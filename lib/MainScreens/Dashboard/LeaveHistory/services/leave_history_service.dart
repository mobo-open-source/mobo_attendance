import 'package:shared_preferences/shared_preferences.dart';

import '../../../../CommonWidgets/core/company/session/company_session_manager.dart';

/// Service layer responsible for fetching employee's leave history data from Odoo.
///
/// Handles:
/// - Initialization check of Odoo session
/// - Version-aware field selection (Odoo 18+ differences)
/// - Paginated loading of leave requests with search/filter support
/// - Counting total matching leaves for pagination
class LeaveHistoryService {
  /// Ensures there is an active Odoo session before making any RPC calls.
  ///
  /// Throws exception if no session is found.
  Future<void> initializeClient() async {
    final session = await CompanySessionManager.getCurrentSession();
    if (session == null) throw Exception("No active session");
  }

  /// Extracts the major version number from Odoo's server_version string
  /// (e.g. "18.0" → 18, "16.0+e" → 16)
  int parseMajorVersion(String serverVersion) {
    final match = RegExp(r'\d+').firstMatch(serverVersion);
    if (match != null) {
      return int.tryParse(match.group(0)!) ?? 0;
    }
    return 0;
  }

  /// Loads paginated list of leave requests for the current employee.
  ///
  /// Supports:
  /// - Pagination (page × itemsPerPage offset)
  /// - Keyword search (on leave type name or date fragments)
  /// - Status/approval filters (first approval, second approval, approved, cancelled)
  ///
  /// Returns empty list on error or no records.
  Future<List<Map<String, dynamic>>> loadCurrentEmployeeLeaves(
    int page,
    int itemsPerPage, {
    String? searchQuery,
    bool? firstApproval,
    bool? secondApproval,
    bool? thirdApproval,
    bool? cancelledLeave,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      int userId = prefs.getInt('userId') ?? 0;
      final String version = prefs.getString('serverVersion') ?? '0';
      final int majorVersion = parseMajorVersion(version);

      // Find current employee's ID
      final employeeResult = await CompanySessionManager.callKwWithCompany({
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

      if (employeeResult == null || employeeResult.isEmpty) {
        return [];
      }

      final employeeId = employeeResult[0]['id'];
      final offset = page * itemsPerPage;
      final List domain = [];
      domain.addAll([
        ['employee_id', '=', employeeId],
      ]);

      // Handle search query (type name OR date fragments)
      if (searchQuery != null && searchQuery.isNotEmpty) {
        final parts = searchQuery
            .split('-')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();

        // Try matching leave type name first
        final typeResult = await CompanySessionManager.callKwWithCompany({
          'model': 'hr.leave.type',
          'method': 'search_read',
          'args': [
            [
              ['name', 'ilike', searchQuery],
            ],
          ],
          'kwargs': {
            'fields': ['id'],
          },
        });

        if (typeResult != null && typeResult.isNotEmpty) {
          final typeIds = typeResult.map((e) => e['id']).toList();
          domain.add(['holiday_status_id', 'in', typeIds]);
        } else {
          if (parts.isNotEmpty) {
            final List<dynamic> dateDomain = [];

            for (final part in parts) {
              dateDomain.add('|');
              dateDomain.add(['request_date_from', 'ilike', part]);
              dateDomain.add(['request_date_to', 'ilike', part]);
            }

            dateDomain.removeAt(0);

            domain.addAll(dateDomain);
          }
        }
      }
      final List<String> states = [];

      if (firstApproval == true) {
        states.addAll(['confirm', 'validate1']);
      }

      if (secondApproval == true) {
        states.add('validate1');
      }

      if (thirdApproval == true) {
        states.add('validate');
      }

      final uniqueStates = states.toSet().toList();

      if (uniqueStates.isNotEmpty) {
        domain.add(['state', 'in', uniqueStates]);
      }

      if (cancelledLeave == true) {
        domain.add(['active', '=', false]);
      }

      // Version-aware fields
      List<String> fields;
      if (majorVersion >= 18){
        fields = [
          'id',
          'name',
          'display_name',
          'state',
          'holiday_status_id',
          'request_date_from',
          'request_date_to',
        ];
      } else {
        fields = [
          'id',
          'name',
          'display_name',
          'state',
          'holiday_status_id',
          'request_date_from',
          'request_date_to',
          'number_of_days_display',
        ];
      }

      final records = await CompanySessionManager.callKwWithCompany({
        'model': 'hr.leave',
        'method': 'search_read',
        'args': [domain],
        'kwargs': {
          'fields': fields,
        },
      });
      if (records != null) {
        return List<Map<String, dynamic>>.from(records);
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  /// Counts total number of leave records matching current filters/search.
  ///
  /// Used for calculating pagination metadata (total pages, range display).
  Future<int> LeaveCount({
    String? searchText,
    bool? firstApproval,
    bool? secondApproval,
    bool? thirdApproval,
    bool? cancelledLeave,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      int userId = prefs.getInt('userId') ?? 0;

      // Get employee ID
      final employeeResult = await CompanySessionManager.callKwWithCompany({
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
      if (employeeResult == null || employeeResult.isEmpty) {
        return 0;
      }

      final employeeId = employeeResult[0]['id'];
      final List domain = [];
      domain.addAll([
        ['employee_id', '=', employeeId],
      ]);

      if (searchText != null && searchText.isNotEmpty) {
        final parts = searchText
            .split('-')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();

        final typeResult = await CompanySessionManager.callKwWithCompany({
          'model': 'hr.leave.type',
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

        if (typeResult != null && typeResult.isNotEmpty) {
          final typeIds = typeResult.map((e) => e['id']).toList();
          domain.add(['holiday_status_id', 'in', typeIds]);
        } else {
          if (parts.isNotEmpty) {
            final List<dynamic> dateDomain = [];

            for (final part in parts) {
              dateDomain.add('|');
              dateDomain.add(['request_date_from', 'ilike', part]);
              dateDomain.add(['request_date_to', 'ilike', part]);
            }

            dateDomain.removeAt(0);

            domain.addAll(dateDomain);
          }
        }
      }

      final List<String> states = [];

      if (firstApproval == true) {
        states.addAll(['confirm', 'validate1']);
      }

      if (secondApproval == true) {
        states.add('validate1');
      }

      if (thirdApproval == true) {
        states.add('validate');
      }

      final uniqueStates = states.toSet().toList();

      if (uniqueStates.isNotEmpty) {
        domain.add(['state', 'in', uniqueStates]);
      }

      if (cancelledLeave == true) {
        domain.add(['active', '=', false]);
      }
      final records = await CompanySessionManager.callKwWithCompany({
        'model': 'hr.leave',
        'method': 'search_count',
        'args': [domain],
        'kwargs': {},
      });
      if (records != null) {
        return records ?? 0;
      } else {
        return 0;
      }
    } catch (e) {
      return 0;
    }
  }
}
