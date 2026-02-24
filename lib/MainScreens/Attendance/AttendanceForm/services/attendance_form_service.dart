import 'package:odoo_rpc/odoo_rpc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../CommonWidgets/core/company/session/company_session_manager.dart';

/// Service class to interact with Odoo attendance and employee records.
///
/// Provides methods for fetching, updating, and validating attendance entries,
/// as well as retrieving employee information and checking permissions.
class AttendanceFormService {
  /// Initializes the Odoo client session.
  ///
  /// Throws an [Exception] if no active session is found.
  Future<void> initializeClient() async {
    final session = await CompanySessionManager.getCurrentSession();
    if (session == null) throw Exception("No active session");
  }

  /// Fetches attendance data for a specific attendance record ID.
  ///
  /// Enriches the attendance data with employee information like image, job, and email.
  /// Returns an empty list if no record is found or an error occurs.
  Future<List<Map<String, dynamic>>> fetchAttendance(int attendanceId) async {
    try {
      final attendanceItems = await CompanySessionManager.callKwWithCompany({
        'model': 'hr.attendance',
        'method': 'search_read',
        'args': [
          [
            ['id', '=', attendanceId],
          ],
        ],
        'kwargs': {},
      });

      if (attendanceItems == null || attendanceItems is! List) {
        return [];
      }

      final attendanceList = List<Map<String, dynamic>>.from(
        attendanceItems.whereType<Map<String, dynamic>>(),
      );

      if (attendanceList.isNotEmpty) {
        final empField = attendanceList[0]['employee_id'];
        final empId = (empField is List && empField.isNotEmpty)
            ? empField[0]
            : null;

        final safeFields = ['id', 'job_id', 'work_email', 'image_1920'];

        if (empId != null) {
          final employeeData = await CompanySessionManager.callKwWithCompany({
            'model': 'hr.employee',
            'method': 'search_read',
            'args': [
              [
                ['id', '=', empId],
              ],
            ],
            'kwargs': {'fields': safeFields},
          });

          if (employeeData != null &&
              employeeData is List &&
              employeeData.isNotEmpty) {
            final emp = employeeData[0] as Map<String, dynamic>;
            attendanceList[0]['employee_image'] = emp['image_1920'];
            attendanceList[0]['job'] = emp['job_id'] is List
                ? emp['job_id'][1]
                : null;
            attendanceList[0]['work_email'] = emp['work_email'];
          }
        }
      }

      return attendanceList;
    } catch (e) {
      return [];
    }
  }

  /// Checks whether an employee is already checked in (i.e., has an open attendance).
  ///
  /// Returns `true` if the employee is currently checked in, otherwise `false`.
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

  /// Updates an attendance record with the given [data].
  ///
  /// Returns a map containing `success` status and `error` message if any.
  /// Handles Odoo exceptions gracefully using [extractOdooError].
  Future<Map<String, dynamic>> updateAttendance(
    int attendanceId,
    Map<String, dynamic> data,
  ) async {
    try {
      final result = await CompanySessionManager.callKwWithCompany({
        'model': 'hr.attendance',
        'method': 'write',
        'args': [
          [attendanceId],
          data,
        ],
        'kwargs': {},
      });
      return {'success': result == true, 'error': null};
    } on OdooException catch (e) {
      final errorMsg = extractOdooError(e);
      return {
        "success": false,
        "employee_id": null,
        "error":
            errorMsg ?? "Failed to update attendance, Please try again later",
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to save attendance, try again later',
      };
    }
  }

  /// Extracts user-friendly error messages from an [OdooException].
  ///
  /// Handles `ValidationError`, `AccessError`, and `UserError`.
  /// Returns `null` if no specific error message is found.
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

  /// Parses the major version number from a server version string.
  ///
  /// Example: "18.0.1" → 18
  int parseMajorVersion(String serverVersion) {
    final match = RegExp(r'\d+').firstMatch(serverVersion);
    if (match != null) {
      return int.tryParse(match.group(0)!) ?? 0;
    }
    return 0;
  }

  /// Checks whether the current user has permission to manage skills.
  ///
  /// Uses `SharedPreferences` to retrieve server version and user ID,
  /// and checks the `base.group_system` group in Odoo.
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

    return await hasGroup('base.group_system');
  }

  /// Fetches a list of all employees with basic fields.
  ///
  /// Returns an empty list if an error occurs.
  Future<List<Map<String, dynamic>>> fetchEmployees() async {
    try {
      final employeeItems = await CompanySessionManager.callKwWithCompany({
        'model': 'hr.employee',
        'method': 'search_read',
        'args': [[]],
        'kwargs': {
          'fields': ['id', 'name', 'image_1920', 'job_id', 'work_email'],
        },
      });

      final employeeList = List<Map<String, dynamic>>.from(employeeItems ?? []);
      return employeeList;
    } catch (e) {
      return [];
    }
  }

  /// Fetches detailed information for a specific employee [id].
  ///
  /// Includes `image_1920` if the current user has permission to manage skills.
  /// Returns an empty list if no record is found or an error occurs.
  Future<List<Map<String, dynamic>>> fetchEmployeeDetails(int id) async {
    try {
      final canSeeExtraFields = await canManageSkills();
      final safeFields = ['id', 'job_id', 'work_email'];
      if (canSeeExtraFields) {
        safeFields.addAll(['image_1920']);
      }
      final result = await CompanySessionManager.callKwWithCompany({
        'model': 'hr.employee',
        'method': 'search_read',
        'args': [
          [
            ['id', '=', id],
          ],
        ],
        'kwargs': {'fields': safeFields},
      });

      final employeeDetails = List<Map<String, dynamic>>.from(result ?? []);
      return employeeDetails;
    } catch (e) {
      return [];
    }
  }
}
