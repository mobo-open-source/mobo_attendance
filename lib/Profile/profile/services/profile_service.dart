import 'package:shared_preferences/shared_preferences.dart';

import '../../../CommonWidgets/core/company/session/company_session_manager.dart';
import '../models/profile.dart';

/// Service responsible for all profile-related API interactions with the backend
/// (typically an Odoo instance via XML-RPC / JSON-RPC through CompanySessionManager).
///
/// Handles:
/// - Loading current user's profile data
/// - Updating basic profile fields (name, email, phone, image, etc.)
/// - Updating address-related fields (street, state, country)
/// - Fetching dropdown data for countries and states
///
/// All methods assume an active session is available via [CompanySessionManager].
/// Throws exceptions or returns error maps on failure.
class ProfileService {
  /// Ensures there's an active session before any API call.
  /// Call this method before using any other method in this service.
  ///
  /// Throws [Exception] if no session is found.
  Future<void> initializeClient() async {
    final session = await CompanySessionManager.getCurrentSession();
    if (session == null) throw Exception("No active session");
  }

  /// Resolves the `hr.employee` record linked to this user.
  ///
  /// `employee_id` on `res.users` is a company-dependent related field: it
  /// can resolve to `false` even when the user genuinely has a linked
  /// employee, if the employee's company doesn't match the currently
  /// selected company context. `employee_ids` (the company-independent
  /// one2many) is used as a fallback so the real record can still be found.
  Future<int?> _resolveEmployeeId(int userId) async {
    final result = await CompanySessionManager.callKwWithCompany({
      'model': 'res.users',
      'method': 'read',
      'args': [
        [userId],
        ['employee_id', 'employee_ids'],
      ],
      'kwargs': {},
    });
    if (result is List && result.isNotEmpty) {
      final row = result.first as Map;
      final employeeField = row['employee_id'];
      if (employeeField is List && employeeField.isNotEmpty) {
        return employeeField.first as int;
      }
      final employeeIds = row['employee_ids'];
      if (employeeIds is List && employeeIds.isNotEmpty) {
        return employeeIds.first as int;
      }
    }
    return null;
  }

  /// Loads the current authenticated user's profile data from `res.users`.
  ///
  /// For Odoo < 18, `mobile` lives directly on `res.users` (related to
  /// `res.partner.mobile`).
  ///
  /// For Odoo >= 18, `res.partner.mobile` no longer exists (confirmed in
  /// Odoo 19 core: `res.partner` only defines `phone`). "Mobile" there is
  /// `hr.employee.mobile_phone`, exposed on `res.users` as a related field
  /// (`hr/models/res_users.py`) that's company-dependent and can silently
  /// fail to resolve through `res.users` when the employee's company doesn't
  /// match the current company context, so it's read directly from
  /// `hr.employee` instead (see [_resolveEmployeeId]).
  ///
  /// Returns a list of [Profile] objects (usually 0 or 1 item).
  /// Returns empty list if no data or on error.
  Future<List<Profile>> loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    int userId = prefs.getInt('userId') ?? 0;
    int version = prefs.getInt('version') ?? 0;

    const baseFields = [
      'id',
      'name',
      'phone',
      'email',
      'contact_address',
      'company_id',
      'street',
      'street2',
      'state_id',
      'country_id',
      'image_1920',
      'website',
      'function',
    ];

    if (version < 18) {
      final response = await CompanySessionManager.callKwWithCompany({
        'model': 'res.users',
        'method': 'search_read',
        'args': [
          [
            ['id', '=', userId],
          ],
        ],
        'kwargs': {
          'fields': [...baseFields, 'mobile'],
        },
      });
      final profileItems = response is List ? response : [];
      return profileItems.map((item) => Profile.fromJson(item)).toList();
    }

    final response = await CompanySessionManager.callKwWithCompany({
      'model': 'res.users',
      'method': 'search_read',
      'args': [
        [
          ['id', '=', userId],
        ],
      ],
      'kwargs': {'fields': baseFields},
    });
    final profileItems = response is List
        ? List<Map<String, dynamic>>.from(
            response.map((item) => Map<String, dynamic>.from(item as Map)),
          )
        : <Map<String, dynamic>>[];

    if (profileItems.isNotEmpty) {
      final employeeId = await _resolveEmployeeId(userId);
      if (employeeId != null) {
        try {
          final employeeRead = await CompanySessionManager.callKwWithCompany({
            'model': 'hr.employee',
            'method': 'read',
            'args': [
              [employeeId],
              ['mobile_phone'],
            ],
            'kwargs': {},
          });
          if (employeeRead is List && employeeRead.isNotEmpty) {
            profileItems.first['mobile_phone'] =
                (employeeRead.first as Map)['mobile_phone'];
          }
        } catch (_) {
          // Some non-admin accounts can't even read hr.employee — leave
          // mobile blank rather than mixing in the phone value.
        }
      }
    }

