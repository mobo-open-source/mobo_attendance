import 'package:odoo_rpc/odoo_rpc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../CommonWidgets/core/company/session/company_session_manager.dart';

/// Service responsible for attendance-related Odoo RPC operations.
///
/// Main responsibilities:
///   - Fetch paginated attendance records with filters
///   - Count attendances matching filter criteria
///   - Delete individual attendance records
///   - Resolve current user's employee ID and subordinate employee IDs
///   - Flexible date parsing from search input
///   - Attach employee profile images to attendance records
class AttendanceListService {
  int? userId;

  /// Ensures an active Odoo session exists.
  /// Throws exception if no session is found.
  Future<void> initializeClient() async {
    final session = await CompanySessionManager.getCurrentSession();
    if (session == null) throw Exception("No active session");
  }

  /// Finds all employees whose `parent_id` has `user_id` matching the current user.
  /// Used to determine "my team" members (direct subordinates).
  ///
  /// Returns list of employee IDs or empty list on error / no matches.
  Future<List<int>> getEmployeeIdsByParentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      userId = prefs.getInt('userId') ?? 0;

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

  /// Looks up the `hr.employee` record linked to the current logged-in user.
  ///
  /// Returns employee ID or `null` if no matching employee is found or on error.
  Future<int?> getEmployeeIdByUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      userId = prefs.getInt('userId') ?? 0;

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

