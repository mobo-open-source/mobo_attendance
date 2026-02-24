import 'package:odoo_rpc/odoo_rpc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../CommonWidgets/core/company/session/company_session_manager.dart';

/// Service layer responsible for fetching and managing pending leave requests
/// (Leave Manager / Manager approval view) from Odoo.
///
/// Features:
/// - Initialization check of Odoo session
/// - Version-aware field selection (Odoo 18+ differences)
/// - Paginated loading of pending leaves with search/filter support
/// - Counting total pending leaves
/// - Approve / Validate / Refuse actions with error extraction
class PendingLeaveService {
  /// Ensures an active Odoo session exists before making RPC calls.
  ///
  /// Throws an exception if no session is available.
  Future<void> initializeClient() async {
    final session = await CompanySessionManager.getCurrentSession();
    if (session == null) throw Exception("No active session");
  }

  /// Extracts the major version number from Odoo's `server_version` string
  /// (e.g. "18.0" → 18, "16.0+e" → 16)
  int parseMajorVersion(String serverVersion) {
    final match = RegExp(r'\d+').firstMatch(serverVersion);
    if (match != null) {
      return int.tryParse(match.group(0)!) ?? 0;
    }
    return 0;
  }

  /// Loads paginated list of pending leave requests.
  ///
  /// Pending leaves are those with `state` not in ['validate', 'draft', 'refuse'].
  ///
  /// Supports:
  /// - Pagination via `page` and `itemsPerPage`
  /// - Keyword search (employee name, leave type name, or date fragments)
  /// - Filtering by approval stage (`firstApproval`, `secondApproval`)
  ///
  /// Returns empty list on error or no records.
  Future<List<Map<String, dynamic>>> loadPendingLeaves(
    int page,
    int itemsPerPage, {
    String? searchQuery,
    bool? firstApproval,
    bool? secondApproval,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String version = prefs.getString('serverVersion') ?? '0';
      final int majorVersion = parseMajorVersion(version);
      final offset = page * itemsPerPage;
      final List domain = [];

      domain.add([
        'state',
        'not in',
        ['validate', 'draft', 'refuse'],
      ]);

      if (searchQuery != null && searchQuery.isNotEmpty) {
        final parts = searchQuery
            .split('-')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();

        // Try matching employee name first
        final employeeResult = await CompanySessionManager.callKwWithCompany({
          'model': 'hr.employee',
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

        if (employeeResult != null && employeeResult.isNotEmpty) {
          domain.add([
            'employee_id',
            'in',
            employeeResult.map((e) => e['id']).toList(),
          ]);
        } else {
          // Try matching leave type name
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
            domain.add([
              'holiday_status_id',
              'in',
              typeResult.map((e) => e['id']).toList(),
            ]);
          } else if (parts.isNotEmpty) {
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

      // Approval stage filters
      final List<String> states = [];
      if (firstApproval == true) states.addAll(['confirm']);
      if (secondApproval == true) states.add('validate1');

      if (states.isNotEmpty) {
        domain.add(['state', 'in', states.toSet().toList()]);
      }

      // Version-aware fields
      List<String> fields;
      if (majorVersion >= 18) {
        fields = [
          'id',
          'name',
          'employee_id',
          'request_date_from',
          'request_date_to',
          'state',
          'holiday_status_id',
          'display_name',
        ];
      } else {
        fields = [
          'id',
          'name',
          'employee_id',
          'request_date_from',
          'request_date_to',
          'state',
          'holiday_status_id',
          'number_of_days_display',
          'display_name',
        ];
      }

      final records = await CompanySessionManager.callKwWithCompany({
        'model': 'hr.leave',
        'method': 'search_read',
        'args': [domain],
        'kwargs': {
          'limit': itemsPerPage,
          'offset': offset,
          'order': 'request_date_from desc',
          'fields': fields,
        },
      });

      return records != null ? List<Map<String, dynamic>>.from(records) : [];
    } catch (e) {
      return [];
    }
  }

  /// Counts total number of pending leave requests matching current filters/search.
  ///
  /// Used for pagination metadata (total pages, range display).
  Future<int> pendingLeaveCount({
    String? searchQuery,
    bool? firstApproval,
    bool? secondApproval,
  }) async {
    try {
      final List domain = [];

      domain.add([
        'state',
        'not in',
        ['validate', 'draft', 'refuse'],
      ]);

      // Same search logic as loadPendingLeaves
      if (searchQuery != null && searchQuery.isNotEmpty) {
        final parts = searchQuery
            .split('-')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();

        final employeeResult = await CompanySessionManager.callKwWithCompany({
          'model': 'hr.employee',
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

        if (employeeResult != null && employeeResult.isNotEmpty) {
          domain.add([
            'employee_id',
            'in',
            employeeResult.map((e) => e['id']).toList(),
          ]);
        } else {
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
            domain.add([
              'holiday_status_id',
              'in',
              typeResult.map((e) => e['id']).toList(),
            ]);
          } else if (parts.isNotEmpty) {
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
      if (firstApproval == true) states.addAll(['confirm']);
      if (secondApproval == true) states.add('validate1');

      if (states.isNotEmpty) {
        domain.add(['state', 'in', states.toSet().toList()]);
      }

      final count = await CompanySessionManager.callKwWithCompany({
        'model': 'hr.leave',
        'method': 'search_count',
        'args': [domain],
        'kwargs': {},
      });

      return count ?? 0;
    } catch (e) {
      return 0;
    }
  }

  /// Performs first-level approval on a leave request.
  ///
  /// Calls Odoo's `action_approve` method.
  /// Returns `null` on success, or error message on failure.
  Future<String?> approveLeave(int id) async {
    try {
      await CompanySessionManager.callKwWithCompany({
        'model': 'hr.leave',
        'method': 'action_approve',
        'args': [
          [id],
        ],
        'kwargs': {},
      });
      return null;
    } on OdooException catch (e) {
      return extractOdooValidationError(e) ??
          "Unexpected error occurred while approving leave";
    } catch (e) {
      return "Unexpected error occurred while approving leave";
    }
  }

  /// Performs final validation (second approval) on a leave request.
  ///
  /// Calls Odoo's `action_validate` method.
  /// Returns `null` on success, or error message on failure.
  Future<String?> validateLeave(int id) async {
    try {
      await CompanySessionManager.callKwWithCompany({
        'model': 'hr.leave',
        'method': 'action_validate',
        'args': [
          [id],
        ],
        'kwargs': {},
      });
      return null;
    } on OdooException catch (e) {
      return extractOdooValidationError(e) ??
          "Unexpected error occurred while approving leave";
    } catch (e) {
      return "Unexpected error occurred while approving leave";
    }
  }

  /// Rejects a pending leave request.
  ///
  /// Calls Odoo's `action_refuse` method.
  /// Returns `null` on success, or error message on failure.
  Future<String?> rejectLeave(int id) async {
    try {
      await CompanySessionManager.callKwWithCompany({
        'model': 'hr.leave',
        'method': 'action_refuse',
        'args': [
          [id],
        ],
        'kwargs': {},
      });
      return null;
    } on OdooException catch (e) {
      return extractOdooValidationError(e) ??
          "Unexpected error occurred while rejecting leave";
    } catch (e) {
      return "Unexpected error occurred while rejecting leave";
    }
  }

  /// Attempts to extract a human-readable error message from an Odoo ValidationError.
  ///
  /// Parses the exception string looking for content after "ValidationError:".
  String? extractOdooValidationError(OdooException e) {
    final text = e.toString();

    final match = RegExp(
      r'ValidationError:\s*([\s\S]*?)(?=, message:|, arguments:|, context:|\}$)',
    ).firstMatch(text);

    if (match != null) {
      return match.group(1)!.trim();
    }
    return null;
  }
}
