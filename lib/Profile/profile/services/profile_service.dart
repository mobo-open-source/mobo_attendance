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

  /// Loads the current authenticated user's profile data from `res.users`.
  ///
  /// Uses `search_read` on the domain `[('id', '=', userId)]`.
  /// Dynamically selects the mobile field name based on server version:
  ///   - `mobile` for Odoo < 18
  ///   - `mobile_phone` for Odoo >= 18
  ///
  /// Returns a list of [Profile] objects (usually 0 or 1 item).
  /// Returns empty list if no data or on error.
  Future<List<Profile>> loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    int userId = prefs.getInt('userId') ?? 0;

    int version = prefs.getInt('version') ?? 0;
    String mobile;
    if (version < 18) {
      mobile = 'mobile';
    } else {
      mobile = 'mobile_phone';
    }
    final details = [
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
      mobile,
    ];
    final response = await CompanySessionManager.callKwWithCompany({
      'model': 'res.users',
      'method': 'search_read',
      'args': [
        [
          ['id', '=', userId],
        ],
      ],
      'kwargs': {'fields': details},
    });

    final profileItems = response is List ? response : [];

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
      return {
        'success': false,
        'error': e.toString(),
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
      return {
        'success': false,
        'error': e.toString(),
      };
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