  /// Counts number of `hr.attendance` records matching the given filters.
  ///
  /// Supported filters (all optional):
  ///   - [searchText]     → employee name/email or flexible date (e.g. "15 mar", "2024", "june 12")
  ///   - [myAttendance]   → only records of current user
  ///   - [myTeam]         → only records of direct subordinates
  ///   - [atWork]         → check_out is false (still clocked in)
  ///   - [Errors]         → suspicious records (≥16h or no checkout + old check-in)
  ///   - [last7days]      → check_in in last 7 calendar days
  ///
  /// Returns count or 0 if domain results in no records or on error.
  Future<int> AttendanceCount({
    String? searchText,
    bool? myAttendance,
    bool? myTeam,
    bool? atWork,
    bool? Errors,
    bool? last7days,
  }) async {
    try {
      final List domain = [];

      if (last7days == true) {
        final now = DateTime.now();
        final last7 = now.subtract(Duration(days: 7));

        final formatted = "${last7.toIso8601String().split('T')[0]} 00:00:00";

        domain.add(['check_in', '>=', formatted]);
      }

      if (Errors == true) {
        final now = DateTime.now();
        final yesterday = now.subtract(Duration(days: 1));

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

      if (atWork == true) {
        domain.add(['check_out', '=', false]);
      }

      if (myTeam == true) {
        final empIds = await getEmployeeIdsByParentUser();

        if (empIds.isNotEmpty) {
          domain.add(['employee_id', 'in', empIds]);
        } else {
          return 0;
        }
      }

      if (myAttendance == true) {
        final empId = await getEmployeeIdByUserId();
        if (empId != null) {
          domain.add(['employee_id', '=', empId]);
        } else {
          return 0;
        }
      }

      if (searchText != null && searchText.isNotEmpty) {
        final parsed = _parseFlexibleDate(searchText);

        if (parsed != null) {
          final range = _buildDateRange(
            year: parsed['year']!,
            month: parsed['month'],
            day: parsed['day'],
          );

          domain.addAll([
            '|',
            '&',
            ['check_in', '>=', range['start']],
            ['check_in', '<=', range['end']],
            '&',
            ['check_out', '>=', range['start']],
            ['check_out', '<=', range['end']],
          ]);
        } else {
          final empResult = await CompanySessionManager.callKwWithCompany({
            'model': 'hr.employee',
            'method': 'search_read',
            'args': [
              [
                '|',
                ['name', 'ilike', searchText],
                ['work_email', 'ilike', searchText],
              ],
            ],
            'kwargs': {
              'fields': ['id'],
            },
          });

          if (empResult != null && empResult.isNotEmpty) {
            final employeeIds = empResult.map((e) => e['id']).toList();
            domain.add(['employee_id', 'in', employeeIds]);
          } else {
            return 0;
          }
        }
      }

      final attendanceCount = await CompanySessionManager.callKwWithCompany({
        'model': 'hr.attendance',
        'method': 'search_count',
        'args': [domain],
        'kwargs': {},
      });
      return attendanceCount ?? 0;
    } catch (e) {
      throw Exception('Failed to count Attendance: $e');
    }
  }

  /// Deletes a single attendance record by ID.
  ///
  /// Returns:
  ///   - `null`               → success
  ///   - error message string → failure (tries to extract meaningful Odoo message)
  Future<String?> deleteAttendance(int id) async {
    try {
      await CompanySessionManager.callKwWithCompany({
        'model': 'hr.attendance',
        'method': 'unlink',
        'args': [
          [id],
        ],
        'kwargs': {},
      });
      return null;
    } on OdooException catch (e) {
      return extractOdooError(e) ??
          "Something went wrong, Please try again later";
    } catch (e) {
      return "Unexpected error occurred while deleting attendance";
    }
  }

  /// Attempts to extract a user-friendly error message from OdooException.
  ///
  /// Looks for ValidationError, AccessError, UserError messages.
  /// Falls back to null if no clear message is found.
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

  /// Maps short/full month names → month number (1–12)
  final Map<String, int> _monthMap = {
    'jan': 1,
    'january': 1,
    'feb': 2,
    'february': 2,
    'mar': 3,
    'march': 3,
    'apr': 4,
    'april': 4,
    'may': 5,
    'jun': 6,
    'june': 6,
    'jul': 7,
    'july': 7,
    'aug': 8,
    'august': 8,
    'sep': 9,
    'september': 9,
    'oct': 10,
    'october': 10,
    'nov': 11,
    'november': 11,
    'dec': 12,
    'december': 12,
  };

  /// Very flexible natural-language date parser for search input.
  ///
  /// Supported formats (case insensitive, partial):
  ///   - "15 mar 2024"
  ///   - "june"
  ///   - "2023"
  ///   - "12/05/24" (day/month/year assumed)
  ///   - "november 5"
  ///
  /// Returns map with at least {'year': int}, optionally {'month', 'day'}
  /// or `null` if no date-like information was detected.
  Map<String, int?>? _parseFlexibleDate(String input) {
    final text = input.toLowerCase().trim();

    int? year, month, day;

    final parts = text.split(RegExp(r'[\s/-]+'));

    for (final part in parts) {
      final num = int.tryParse(part);

      if (num != null && num > 1900 && num < 2100) {
        year = num;
      } else if (num != null && num >= 1 && num <= 31) {
        day ??= num;
      } else if (num != null && num >= 1 && num <= 12) {
        month ??= num;
      } else if (_monthMap.containsKey(part)) {
        month = _monthMap[part];
      }
    }

    if (year != null && month == null && day == null) {
      return {'year': year};
    }

    if (month != null && year == null && day == null) {
      return {'year': DateTime.now().year, 'month': month};
    }

    if (year != null || month != null || day != null) {
      return {'year': year ?? DateTime.now().year, 'month': month, 'day': day};
    }

    return null;
  }

  /// Builds ISO-like start/end datetime strings (Odoo compatible) for a year/month/day range.
  ///
  /// - Day given   → that single day (00:00 – 23:59:59)
  /// - Month given → whole month
  /// - Only year   → whole year
  Map<String, String> _buildDateRange({
    required int year,
    int? month,
    int? day,
  }) {
    late DateTime start;
    late DateTime end;

    if (day != null && month != null) {
      start = DateTime(year, month, day);
      end = start
          .add(const Duration(days: 1))
          .subtract(const Duration(seconds: 1));
    } else if (month != null) {
      start = DateTime(year, month, 1);
      end = DateTime(year, month + 1, 1).subtract(const Duration(seconds: 1));
    } else {
      start = DateTime(year, 1, 1);
      end = DateTime(year + 1, 1, 1).subtract(const Duration(seconds: 1));
    }

    return {
      'start': "${start.toIso8601String().split('T')[0]} 00:00:00",
      'end': "${end.toIso8601String().split('T')[0]} 23:59:59",
    };
  }

  /// Main method — fetches paginated attendance records with filters + employee images.
  ///
  /// Parameters:
  ///   - [page]           0-based page index
  ///   - [itemsPerPage]   records per page
  ///   - filters (same as [AttendanceCount])
  ///
  /// Behavior:
  ///   - Builds domain from filters
  ///   - Fetches `hr.attendance` records
  ///   - Collects unique employee IDs
  ///   - Fetches `image_1920` for those employees
  ///   - Injects `employee_image` field into each attendance record
  ///
  /// Returns list of attendance maps or empty list on any error.
  Future<List<Map<String, dynamic>>> fetchAttendance(
    int page,
    int itemsPerPage, {
    String? searchText,
    bool? myAttendance,
    bool? myTeam,
    bool? atWork,
    bool? Errors,
    bool? last7days,
  }) async {
    try {
      final offset = page * itemsPerPage;
      final List domain = [];

      if (last7days == true) {
        final now = DateTime.now();
        final last7 = now.subtract(Duration(days: 7));

        final formatted = "${last7.toIso8601String().split('T')[0]} 00:00:00";

        domain.add(['check_in', '>=', formatted]);
      }

      if (Errors == true) {
        final now = DateTime.now();
        final yesterday = now.subtract(Duration(days: 1));

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

      if (atWork == true) {
        domain.add(['check_out', '=', false]);
      }

      if (myTeam == true) {
        final empIds = await getEmployeeIdsByParentUser();

        if (empIds.isNotEmpty) {
          domain.add(['employee_id', 'in', empIds]);
        }
      }

      if (myAttendance == true) {
        final empId = await getEmployeeIdByUserId();
        if (empId != null) {
          domain.add(['employee_id', '=', empId]);
        }
      }

      if (searchText != null && searchText.isNotEmpty) {
        final parsed = _parseFlexibleDate(searchText);

        if (parsed != null) {
          final range = _buildDateRange(
            year: parsed['year']!,
            month: parsed['month'],
            day: parsed['day'],
          );

          domain.addAll([
            '|',
            '&',
            ['check_in', '>=', range['start']],
            ['check_in', '<=', range['end']],
            '&',
            ['check_out', '>=', range['start']],
            ['check_out', '<=', range['end']],
          ]);
        } else {
          final empResult = await CompanySessionManager.callKwWithCompany({
            'model': 'hr.employee',
            'method': 'search_read',
            'args': [
              [
                '|',
                ['name', 'ilike', searchText],
                ['work_email', 'ilike', searchText],
              ],
            ],
            'kwargs': {
              'fields': ['id'],
            },
          });

          if (empResult != null && empResult.isNotEmpty) {
            final employeeIds = empResult.map((e) => e['id']).toList();
            domain.add(['employee_id', 'in', employeeIds]);
          } else {
            return [];
          }
        }
      }

      final attendanceItems = await CompanySessionManager.callKwWithCompany({
        'model': 'hr.attendance',
        'method': 'search_read',
        'args': [domain],
        'kwargs': {'limit': itemsPerPage, 'offset': offset},
      });

      final attendanceList = List<Map<String, dynamic>>.from(
        attendanceItems ?? [],
      );

      final employeeIds = attendanceList
          .map((item) => item['employee_id']?[0])
          .where((id) => id != null)
          .toSet()
          .toList();

      if (employeeIds.isNotEmpty) {
        final employeeData = await CompanySessionManager.callKwWithCompany({
          'model': 'hr.employee',
          'method': 'search_read',
          'args': [
            [
              ['id', 'in', employeeIds],
            ],
          ],
          'kwargs': {
            'fields': ['id', 'image_1920'],
          },
        });

        final Map<int, dynamic> employeeImageMap = {
          for (var emp in employeeData) emp['id']: emp['image_1920'],
        };

        for (var item in attendanceList) {
          final empId = item['employee_id']?[0];
          if (empId != null && employeeImageMap.containsKey(empId)) {
            item['employee_image'] = employeeImageMap[empId];
          }
        }
      }
      return attendanceList;
    } catch (e) {
      return [];
    }
  }

  /// Extracts the major version number from Odoo's server_version string.
  ///
  /// Examples:
  ///   "18.0+e"   → 18
  ///   "16.0"     → 16
  ///   "Saas~123" → 0 (fallback)
  int parseMajorVersion(String serverVersion) {
    final match = RegExp(r'\d+').firstMatch(serverVersion);
    if (match != null) {
      return int.tryParse(match.group(0)!) ?? 0;
    }
    return 0;
  }

  /// Checks whether current user belongs to 'base.group_system' (Settings / Technical access).
  ///
  /// Used in some UIs to conditionally show advanced features.
  ///
  /// Handles difference in `has_group` signature between Odoo 17 and 18+.
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
        }) == true;
      } else {
        return await CompanySessionManager.callKwWithCompany({
          'model': 'res.users',
          'method': 'has_group',
          'args': [groupExtId],
          'kwargs': {},
        }) == true;
      }
    }

    return await hasGroup('base.group_system');
  }
}
