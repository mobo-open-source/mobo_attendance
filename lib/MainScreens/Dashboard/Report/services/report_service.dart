import 'package:shared_preferences/shared_preferences.dart';

import '../../../../CommonWidgets/core/company/session/company_session_manager.dart';

/// Service layer responsible for fetching attendance report / analytics data from Odoo.
///
/// Features:
/// - Session initialization check
/// - Employee hierarchy lookup (my team / subordinates)
/// - Complex domain building for filters (my attendance, my team, at work, errors, last 7 days, search)
/// - Paginated grouped data for graph visualization (read_group)
/// - Total count for pagination
/// - Measure-specific field selection (sum, avg, etc.)
class ReportService {
  /// Ensures an active Odoo session exists before making any RPC calls.
  ///
  /// Throws exception if no session is found.
  Future<void> initializeClient() async {
    final session = await CompanySessionManager.getCurrentSession();
    if (session == null) throw Exception("No active session");
  }

  /// Finds all employee IDs whose `parent_id` points to the current user's employee record.
  ///
  /// Used for "My Team" filter — returns subordinates under the current manager.
  /// Returns empty list on error or no subordinates.
  Future<List<int>> getEmployeeIdsByParentUser() async {
    try {

      final prefs = await SharedPreferences.getInstance();
      int userId = prefs.getInt('userId') ?? 0;

      // Find employees with any parent_id set
      final res = await CompanySessionManager.callKwWithCompany({
        'model': 'hr.employee',
        'method': 'search_read',
        'args': [
          [
            ['parent_id', '!=', false],
          ],
        ],
        'kwargs': {
          'fields': ['id', 'parent_id'],
        },
      });

      if (res == null || res.isEmpty) return [];

      List<int> matchingIds = [];

      for (var emp in res) {
        final parent = emp['parent_id'];
        if (parent != null && parent is List && parent.isNotEmpty) {
          final parentId = parent[0];

          // Check if this parent belongs to current user
          final parentData = await CompanySessionManager.callKwWithCompany({
            'model': 'hr.employee',
            'method': 'read',
            'args': [parentId],
            'kwargs': {
              'fields': ['user_id'],
            },
          });

          if (parentData != null &&
              parentData.isNotEmpty &&
              parentData[0]['user_id'] != null &&
              parentData[0]['user_id'] is List &&
              parentData[0]['user_id'][0] == userId) {
            matchingIds.add(emp['id'] as int);
          }
        }
      }

      return matchingIds;
    } catch (e) {
      return [];
    }
  }

