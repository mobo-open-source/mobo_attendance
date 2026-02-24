import 'package:odoo_rpc/odoo_rpc.dart';

import '../../../../CommonWidgets/core/company/session/company_session_manager.dart';

/// Service class to handle attendance creation and employee-related operations
/// through Odoo RPC calls.
///
/// This class interacts with Odoo's `hr.attendance` and `hr.employee` models
/// using `CompanySessionManager` to manage sessions and RPC calls.
///
/// Responsibilities:
/// - Create attendance records for employees.
/// - Fetch employee list and individual employee details.
/// - Check if an employee has already checked in.
/// - Extract and handle errors returned by Odoo exceptions.
class AttendanceCreateService {

  /// Initializes the Odoo RPC client for the current company session.
  ///
  /// Throws an [Exception] if there is no active session.
  Future<void> initializeClient() async {
    final session = await CompanySessionManager.getCurrentSession();
    if (session == null) throw Exception("No active session");
  }

  /// Creates a new attendance record for an employee.
  ///
  /// [data] is a map containing attendance fields, e.g., employee_id, check_in, check_out.
  ///
  /// Returns a map with the following keys:
  /// - `success` (bool) – indicates if creation succeeded.
  /// - `attendance_id` (dynamic) – the ID of the newly created attendance (if successful).
  /// - `error` (String?) – error message in case of failure.
  ///
  /// Handles [OdooException] and generic exceptions.
  Future<dynamic> createAttendanceDetails(Map<String, dynamic> data) async {
    try {
      final result = await CompanySessionManager.callKwWithCompany({
        'model': 'hr.attendance',
        'method': 'create',
        'args': [data],
        'kwargs': {},
      });

      return {'success': true, 'attendance_id': result, 'error': null};
    } on OdooException catch (e) {
      final errorMsg = extractOdooError(e);
      return {
        "success": false,
        "employee_id": null,
        "error":
            errorMsg ?? "Failed to create attendance, Please try again later",
      };
    } catch (e) {
      return {
        'success': false,
        'attendance_id': null,
        "error": "Failed to create attendance, Please try again later",
      };
    }
  }

  /// Extracts human-readable error messages from an [OdooException].
  ///
  /// Supports extracting messages from:
  /// - `ValidationError`
  /// - `AccessError`
  /// - `UserError`
  ///
  /// Returns the extracted error message, or null if none is found.
  String? extractOdooError(OdooException e) {
    final text = e.toString();

    // Validation errors
    final validationMatch = RegExp(
      r'ValidationError:\s*([\s\S]*?)(?=, message:|, arguments:|, context:|\}$)',
    ).firstMatch(text);

    if (validationMatch != null) {
      return validationMatch.group(1)!.trim();
    }

    // Access errors
    final accessMatch = RegExp(
      r'name:\s*odoo\.exceptions\.AccessError,\s*message:\s*([\s\S]*?)(?=, arguments:|, context:|\}$)',
      caseSensitive: false,
    ).firstMatch(text);

    if (accessMatch != null) {
      return accessMatch.group(1)!.trim();
    }

    // User errors
    final userMatch = RegExp(
      r'name:\s*odoo\.exceptions\.UserError,\s*message:\s*([\s\S]*?)(?=, arguments:|, context:|\}$)',
      caseSensitive: false,
    ).firstMatch(text);

    if (userMatch != null) {
      return userMatch.group(1)!.trim();
    }

    return null;
  }

  /// Checks if an employee has an active check-in without a check-out.
  ///
  /// [employeeId] – the employee's ID to check.
  ///
  /// Returns `true` if there is an active attendance record, otherwise `false`.
  Future<bool> isEmployeeAlreadyCheckedIn(int employeeId) async {
    await initializeClient();

    final result = await CompanySessionManager.callKwWithCompany({
      'model': 'hr.attendance',
      'method': 'search_read',
      'args': [],
      'kwargs': {
        'domain': [
          ['employee_id', '=', employeeId],
          ['check_out', '=', false],
        ],
        'fields': ['id'],
        'limit': 1,
      },
    });

    return result != null && result.isNotEmpty;
  }

  /// Fetches the list of all employees.
  ///
  /// Returns a list of maps, each representing an employee record.
  /// Returns an empty list in case of any error.
  Future<List<Map<String, dynamic>>> fetchEmployees() async {
    try {
      final employeeItems = await CompanySessionManager.callKwWithCompany({
        'model': 'hr.employee',
        'method': 'search_read',
        'args': [[]],
        'kwargs': {},
      });

      final employeeList = List<Map<String, dynamic>>.from(employeeItems ?? []);
      return employeeList;
    } catch (e) {
      return [];
    }
  }

  /// Fetches detailed information for a specific employee.
  ///
  /// [id] – the ID of the employee.
  ///
  /// Returns a list of maps (usually a single record) containing:
  /// - `id`
  /// - `image_1920` (Base64 image)
  /// - `job_id`
  /// - `work_email`
  ///
  /// Returns an empty list if an error occurs.
  Future<List<Map<String, dynamic>>> fetchEmployeeDetails(int id) async {
    try {
      final result = await CompanySessionManager.callKwWithCompany({
        'model': 'hr.employee',
        'method': 'search_read',
        'args': [
          [
            ['id', '=', id],
          ],
        ],
        'kwargs': {
          'fields': ['id', 'image_1920', 'job_id', 'work_email'],
        },
      });

      final employeeDetails = List<Map<String, dynamic>>.from(result ?? []);
      return employeeDetails;
    } catch (e) {
      return [];
    }
  }
}