    return profileItems.map((item) => Profile.fromJson(item)).toList();
  }

  /// Updates the current user's profile fields via `res.users.write`.
  ///
  /// Common fields that can be passed in [data]:
  ///   - name
  ///   - email
  ///   - phone
  ///   - mobile / mobile_phone (handled by caller)
  ///   - image_1920 (base64 string)
  ///   - website
  ///   - function (job title)
  ///
  /// Returns:
  ///   - `{'success': true, 'error': null}` on success
  ///   - `{'success': false, 'error': '...'}`
  Future<Map<String, dynamic>> updateUserProfile(
    Map<String, dynamic> data,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      int userId = prefs.getInt('userId') ?? 0;

      final result = await CompanySessionManager.callKwWithCompany({
        'model': 'res.users',
        'method': 'write',
        'args': [
          [userId],
          data,
        ],
        'kwargs': {},
      });

      return {'success': result == true, 'error': null};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Updates the mobile number.
  ///
  /// For Odoo < 18, `mobile` is written directly on `res.users` (related to
  /// `res.partner.mobile`, which always resolves on those versions).
  ///
  /// For Odoo >= 18, there is no `mobile`-like field on `res.partner`
  /// anymore (confirmed in Odoo 19 core), so "Mobile" lives on
  /// `hr.employee.mobile_phone` ("Work Mobile"). It's written through the
  /// `mobile_phone` related field on `res.users` rather than a direct
  /// `hr.employee.write` — verified live against a real Odoo 19 server: a
  /// direct `hr.employee.write` fails with an AccessError for accounts
  /// without `hr.group_hr_user`, because `mail.thread`'s change-tracking
  /// machinery on that model implicitly reads the (HR-Officer-only)
  /// `version_id` field on every write, regardless of which field is being
  /// set. Going through the `res.users` related field bypasses that
  /// tracking write path and succeeds for a normal employee editing their
  /// own record — this is also how Odoo's own "My Preferences" screen does
  /// it, and it was confirmed to persist correctly on `hr.employee`.
  ///
  /// [_resolveEmployeeId] is still used first to check a linked employee
  /// exists at all, so a genuinely unlinked user gets a clear error instead
  /// of a write that would silently no-op. This never falls back to writing
  /// `phone`, since that would silently overwrite the user's actual phone
  /// number with their mobile number.
  ///
  /// Kept independent from [updateUserProfile] so a failure here never
  /// blocks name/email/phone/image from saving, and vice versa.
  ///
  /// Returns same format as [updateUserProfile].
  Future<Map<String, dynamic>> updateMobileNumber(String mobile) async {
    final prefs = await SharedPreferences.getInstance();
    int userId = prefs.getInt('userId') ?? 0;
    int version = prefs.getInt('version') ?? 0;

    if (version < 18) {
      try {
        final result = await CompanySessionManager.callKwWithCompany({
          'model': 'res.users',
          'method': 'write',
          'args': [
            [userId],
            {'mobile': mobile},
          ],
          'kwargs': {},
        });
        return {'success': result == true, 'error': null};
      } catch (e) {
        return {'success': false, 'error': e.toString()};
      }
    }

    final employeeId = await _resolveEmployeeId(userId);
    if (employeeId == null) {
      return {
        'success': false,
        'error': 'No linked employee record found to update the mobile number.',
      };
    }

    try {
      final result = await CompanySessionManager.callKwWithCompany({
        'model': 'res.users',
        'method': 'write',
        'args': [
          [userId],
          {'mobile_phone': mobile},
        ],
        'kwargs': {},
      });
      return {'success': result == true, 'error': null};
    } catch (e) {
      final isAccessError = e.toString().contains('AccessError');
      return {
        'success': false,
        'error': isAccessError
            ? 'Your account does not have permission to update the mobile number. Please contact your administrator.'
            : 'Could not update the mobile number.',
      };
    }
  }

  /// Specialized method to update address-related fields on the current user.
  ///
  /// Recommended fields in [data]:
  ///   - street
  ///   - street2
  ///   - state_id     (integer ID)
  ///   - country_id   (integer ID)
  ///
  /// This method exists mainly for clarity/separation of concerns
  /// (address is often edited separately in UI).
  ///
  /// Returns same format as [updateUserProfile].
  Future<Map<String, dynamic>> updateUserAddress(
    Map<String, dynamic> data,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      int userId = prefs.getInt('userId') ?? 0;

      final result = await CompanySessionManager.callKwWithCompany({
        'model': 'res.users',
        'method': 'write',
        'args': [
          [userId],
          data,
        ],
        'kwargs': {},
      });
      return {'success': result == true, 'error': null};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Fetches all countries from `res.country` model.
  ///
  /// Returns list of maps like:
  ///   [{'id': 1, 'name': 'India'}, ...]
  Future<List<Map<String, dynamic>>> fetchCountries() async {
    final result = await CompanySessionManager.callKwWithCompany({
      'model': 'res.country',
      'method': 'search_read',
      'args': [[]],
      'kwargs': {
        'fields': ['id', 'name'],
      },
    });

    if (result is List) {
      return List<Map<String, dynamic>>.from(result);
    } else {
      return [];
    }
  }

  /// Fetches all states/provinces from `res.country.state`.
  ///
  /// Returns list of maps like:
  ///   [{'id': 12, 'name': 'Kerala'}, ...]
  ///
  /// Note: In real apps you usually want to filter by country
  /// (add domain `[('country_id', '=', selectedCountryId)]`).
  /// This implementation fetches everything for simplicity.
  Future<List<Map<String, dynamic>>> fetchStates() async {
    final result = await CompanySessionManager.callKwWithCompany({
      'model': 'res.country.state',
      'method': 'search_read',
      'args': [[]],
      'kwargs': {
        'fields': ['id', 'name'],
      },
    });

    if (result is List) {
      return List<Map<String, dynamic>>.from(result);
    } else {
      return [];
    }
  }
}
