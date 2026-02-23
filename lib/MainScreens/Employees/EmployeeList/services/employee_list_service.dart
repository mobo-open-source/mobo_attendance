import 'package:odoo_rpc/odoo_rpc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../CommonWidgets/core/company/session/company_session_manager.dart';

/// Service layer for all backend operations related to **employee listing** in Odoo.
///
/// Responsibilities:
/// - Session initialization
/// - Counting employees with complex filters (search, active, newly hired, my team/department, pre-applied IDs)
/// - Fetching paginated employee list with safe fields (image conditionally included)
/// - Archiving (`active = false`) and deleting employees
/// - Permission checks for viewing employee images
/// - Enriching employee data with skill and tag names (post-fetch)
/// - Extracting readable error messages from Odoo exceptions
class EmployeeListService {
  /// Ensures an active Odoo session exists before making RPC calls.
  ///
  /// Throws exception if no session is available.
  Future<void> initializeClient() async {
    final session = await CompanySessionManager.getCurrentSession();
    if (session == null) throw Exception("No active session");
  }

  /// Counts employees matching the given filters and domain conditions.
  ///
  /// Supports:
  /// - Text search (`name ilike`)
  /// - Active status
  /// - Newly hired flag
  /// - My team (subordinates of current user)
  /// - My department (employees in same department)
  /// - Pre-applied employee IDs (from external filter)
  Future<int> EmployeeCount({
    String? searchText,
    bool? active,
    bool? newlyHired,
    bool? myTeam,
    bool? myDepartment,
    List<int>? employeeIds,
    bool? preApplied,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      int userId = prefs.getInt('userId') ?? 0;

      final List domain = [];
      domain.addAll([
        ['active', '=', active],
      ]);
      if (preApplied == true) {
        domain.add(['id', 'in', employeeIds]);
      }
      if (newlyHired == true) {
        domain.add(['newly_hired', '=', newlyHired]);
      }
      List orConditions = [];

      if (myTeam == true) {
        final currentEmployeeId = await CompanySessionManager.callKwWithCompany(
          {
            'model': 'hr.employee',
            'method': 'search_read',
            'args': [
              [
                ['user_id', '=', userId],
              ],
            ],
            'kwargs': {
              'fields': ['id'],
            },
          },
        );
        if (currentEmployeeId != null && currentEmployeeId.isNotEmpty) {
          final empId = currentEmployeeId[0]['id'];
          orConditions.add(['parent_id', '=', empId]);
        }
      }
      if (myDepartment == true) {
        orConditions.add(['member_of_department', '=', true]);
      }

      if (orConditions.length == 1) {
        domain.add(orConditions.first);
      } else if (orConditions.length == 2) {
        domain.add('|');
        domain.add(orConditions[0]);
        domain.add(orConditions[1]);
      }
      if (searchText != null && searchText.isNotEmpty) {
        domain.add(['name', 'ilike', searchText]);
      }

      final employeeCount = await CompanySessionManager.callKwWithCompany({
        'model': 'hr.employee',
        'method': 'search_count',
        'args': [domain],
        'kwargs': {},
      });
      return employeeCount ?? 0;
    } catch (e) {
      throw Exception('Failed to count Employees: $e');
    }
  }

  /// Archives an employee by setting `active = false`.
  ///
  /// Returns null on success or error map with `warning`/`warningMessage`.
  Future<Map<String, dynamic>?> archiveEmployee(int id) async {
    try {
      await CompanySessionManager.callKwWithCompany({
        'model': 'hr.employee',
        'method': 'write',
        'args': [
          [id],
          {'active': false},
        ],
        'kwargs': {},
      });

      return null;
    } on OdooException catch (e) {
      return {
        'warning':true,
        'warningMessage':
            extractOdooError(e) ??
            'Something went wrong, Please try again later',
      };
    } catch (e) {
      return {
        'warning':false,
        'errorMessage': 'Unexpected error occurred while archiving employee',
      };
    }
  }