  /// Finds the employee ID linked to the current authenticated user.
  ///
  /// Returns null if no matching employee record is found or on error.
  Future<int?> getEmployeeIdByUserId() async {
    try {

      final prefs = await SharedPreferences.getInstance();
      int userId = prefs.getInt('userId') ?? 0;

      final res = await CompanySessionManager.callKwWithCompany({
        'model': 'hr.employee',
        'method': 'search_read',
        'args': [
          [
            ['user_id', '=', userId],
          ],
        ],
        'kwargs': {
          'fields': ['id'],
          'limit': 1,
        },
      });

      if (res != null && res.isNotEmpty) {
        return res[0]['id'] as int?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Builds the Odoo domain for attendance queries based on active filters and search text.
  ///
  /// Handles:
  /// - "my_attendance" → current user's employee
  /// - "my_team" → subordinates
  /// - "at_work" → open attendances (no check_out)
  /// - "errors" → long open shifts or >16h worked
  /// - "last_7_days" → recent check-ins
  /// - Search → employee name match
  Future<List> _buildAttendanceDomain(
    List<String> filters, {
    String? searchText,
  }) async {
    List domain = [];

    if (filters.contains("my_attendance")) {
      final empId = await getEmployeeIdByUserId();
      if (empId != null) domain.add(['employee_id', '=', empId]);
    }

    if (filters.contains("my_team")) {
      final empIds = await getEmployeeIdsByParentUser();
      if (empIds.isNotEmpty) domain.add(['employee_id', 'in', empIds]);
    }

    if (filters.contains("at_work")) {
      domain.add(['check_out', '=', false]);
    }

    if (filters.contains("errors")) {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final formatted = "${yesterday.toIso8601String().split('T')[0]} 00:00:00";

      domain.addAll([
        '&',
        ['worked_hours', '>=', 16],
        '|',
        ['check_out', '=', false],
        ['check_in', '<=', formatted],
      ]);
    }

    if (filters.contains("last_7_days")) {
      final last7 = DateTime.now().subtract(const Duration(days: 7));
      final formatted = "${last7.toIso8601String().split('T')[0]} 00:00:00";
      domain.add(['check_in', '>=', formatted]);
    }

    if (searchText != null && searchText.trim().isNotEmpty) {
      final empIds = await getEmployeeIdsByName(searchText);

      if (empIds.isNotEmpty) {
        domain.add(['employee_id', 'in', empIds]);
      } else {
        domain.add(['id', '=', -1]);
      }
    }

    return domain;
  }

  /// Counts total attendance records matching current filters and search text.
  ///
  /// Uses `read_group` on `employee_id` to get unique count (fast).
  Future<int> fetchAttendanceTotalCount({
    required List<String> filters,
    String? searchText,
  }) async {
    await initializeClient();

    final domain = await _buildAttendanceDomain(
      filters,
      searchText: searchText,
    );

    final result = await CompanySessionManager.callKwWithCompany({
      'model': 'hr.attendance',
      'method': 'read_group',
      'args': [
        domain,
        ['employee_id'],
        ['employee_id'],
      ],
      'kwargs': {},
    });

    return (result as List).length;
  }

  /// Finds employee IDs matching a search term (name ilike).
  ///
  /// Used for search filter on employee name.
  Future<List<int>> getEmployeeIdsByName(String searchText) async {
    final res = await CompanySessionManager.callKwWithCompany({
      'model': 'hr.employee',
      'method': 'search_read',
      'args': [
        [
          ['name', 'ilike', searchText],
        ],
      ],
      'kwargs': {
        'fields': ['id'],
      },
    });

    if (res == null || res.isEmpty) return [];

    return res.map<int>((e) => e['id'] as int).toList();
  }

  /// Fetches paginated, grouped attendance data for graph visualization.
  ///
  /// Main method used by report bloc to populate charts.
  ///
  /// Parameters:
  /// - `page`, `itemsPerPage`: pagination
  /// - `filters`: list of active filter keys
  /// - `dateGroupBy`: "check_in" or "check_out" (or null)
  /// - `dateGroupByUnit`: time granularity ("day", "month", etc.)
  /// - `measure`: metric to aggregate ("Worked Hours", "Over Time", etc.)
  /// - `searchText`: optional employee name search
  Future<List<Map<String, dynamic>>> fetchAttendanceForGraph({
    required int page,
    int? itemsPerPage,
    required List<String> filters,
    required String? dateGroupBy,
    required String? dateGroupByUnit,
    required String measure,
    String? searchText,
  }) async {
    await initializeClient();
    final offset = page * itemsPerPage!;

    List domain = [];

    if (filters.contains("my_attendance")) {
      final empId = await getEmployeeIdByUserId();
      if (empId != null) domain.add(['employee_id', '=', empId]);
    }
    if (filters.contains("my_team")) {
      final empIds = await getEmployeeIdsByParentUser();
      if (empIds.isNotEmpty) domain.add(['employee_id', 'in', empIds]);
    }
    if (filters.contains("at_work")) {
      domain.add(['check_out', '=', false]);
    }

    if (searchText != null && searchText.trim().isNotEmpty) {
      final employeeIds = await getEmployeeIdsByName(searchText);

      if (employeeIds.isNotEmpty) {
        domain.add(['employee_id', 'in', employeeIds]);
      } else {
        domain.add(['id', '=', -1]);
      }
    }

    if (filters.contains("errors")) {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final yesterdayFormatted =
          "${yesterday.toIso8601String().split('T')[0]} 00:00:00";
      domain.addAll([
        '&',
        ['worked_hours', '>=', 16],
        '|',
        ['check_out', '=', false],
        ['check_in', '<=', yesterdayFormatted],
      ]);
    }
    if (filters.contains("last_7_days")) {
      final last7 = DateTime.now().subtract(const Duration(days: 7));
      final formatted = "${last7.toIso8601String().split('T')[0]} 00:00:00";
      domain.add(['check_in', '>=', formatted]);
    }

    List<String> groupByList = [];

    if (dateGroupBy != null && dateGroupByUnit != null) {
      groupByList.add('$dateGroupBy:$dateGroupByUnit');
    } else {
      groupByList.add('employee_id');
    }

    final fields = [
      ..._getFieldsForMeasure(measure),
      'check_in:min',
      'check_out:max',
    ];
    final result = await CompanySessionManager.callKwWithCompany({
      'model': 'hr.attendance',
      'method': 'read_group',
      'args': [domain, fields, groupByList],
      'kwargs': {
        'orderby': dateGroupBy != null ? dateGroupBy : 'employee_id',
        'limit': itemsPerPage,
        'offset': offset,
      },
    });

    return List<Map<String, dynamic>>.from(result ?? []);
  }

  /// Returns the appropriate aggregation fields for the selected measure.
  List<String> _getFieldsForMeasure(String measure) {
    switch (measure) {
      case 'Worked Hours':
        return ['worked_hours:sum'];
      case 'Over Time':
        return ['overtime_hours:sum'];
      case 'Latitude':
        return ['in_latitude:avg'];
      case 'Out Latitude':
        return ['out_latitude:avg'];
      case 'Longitude':
        return ['in_longitude:avg'];
      case 'Out Longitude':
        return ['out_longitude:avg'];
      default:
        return ['worked_hours:sum'];
    }
  }
}
