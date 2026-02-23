import 'package:odoo_rpc/odoo_rpc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../../../CommonWidgets/core/company/session/company_session_manager.dart';

/// Service layer for all backend operations related to **work/organizational employee information** in Odoo.
///
/// Responsibilities:
/// - Session initialization
/// - Loading dropdown data (addresses, work locations, expense/attendance managers, working hours, timezones)
/// - Loading full address details for selected partner
/// - Loading employee work-related fields (address, location, approvers, schedule, timezone)
/// - Permission checks (`canManageSkills`, `isSystemAdmin`)
/// - Fetching hierarchical parent chain for organization chart visualization
/// - Updating work-related employee fields (`hr.employee` write)
/// - Extracting readable error messages from Odoo exceptions
class WorkInfoService {
  /// Ensures an active Odoo session exists before making RPC calls.
  ///
  /// Throws exception if no session is available.
  Future<void> initializeClient() async {
    final session = await CompanySessionManager.getCurrentSession();
    if (session == null) throw Exception("No active session");
  }

  /// Loads partner records (`res.partner`) for work address selection.
  ///
  /// Returns list of maps with `id` and `name`.
  Future<List<Map<String, dynamic>>> loadAddress() async {
    try {
      final address = await CompanySessionManager.callKwWithCompany({
        'model': 'res.partner',
        'method': 'search_read',
        'args': [[]],
        'kwargs': {
          'fields': ['id', 'name'],
        },
      });

      if (address != null && address.isNotEmpty) {
        return List<Map<String, dynamic>>.from(address);
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  /// Loads work locations (`hr.work.location`).
  ///
  /// Returns list of maps with `id` and `name`.
  Future<List<Map<String, dynamic>>> loadLocation() async {
    try {
      final location = await CompanySessionManager.callKwWithCompany({
        'model': 'hr.work.location',
        'method': 'search_read',
        'args': [[]],
        'kwargs': {
          'fields': ['id', 'name'],
        },
      });

      if (location != null && location.isNotEmpty) {
        return List<Map<String, dynamic>>.from(location);
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  /// Loads users (`res.users`) for attendance/expense approver selection.
  ///
  /// Returns list of maps with `id` and `name`.
  Future<List<Map<String, dynamic>>> loadExpense() async {
    try {
      final expense = await CompanySessionManager.callKwWithCompany({
        'model': 'res.users',
        'method': 'search_read',
        'args': [[]],
        'kwargs': {
          'fields': ['id', 'name'],
        },
      });

      if (expense != null && expense.isNotEmpty) {
        return List<Map<String, dynamic>>.from(expense);
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  /// Loads working schedules/calendars (`resource.calendar`).
  ///
  /// Returns list of maps with `id` and `name`.
  Future<List<Map<String, dynamic>>> loadWorkingHours() async {
    try {
      final workingHour = await CompanySessionManager.callKwWithCompany({
        'model': 'resource.calendar',
        'method': 'search_read',
        'args': [[]],
        'kwargs': {
          'fields': ['id', 'name'],
        },
      });

      if (workingHour != null && workingHour.isNotEmpty) {
        return List<Map<String, dynamic>>.from(workingHour);
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  /// In-memory cache for available timezones (fallback list if RPC fails)
  List<Map<String, dynamic>> _availableTimezones = [];

  /// Loads timezone selection options from `res.users` field metadata (`tz` selection).
  ///
  /// Falls back to a hardcoded common list if RPC fails or selection is empty.
  Future<List<Map<String, dynamic>>> fetchTimezones() async {
    try {
      final result = await CompanySessionManager.callKwWithCompany({
        'model': 'res.users',
        'method': 'fields_get',
        'args': [
          ['tz'],
        ],
        'kwargs': {
          'attributes': ['selection', 'string'],
        },
      });

      final tzField = (result != null)
          ? result['tz'] as Map<String, dynamic>?
          : null;
      final selection = tzField != null
          ? tzField['selection'] as List<dynamic>?
          : null;

      List<Map<String, dynamic>> timezones = [];

      if (selection != null && selection.isNotEmpty) {
        timezones = selection.map<Map<String, dynamic>>((item) {
          if (item is List && item.length >= 2) {
            return {'code': item[0].toString(), 'name': item[1].toString()};
          }
          return {'code': item.toString(), 'name': item.toString()};
        }).toList();
      }

      // Fallback if no selection returned
      if (timezones.isEmpty) {
        timezones = [
          {'code': 'UTC', 'name': 'UTC'},
          {'code': 'Europe/Brussels', 'name': 'Europe/Brussels'},
          {'code': 'Asia/Kolkata', 'name': 'Asia/Kolkata'},
          {'code': 'America/New_York', 'name': 'America/New_York'},
        ];
      }

      _availableTimezones = timezones;

      return timezones;
    } catch (e) {
      _availableTimezones = [
        {'code': 'UTC', 'name': 'UTC'},
        {'code': 'America/New_York', 'name': 'Eastern Time (US & Canada)'},
        {'code': 'America/Chicago', 'name': 'Central Time (US & Canada)'},
        {'code': 'America/Denver', 'name': 'Mountain Time (US & Canada)'},
        {'code': 'America/Los_Angeles', 'name': 'Pacific Time (US & Canada)'},
        {'code': 'Europe/London', 'name': 'London'},
        {'code': 'Europe/Paris', 'name': 'Paris'},
        {'code': 'Europe/Berlin', 'name': 'Berlin'},
        {'code': 'Asia/Tokyo', 'name': 'Tokyo'},
        {'code': 'Asia/Shanghai', 'name': 'Shanghai'},
        {'code': 'Asia/Kolkata', 'name': 'Mumbai, Kolkata, New Delhi'},
        {'code': 'Asia/Dubai', 'name': 'Dubai'},
        {'code': 'Australia/Sydney', 'name': 'Sydney'},
      ];
      return _availableTimezones;
    } finally {}
  }

  /// Loads full address details for a selected partner (`res.partner`).
  Future<dynamic> loadFullAddress(int id) async {
    await initializeClient();
    try {
      final addressDetails = await CompanySessionManager.callKwWithCompany({
        'model': 'res.partner',
        'method': 'search_read',
        'args': [
          [
            ['id', '=', id],
          ],
        ],
        'kwargs': {
          'fields': [
            'name',
            'street',
            'street2',
            'city',
            'zip',
            'state_id',
            'country_id',
          ],
        },
      });

      if (addressDetails == null || addressDetails.isEmpty) {
        return null;
      }

      return addressDetails[0];
    } catch (e) {
      return null;
    }
  }

  /// Updates work-related employee fields in `hr.employee`.
  ///
  /// Returns map with `success`, `warning`, `warningMessage`, or `errorMessage`.
  Future<dynamic> updateEmployeeDetails(int id, data) async {
    try {
      await CompanySessionManager.callKwWithCompany({
        'model': 'hr.employee',
        'method': 'write',
        'args': [
          [id],
          data,
        ],
        'kwargs': {},
      });

      return {"success": true, "errorMessage": null};
    } on OdooException catch (e) {
      final errorMsg = extractOdooError(e);
      return {
        "success": false,
        "warning": true,
        "warningMessage":
            errorMsg ??
            "Failed to update work information, Please try again later",
      };
    } catch (e) {
      return {
        "success": false,
        "warning": false,
        "errorMessage":
            "Failed to update work information, Please try again later",
      };
    }
  }

  /// Extracts human-readable error message from Odoo exceptions.
  ///
  /// Supports `ValidationError`, `AccessError`, `UserError`.
  String? extractOdooError(OdooException e) {
    final text = e.toString();

    final validationMatch = RegExp(
      r'ValidationError:\s*([\s\S]*?)(?=, message:|, arguments:|, context:|\}$)',
    ).firstMatch(text);

    if (validationMatch != null) {
      return validationMatch.group(1)!.trim();
    }

    final accessMatch = RegExp(
      r'name:\s*odoo\.exceptions\.AccessError,\s*message:\s*([\s\S]*?)(?=, arguments:|, context:|\}$)',
      caseSensitive: false,
    ).firstMatch(text);

    if (accessMatch != null) {
      return accessMatch.group(1)!.trim();
    }

    final userMatch = RegExp(
      r'name:\s*odoo\.exceptions\.UserError,\s*message:\s*([\s\S]*?)(?=, arguments:|, context:|\}$)',
      caseSensitive: false,
    ).firstMatch(text);

    if (userMatch != null) {
      return userMatch.group(1)!.trim();
    }

    return null;
  }

  /// Extracts major version number from Odoo `server_version` string.
  ///
  /// Used to handle API differences (e.g. `has_group` signature in v18+).
  int parseMajorVersion(String serverVersion) {
    final match = RegExp(r'\d+').firstMatch(serverVersion);
    if (match != null) {
      return int.tryParse(match.group(0)!) ?? 0;
    }
    return 0;
  }

  /// Checks if current user has HR rights (user/manager) or is system admin.
  ///
  /// Uses `res.users.has_group` RPC — version-aware (args differ in Odoo 18+).
  Future<bool> canManageSkills() async {
    final prefs = await SharedPreferences.getInstance();
    final String version = prefs.getString('serverVersion') ?? '0';
    final int userId = prefs.getInt('userId') ?? 0;
    final int majorVersion = parseMajorVersion(version);

    Future<bool> hasGroup(String groupExtId) async {
      if (majorVersion >= 18) {
        return await CompanySessionManager.callKwWithCompany({
              'model': 'res.users',
              'method': 'has_group',
              'args': [userId, groupExtId],
              'kwargs': {},
            }) ==
            true;
      } else {
        return await CompanySessionManager.callKwWithCompany({
              'model': 'res.users',
              'method': 'has_group',
              'args': [groupExtId],
              'kwargs': {},
            }) ==
            true;
      }
    }

    final isHrUser = await hasGroup('hr.group_hr_user');
    final isHrManager = await hasGroup('hr.group_hr_manager');
    final isAdmin = await hasGroup('base.group_system');

    return isHrUser || isHrManager || isAdmin;
  }

  /// Checks if current user is system administrator (`base.group_system`).
  ///
  /// Version-aware call to `has_group`.
  Future<bool> isSystemAdmin() async {
    final prefs = await SharedPreferences.getInstance();
    final String version = prefs.getString('serverVersion') ?? '0';
    final int userId = prefs.getInt('userId') ?? 0;
    final int majorVersion = parseMajorVersion(version);

    if (majorVersion >= 18) {
      return await CompanySessionManager.callKwWithCompany({
            'model': 'res.users',
            'method': 'has_group',
            'args': [userId, 'base.group_system'],
            'kwargs': {},
          }) ==
          true;
    } else {
      return await CompanySessionManager.callKwWithCompany({
            'model': 'res.users',
            'method': 'has_group',
            'args': ['base.group_system'],
            'kwargs': {},
          }) ==
          true;
    }
  }

  /// Loads work-related fields from `hr.employee` — admin-aware field inclusion.
  ///
  /// Includes `attendance_manager_id` only if current user is system admin.
  Future<dynamic> loadEmployeeDetails(int id, bool canSeeExtraFields) async {
    final bool isAdmin = await isSystemAdmin();

    final safeFields = [
      'address_id',
      'work_location_id',
      if (isAdmin) 'attendance_manager_id',
      'resource_calendar_id',
      'tz',
      'name',
      'job_title',
      'parent_id',
    ];

    if (canSeeExtraFields) safeFields.add('image_1920');

    final employeeDetails = await CompanySessionManager.callKwWithCompany({
      'model': 'hr.employee',
      'method': 'search_read',
      'args': [
        [
          ['id', '=', id],
        ],
      ],
      'kwargs': {'fields': safeFields},
    });

    if (employeeDetails.isEmpty) return null;
    return employeeDetails[0];
  }

  /// Recursively fetches the parent chain (manager hierarchy) for organization chart.
  ///
  /// Stops on cycles or missing parents. Includes extra fields (e.g. image) if permitted.
  Future<List<Map<String, dynamic>>> fetchParentChain(int employeeId) async {
    final canSeeExtraFields = await canManageSkills();

    List<Map<String, dynamic>> chain = [];
    Set<int> visited = {};

    int? currentId = employeeId;

    while (currentId != null && !visited.contains(currentId)) {
      visited.add(currentId);

      final emp = await loadEmployeeDetails(currentId, canSeeExtraFields);
      if (emp == null) break;

      chain.add(emp);

      if (emp['parent_id'] is List && emp['parent_id'].isNotEmpty) {
        currentId = emp['parent_id'][0];
      } else {
        break;
      }
    }

    return chain;
  }
}