  /// Permanently deletes an employee record (`unlink`).
  ///
  /// Returns null on success or error map with `warning`/`warningMessage`.
  Future<Map<String, dynamic>?> deleteEmployee(int id) async {
    try {
      await CompanySessionManager.callKwWithCompany({
        'model': 'hr.employee',
        'method': 'unlink',
        'args': [
          [id],
        ],
        'kwargs': {},
      });

      return null;
    } on OdooException catch (e) {
      return {
        'warning':true,
        'warningMessage':
            extractOdooError(e) ??
            'Something went wrong, Please try again later',
      };
    } catch (e) {
      return {
        'warning':false,
        'errorMessage': "Unexpected error occurred while deleting employee",
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

  /// Fetches current user's group IDs (`res.users.groups_id`).
  Future<List<int>> getCurrentUserGroups() async {
    final prefs = await SharedPreferences.getInstance();
    int userId = prefs.getInt('userId') ?? 0;

    final userData = await CompanySessionManager.callKwWithCompany({
      'model': 'res.users',
      'method': 'read',
      'args': [
        [userId],
      ],
      'kwargs': {
        'fields': ['groups_id'],
      },
    });

    if (userData != null && userData.isNotEmpty) {
      return List<int>.from(userData[0]['groups_id'] ?? []);
    }
    return [];
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

  /// Checks if current user has permission to view employee images (`image_1920`).
  ///
  /// Allowed for HR users, managers, or system admins.
  /// Uses `res.users.has_group` — version-aware (args differ in Odoo 18+).
  Future<bool> userCanSeeEmployeeImage() async {
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

    final isHrManager = await hasGroup('hr.group_hr_manager');
    final isHrUser = await hasGroup('hr.group_hr_user');
    final isAdmin = await hasGroup('base.group_system');

    return isHrUser || isHrManager || isAdmin;
  }

  /// Fetches paginated list of employees with dynamic domain and safe fields.
  ///
  /// Fields are restricted; `image_1920` only included if user has permission.
  Future<List<Map<String, dynamic>>> fetchEmployees(
    int page,
    int itemsPerPage, {
    String? searchQuery,
    bool? active,
    bool? newlyHired,
    bool? myTeam,
    bool? myDepartment,
    List<int>? employeeIds,
    bool? preApplied,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      int userId = prefs.getInt('userId') ?? 0;

      final offset = page * itemsPerPage;
      final List domain = [];
      domain.addAll([
        ['active', '=', active],
      ]);
      if (preApplied == true) {
        domain.add(['id', 'in', employeeIds]);
      }
      if (newlyHired == true) {
        domain.add(['newly_hired', '=', newlyHired]);
      }
      List orConditions = [];

      if (myTeam == true) {
        final currentEmployeeId = await CompanySessionManager.callKwWithCompany(
          {
            'model': 'hr.employee',
            'method': 'search_read',
            'args': [
              [
                ['user_id', '=', userId],
              ],
            ],
            'kwargs': {
              'fields': ['id'],
            },
          },
        );
        if (currentEmployeeId != null && currentEmployeeId.isNotEmpty) {
          final empId = currentEmployeeId[0]['id'];
          orConditions.add(['parent_id', '=', empId]);
        }
      }
      if (myDepartment == true) {
        orConditions.add(['member_of_department', '=', true]);
      }

      if (orConditions.length == 1) {
        domain.add(orConditions.first);
      } else if (orConditions.length == 2) {
        domain.add('|');
        domain.add(orConditions[0]);
        domain.add(orConditions[1]);
      }
      if (searchQuery != null && searchQuery.isNotEmpty) {
        domain.add(['name', 'ilike', searchQuery]);
      }

      final canSeeImage = await userCanSeeEmployeeImage();
      final safeFields = [
        'id',
        'name',
        'work_email',
        'work_phone',
        'parent_id',
        'department_id',
        'job_id',
        'create_date',
      ];
      if (canSeeImage) {
        safeFields.addAll(['image_1920', 'skill_ids', 'category_ids']);
      }

      final employeeItems = await CompanySessionManager.callKwWithCompany({
        'model': 'hr.employee',
        'method': 'search_read',
        'args': [domain],
        'kwargs': {
          'fields': safeFields,
          'limit': itemsPerPage,
          'offset': offset,
        },
      });

      return List<Map<String, dynamic>>.from(employeeItems ?? []);
    } catch (e) {
      return [];
    }
  }

  /// Enriches employee list with human-readable skill names.
  ///
  /// Fetches `hr.skill` records in bulk and maps IDs → names.
  Future<void> loadSkill(List<Map<String, dynamic>> employees) async {
    try {
      final List<int> skillIds = employees
          .expand((emp) => (emp["skill_ids"] ?? []) as List)
          .cast<int>()
          .toSet()
          .toList();

      if (skillIds.isEmpty) {
        return;
      }

      final skillData = await CompanySessionManager.callKwWithCompany({
        'model': 'hr.skill',
        'method': 'search_read',
        'args': [
          [
            ['id', 'in', skillIds],
          ],
        ],
        'kwargs': {
          'fields': ['id', 'name'],
        },
      });

      if (skillData == null) return;

      final Map<int, String> skillMap = {
        for (var s in skillData) s['id']: s['name'],
      };

      for (var emp in employees) {
        final ids = (emp["skill_ids"] ?? []) as List;

        emp["skill_names"] = ids
            .map((id) => skillMap[id] ?? "Unknown")
            .toList();
      }
    } catch (e) {}
  }

  /// Enriches employee list with human-readable tag/category names.
  ///
  /// Fetches `hr.employee.category` records in bulk and maps IDs → names.
  Future<void> loadTags(List<Map<String, dynamic>> employees) async {
    try {
      final List<int> tagIds = employees
          .expand((emp) => (emp["category_ids"] ?? []) as List)
          .cast<int>()
          .toSet()
          .toList();

      if (tagIds.isEmpty) {
        return;
      }

      final tagData = await CompanySessionManager.callKwWithCompany({
        'model': 'hr.employee.category',
        'method': 'search_read',
        'args': [
          [
            ['id', 'in', tagIds],
          ],
        ],
        'kwargs': {
          'fields': ['id', 'name'],
        },
      });

      if (tagData == null) return;

      final Map<int, String> tagMap = {
        for (var t in tagData) t['id']: t['name'],
      };

      for (var emp in employees) {
        final ids = (emp["category_ids"] ?? []) as List;

        emp["tag_names"] = ids.map((id) => tagMap[id] ?? "Unknown").toList();
      }
    } catch (e) {}
  }
}
