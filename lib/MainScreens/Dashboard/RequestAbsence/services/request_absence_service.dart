import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:odoo_rpc/odoo_rpc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../CommonWidgets/core/company/session/company_session_manager.dart';

/// Service layer responsible for all backend operations related to creating
/// employee leave/absence requests in Odoo (`hr.leave` model).
///
/// Features:
/// - Session initialization check
/// - Loading available leave types (with allocation/validation rules)
/// - Loading employees (for multi-employee requests if allowed)
/// - Fetching current user's linked employee ID
/// - Overlap checking (prevents double-booking)
/// - Version-aware leave creation (Odoo 18+ differences)
/// - Supporting document upload (`ir.attachment`)
/// - Error extraction from Odoo ValidationError
class RequestAbsenceService {
  /// Ensures an active Odoo session exists before making any RPC calls.
  ///
  /// Throws exception if no session is available.
  Future<void> initializeClient() async {
    final session = await CompanySessionManager.getCurrentSession();
    if (session == null) throw Exception("No active session");
  }

  /// Loads available leave types (`hr.leave.type`) that the current user can request.
  ///
  /// Filters types based on allocation rules:
  /// - No allocation required
  /// - OR has valid allocation with remaining leaves > 0
  ///
  /// Returns empty list on error or no types available.
  Future<List<Map<String, dynamic>>> loadLeaveType() async {
    try {

      final domain = [
        '|',
        ['requires_allocation', '=', 'no'],
        '&',
        ['has_valid_allocation', '=', true],
        '&',
        ['max_leaves', '>', 0],
        '|',
        ['allows_negative', '=', true],
        '&',
        ['virtual_remaining_leaves', '>', 0],
        ['allows_negative', '=', false],
      ];

      final response = await CompanySessionManager.callKwWithCompany({
        'model': 'hr.leave.type',
        'method': 'search_read',
        'args': [domain],
        'kwargs': {
          'fields': ['id', 'name', 'support_document', 'request_unit'],
        },
      });

      if (response != null) {
        return List<Map<String, dynamic>>.from(response);
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  /// Loads list of employees that can be selected for the leave request.
  ///
  /// Currently fetches all employees — in production you may want to restrict
  /// this list (e.g. only subordinates or active employees).
  ///
  /// Returns empty list on error.
  Future<List<Map<String, dynamic>>> loadEmployees() async {
    try {

      final response = await CompanySessionManager.callKwWithCompany({
        'model': 'hr.employee',
        'method': 'search_read',
        'args': [[]],
        'kwargs': {
          'fields': ['id', 'name'],
        },
      });

      if (response != null) {
        return List<Map<String, dynamic>>.from(response);
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  /// Finds the employee ID linked to the currently authenticated user.
  ///
  /// Returns 0 if no matching employee is found or on error.
  Future<int> loadCurrentEmployeeId() async {
    try {

      final prefs = await SharedPreferences.getInstance();
      int userId = prefs.getInt('userId') ?? 0;

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

      return employeeResult[0]['id'];
    } catch (e) {
      return 0;
    }
  }

  /// Converts Dart DateTime to Odoo-compatible datetime string
  /// (YYYY-MM-DD HH:MM:SS format).
  String odooDate(DateTime dt) {
    return dt.toIso8601String().split('.').first.replaceFirst('T', ' ');
  }

  /// Checks if the given employee already has overlapping leave requests
  /// in the specified date range.
  ///
  /// Overlap is defined as any leave in 'draft', 'confirm', or 'validate1'
  /// state that intersects with the requested period.
  ///
  /// Returns `true` if overlap exists, `false` otherwise.
  Future<bool> hasOverlappingLeave(
    int employeeId,
    DateTime from,
    DateTime? to,
  ) async {
    final conditions = [
      ['employee_id', '=', employeeId],
      [
        'state',
        'in',
        ['draft', 'confirm', 'validate1'],
      ],
      ['request_date_to', '>=', from.toIso8601String()],
    ];

    if (to != null) {
      conditions.add(['request_date_from', '<=', to.toIso8601String()]);
    }

    final response = await CompanySessionManager.callKwWithCompany({
      'model': 'hr.leave',
      'method': 'search_read',
      'args': [conditions],
      'kwargs': {
        'fields': ['id', 'request_date_from', 'request_date_to', 'state'],
      },
    });
    return response != null && response.isNotEmpty;
  }

  /// Formats DateTime to YYYY-MM-DD string (used in some UI contexts)
  String formatDate(DateTime date) => date.toIso8601String().split('T').first;

  /// Extracts major version number from Odoo's `server_version` string
  /// (e.g. "18.0" → 18, "16.0+e" → 16)
  int parseMajorVersion(String serverVersion) {
    final match = RegExp(r'\d+').firstMatch(serverVersion);
    if (match != null) {
      return int.tryParse(match.group(0)!) ?? 0;
    }
    return 0;
  }

  /// Creates a new leave/absence request in Odoo (`hr.leave` model).
  ///
  /// Handles version-specific field differences (Odoo 18+ removed some fields).
  /// Uploads attachment separately if needed.
  ///
  /// Returns map with:
  /// - `success`: true/false
  /// - `id`: created record ID (on success)
  /// - `error`: human-readable message (on failure)
  Future<Map<String, dynamic>> createRequestAbsence(
    Map<String, dynamic> data,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String version = prefs.getString('serverVersion') ?? '0';
      final int majorVersion = parseMajorVersion(version);

      final cleanData = Map<String, dynamic>.from(data);

      if (majorVersion >= 18) {
        cleanData.remove('number_of_days_display');
        cleanData.remove('employee_ids');
      }

      final response = await CompanySessionManager.callKwWithCompany({
        'model': 'hr.leave',
        'method': 'create',
        'args': [cleanData],
        'kwargs': {},
      });

      if (response != null) {
        return {"success": true, "id": response};
      } else {
        return {"success": false, "error": "Invalid response from server"};
      }
    } on OdooException catch (e) {
      return {
        "success": false,
        "error":extractOdooValidationError(e)??"Failed to create leave, Please try again later.",
      };
    } catch (e) {
      return {
        "success": false,
        "error":
            "Failed to create Leave, please try again later or check You've already booked time off which overlaps with this period",
      };
    }
  }

  /// Attempts to extract human-readable message from Odoo `ValidationError`.
  ///
  /// Parses exception string to find content after "ValidationError:".
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

  /// Uploads a supporting document as an `ir.attachment` record.
  ///
  /// Links the attachment to the `hr.leave` model.
  ///
  /// Returns created attachment ID on success, null on failure.
  Future<int?> uploadAttachment({
    required PlatformFile file,
    required String model,
  }) async {
    final bytes = file.bytes ?? await File(file.path!).readAsBytes();

    final attachmentId = await CompanySessionManager.callKwWithCompany({
      'model': 'ir.attachment',
      'method': 'create',
      'args': [
        {
          'name': file.name,
          'datas': base64Encode(bytes),
          'res_model': model,
          'type': 'binary',
        },
      ],
      'kwargs': {},
    });

    return attachmentId as int?;
  }
}
