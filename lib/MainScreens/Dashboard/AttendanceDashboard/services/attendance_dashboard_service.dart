import 'dart:convert';

import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:odoo_rpc/odoo_rpc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../CommonWidgets/core/company/session/company_session_manager.dart';

/// Service layer responsible for all backend communication related to the
/// attendance dashboard.
///
/// Handles:
/// - Odoo RPC calls (via CompanySessionManager)
/// - Version-aware logic (differences between Odoo 17 / 18+)
/// - Employee check-in / check-out
/// - Statistics (present/absent counts, punctuality, pending leaves)
/// - Trends (absenteeism last 7 days)
/// - Profile image loading
/// - Location + IP collection
class AttendanceDashboardService {
  /// Extracts the major version number from Odoo's server_version string
  /// (e.g. "18.0" → 18, "16.0+e" → 16)
  int parseMajorVersion(String serverVersion) {
    final match = RegExp(r'\d+').firstMatch(serverVersion);
    if (match != null) {
      return int.tryParse(match.group(0)!) ?? 0;
    }
    return 0;
  }

  /// Checks whether current user belongs to the Attendance Manager group
  /// (`hr_attendance.group_hr_attendance_manager`)
  ///
  /// Uses version-aware argument order (Odoo 18+ requires user_id as first arg)
  Future<bool> isAdmin() async {
    final prefs = await SharedPreferences.getInstance();
    final String version = prefs.getString('serverVersion') ?? '0';
    final int userId = prefs.getInt('userId') ?? 0;
    final int majorVersion = parseMajorVersion(version);

    if (majorVersion >= 18) {
      return await CompanySessionManager.callKwWithCompany({
            'model': 'res.users',
            'method': 'has_group',
            'args': [userId,'hr_attendance.group_hr_attendance_manager'],
            'kwargs': {},
          }) ==
          true;
    } else {
      return await CompanySessionManager.callKwWithCompany({
            'model': 'res.users',
            'method': 'has_group',
            'args': ['hr_attendance.group_hr_attendance_manager'],
            'kwargs': {},
          }) ==
          true;
    }
  }

  /// Returns last 7 days absenteeism trend (count + employee IDs per day)
  ///
  /// Note: currently counts open attendances as "absent" which may not be accurate
  Future<List<Map<String, dynamic>>> getAbsenteeismTrendLast7Days() async {
    try {
      final today = DateTime.now();
      final sevenDaysAgo = today.subtract(const Duration(days: 6));

      final List<String> last7Dates = List.generate(7, (i) {
        final date = sevenDaysAgo.add(Duration(days: i));
        return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
      });

      List<Map<String, dynamic>> trend = [];

      for (final dateStr in last7Dates) {
        final start = "$dateStr 00:00:00";
        final end = "$dateStr 23:59:59";

        final result = await CompanySessionManager.callKwWithCompany({
          'model': 'hr.attendance',
          'method': 'search_read',
          'args': [
            [
              ['check_in', '>=', start],
              ['check_in', '<=', end],
              ['check_out', '=', false],
            ],
          ],
          'kwargs': {
            'fields': ['id', 'employee_id'],
          },
        });

        List<int> absentEmployeeIds = [];
        if (result != null && result is List) {
          for (final record in result) {
            if (record['employee_id'] != null) {
              absentEmployeeIds.add(record['employee_id'][0]);
            }
          }
        }

        trend.add({
          'date': dateStr,
          'absentCount': absentEmployeeIds.length,
          'absentEmployeeIds': absentEmployeeIds,
        });
      }

      return trend;
    } catch (e) {
      return [];
    }
  }

  /// Determines if current user has HR Leave Manager rights
  /// (`hr_holidays.group_hr_holidays_user`)
  Future<bool> isHrLeaveManager() async {
    final prefs = await SharedPreferences.getInstance();
    final String version = prefs.getString('serverVersion') ?? '0';
    final int userId = prefs.getInt('userId') ?? 0;

    final int majorVersion = parseMajorVersion(version);

    if (majorVersion >= 18) {
      return await CompanySessionManager.callKwWithCompany({
            'model': 'res.users',
            'method': 'has_group',
            'args': [userId, 'hr_holidays.group_hr_holidays_user'],
            'kwargs': {},
          }) ==
          true;
    } else {
      return await CompanySessionManager.callKwWithCompany({
            'model': 'res.users',
            'method': 'has_group',
            'args': ['hr_holidays.group_hr_holidays_user'],
            'kwargs': {},
          }) ==
          true;
    }
  }

  /// Returns total number of employees (hr.employee records)
  Future<int> staffCount() async {
    try {
      final employeeCount = await CompanySessionManager.callKwWithCompany({
        'model': 'hr.employee',
        'method': 'search_count',
        'args': [[]],
        'kwargs': {},
      });
      return employeeCount ?? 0;
    } catch (e) {
      throw Exception('Failed to count Employees: $e');
    }
  }

  /// Returns count and IDs of employees who currently have an open attendance
  /// record (check_out = false)
  Future<Map<String, dynamic>> getPresentEmployees() async {
    try {
      final result = await CompanySessionManager.callKwWithCompany({
        'model': 'hr.attendance',
        'method': 'read_group',
        'args': [
          [
            ['check_out', '=', false],
          ],
          ['employee_id'],
          ['employee_id'],
        ],
        'kwargs': {},
      });

      final List<dynamic> attendances = result as List<dynamic>;

      final List<int> employeeIds = attendances
          .map<int>((e) => (e['employee_id'] as List).first as int)
          .toList();

      return {'count': attendances.length, 'employeeIds': employeeIds};
    } catch (e) {
      throw Exception('Failed to get present employees: $e');
    }
  }

  /// Returns count and IDs of employees NOT present today
  /// (all employees minus currently present ones)
  Future<Map<String, dynamic>> getAbsentEmployees(List<int> ids) async {
    try {
      final result =
          await CompanySessionManager.callKwWithCompany({
                'model': 'hr.employee',
                'method': 'search_read',
                'args': [
                  [
                    ['id', 'not in', ids],
                  ],
                ],
                'kwargs': {
                  'fields': ['id', 'name'],
                },
              })
              as List<dynamic>;

      final List<int> employeeIds = result
          .map<int>((e) => e['id'] as int)
          .toList();

      return {'count': result.length, 'employeeIds': employeeIds};
    } catch (e) {
      throw Exception('Failed to get absent employees: $e');
    }
  }

  /// Number of leave requests that are not yet validated, refused or draft
  Future<int> pendingLeaveCount() async {
    try {
      final count = await CompanySessionManager.callKwWithCompany({
        'model': 'hr.leave',
        'method': 'search_count',
        'args': [
          [
            [
              'state',
              'not in',
              ['validate', 'draft', 'refuse'],
            ],
          ],
        ],
        'kwargs': {},
      });

      return count ?? 0;
    } catch (e) {
      throw Exception('Failed to count pending leaves: $e');
    }
  }

  /// Returns list of pending leave requests with relevant fields
  Future<List<Map<String, dynamic>>> pendingLeaves() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String version = prefs.getString('serverVersion') ?? '0';
      final int majorVersion = parseMajorVersion(version);

      List<String> fields;
      if (majorVersion >= 18){
        fields = [
          'name',
          'employee_id',
          'request_date_from',
          'request_date_to',
          'state',
          'holiday_status_id',
        ];
      } else {
        fields = [
          'name',
          'employee_id',
          'request_date_from',
          'request_date_to',
          'state',
          'holiday_status_id',
          'number_of_days_display',
        ];
      }

      final records = await CompanySessionManager.callKwWithCompany({
        'model': 'hr.leave',
        'method': 'search_read',
        'args': [
          [
            [
              'state',
              'not in',
              ['validate', 'draft', 'refuse'],
            ],
          ],
        ],
        'kwargs': {
          'fields': fields,
          'order': 'request_date_from desc',
        },
      });

      return (records as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (e) {
      throw Exception('Failed to load non-validated leaves: $e');
    }
  }

  /// Collects current GPS coordinates + approximate country + public IP
  Future<Map<String, dynamic>> getLocationAndNetworkInfo() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception("Location permission denied");
      }
    }

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    List<Placemark> placemarks = await placemarkFromCoordinates(
      position.latitude,
      position.longitude,
    );

    String country = placemarks.first.country ?? "Unknown";
    String ip = "Unknown";

    try {
      final response = await http.get(
        Uri.parse("https://api.ipify.org?format=json"),
      );
      if (response.statusCode == 200) {
        ip = jsonDecode(response.body)["ip"];
      }
    } catch (_) {}

    return {
      "latitude": position.latitude,
      "longitude": position.longitude,
      "country": country,
      "ip": ip,
    };
  }

  /// Creates a new attendance record (check-in)
  ///
  /// Also calls the systray attendance endpoint for real-time tracking
  Future<bool> createAttendanceDetails(Map<String, dynamic> data) async {
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
        return false;
      }
      data['employee_id'] = employeeResult[0]['id'];

      await CompanySessionManager.callSystrayAttendance(
        latitude: data['in_latitude'],
        longitude: data['in_longitude'],
      );

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Updates the current open attendance record (check-out)
  Future<bool> writeAttendanceDetails(Map<String, dynamic> data) async {
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
        return false;
      }
      data['employee_id'] = employeeResult[0]['id'];
      await CompanySessionManager.callSystrayAttendance(
        latitude: data['out_latitude'],
        longitude: data['out_longitude'],
      );

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Checks if the current user has an open attendance record (check_out = false)
  Future<bool> isEmployeeAlreadyCheckedIn() async {
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
        'fields': ['id', 'name'],
        'limit': 1,
      },
    });

    if (employeeResult == null || employeeResult.isEmpty) {
      return false;
    }
    final employeeId = employeeResult[0]['id'];
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

  /// Returns detailed information about today's (and recent) attendance records
  ///
  /// Includes:
  /// - total worked hours
  /// - first check-in time
  /// - active check-in (if open)
  /// - last check-out time
  /// - list of all recent records
  Future<dynamic> checkInDetails() async {
    final prefs = await SharedPreferences.getInstance();
    int userId = prefs.getInt('userId') ?? 0;
    final String version = prefs.getString('serverVersion') ?? '0';
    final int majorVersion = parseMajorVersion(version);

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
      return null;
    }

    final employeeId = employeeResult[0]['id'];

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final fiveDaysAgo = today.subtract(const Duration(days: 4));

    final tomorrow = today.add(const Duration(days: 1));

    final start = fiveDaysAgo.toIso8601String().split('.').first;
    final end = tomorrow.toIso8601String().split('.').first;

    List<String> fields;
    if (majorVersion >= 19){
      fields = [
        'id',
        'check_in',
        'check_out',
        'worked_hours',
        'in_mode',
        'out_mode',
      ];
    } else {
      fields = [
        'id',
        'check_in',
        'check_out',
        'worked_hours',
        'in_mode',
        'out_mode',
        'in_country_name',
        'out_country_name',
      ];
    }

    final todayRecords = await CompanySessionManager.callKwWithCompany({
      'model': 'hr.attendance',
      'method': 'search_read',
      'args': [],
      'kwargs': {
        'domain': [
          ['employee_id', '=', employeeId],
          ['check_in', '>=', start],
          ['check_in', '<', end],
        ],
        'fields': fields,
        'order': 'check_in asc',
      },
    });

    final activeAttendance = await CompanySessionManager.callKwWithCompany({
      'model': 'hr.attendance',
      'method': 'search_read',
      'args': [],
      'kwargs': {
        'domain': [
          ['employee_id', '=', employeeId],
          ['check_out', '=', false],
        ],
        'fields': ['check_in'],
        'limit': 1,
      },
    });

    double totalWorkedHours = 0.0;
    String? firstCheckIn;
    String? lastCheckOut;
    String? activeCheckIn;

    if (todayRecords != null && todayRecords.isNotEmpty) {
      for (var att in todayRecords) {
        totalWorkedHours += att['worked_hours'] ?? 0.0;

        firstCheckIn ??= att['check_in'];

        if (att['check_out'] != null && att['check_out'] != false) {
          lastCheckOut = att['check_out'];
        }
      }
    }

    if (activeAttendance != null && activeAttendance.isNotEmpty) {
      activeCheckIn = activeAttendance[0]['check_in'];
    }

    if (activeCheckIn != null) {
      final activeDate = DateTime.parse('${activeCheckIn}Z').toLocal();

      if (activeDate.isBefore(today)) {
        firstCheckIn ??= today.toIso8601String();
      }
    }

    return {
      "totalWorkedHours": totalWorkedHours,
      "firstCheckIn": firstCheckIn,
      "activeCheckIn": activeCheckIn,
      "lastCheckOut": lastCheckOut,
      "records": todayRecords ?? [],
    };
  }

  /// Loads base64-encoded profile image (image_1920 field) of current user
  Future<List<Map<String, dynamic>>> loadProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      int userId = prefs.getInt('userId') ?? 0;

      final response = await CompanySessionManager.callKwWithCompany({
        'model': 'res.users',
        'method': 'search_read',
        'args': [
          [
            ['id', '=', userId],
          ],
        ],
        'kwargs': {
          'fields': ['image_1920'],
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

  /// Calculates total worked hours in the current calendar month
  Future<double> getCurrentMonthWorkedHours() async {
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
        return 0.0;
      }

      final employeeId = employeeResult[0]['id'];

      final now = DateTime.now();
      final firstDay = DateTime(now.year, now.month, 1);
      final nextMonth = DateTime(now.year, now.month + 1, 1);

      final start = firstDay.toIso8601String().split('.').first;
      final end = nextMonth.toIso8601String().split('.').first;

      final records = await CompanySessionManager.callKwWithCompany({
        'model': 'hr.attendance',
        'method': 'search_read',
        'args': [],
        'kwargs': {
          'domain': [
            ['employee_id', '=', employeeId],
            ['check_in', '>=', start],
            ['check_in', '<', end],
          ],
          'fields': ['worked_hours'],
          'order': 'check_in asc',
        },
      });

      if (records == null || records.isEmpty) {
        return 0.0;
      }

      double monthlyHours = 0.0;
      for (var att in records) {
        monthlyHours += (att['worked_hours'] ?? 0.0);
      }

      return monthlyHours;
    } catch (e) {
      return 0.0;
    }
  }

  Future<List<Map<String, dynamic>>> getPresentEmployeesToday() async {
    final result = await CompanySessionManager.callKwWithCompany({
      'model': 'hr.attendance',
      'method': 'search_read',
      'args': [
        [
          ['check_out', '=', false],
        ],
      ],
      'kwargs': {
        'fields': ['employee_id', 'check_in'],
      },
    });

    return List<Map<String, dynamic>>.from(result);
  }

  Future<Map<int, int>> getEmployeeCalendars(List<int> employeeIds) async {
    final result = await CompanySessionManager.callKwWithCompany({
      'model': 'hr.employee',
      'method': 'search_read',
      'args': [
        [
          ['id', 'in', employeeIds],
        ],
      ],
      'kwargs': {
        'fields': ['id', 'resource_calendar_id'],
      },
    });

    final map = <int, int>{};

    for (final emp in result) {
      if (emp['resource_calendar_id'] != false) {
        map[emp['id']] = (emp['resource_calendar_id'] as List).first;
      }
    }

    return map;
  }

  Future<Map<int, List<Map<String, dynamic>>>> getCalendarAttendances(
    Set<int> calendarIds,
  ) async {
    final result = await CompanySessionManager.callKwWithCompany({
      'model': 'resource.calendar.attendance',
      'method': 'search_read',
      'args': [
        [
          ['calendar_id', 'in', calendarIds.toList()],
        ],
      ],
      'kwargs': {
        'fields': [
          'calendar_id',
          'dayofweek',
          'hour_from',
          'hour_to',
          'day_period',
        ],
      },
    });

    final map = <int, List<Map<String, dynamic>>>{};

    for (final att in result) {
      final calId = (att['calendar_id'] as List).first;
      map.putIfAbsent(calId, () => []).add(att);
    }

    return map;
  }

  /// Returns today's punctuality classification (on time, late, early)
  /// based on resource calendar rules
  Future<AttendanceStatus> getTodayAttendanceStatusCounts({
    int graceMinutes = 0,
  }) async {
    int onTime = 0;
    int lateIn = 0;
    int earlyIn = 0;

    List<int> onTimeIds = [];
    List<int> lateInIds = [];
    List<int> earlyInIds = [];

    final present = await getPresentEmployeesToday();

    if (present.isEmpty) {
      return AttendanceStatus(
        onTime: 0,
        lateIn: 0,
        earlyIn: 0,
        onTimeIds: [],
        lateInIds: [],
        earlyInIds: [],
      );
    }

    final List<int> employeeIds = present
        .map<int>((e) => (e['employee_id'] as List).first as int)
        .toList();

    final employeeCalendars = await getEmployeeCalendars(employeeIds);

    final calendarAttendances = await getCalendarAttendances(
      employeeCalendars.values.toSet(),
    );

    final today = DateTime.now();
    final todayWeekday = (today.weekday - 1).toString();

    for (final attendance in present) {
      final empId = (attendance['employee_id'] as List).first;
      final checkIn = DateTime.parse("${attendance['check_in']}Z").toLocal();

      final calendarId = employeeCalendars[empId];

      double hourFrom = 9.0;

      if (calendarId != null) {
        final rules = calendarAttendances[calendarId] ?? [];

        if (rules.isNotEmpty) {
          final todayRule = rules.firstWhere(
            (r) => r['dayofweek'] == todayWeekday,
            orElse: () => {},
          );

          if (todayRule.isNotEmpty) {
            hourFrom = (todayRule['hour_from'] as num).toDouble();
          } else {
            hourFrom = rules.first['hour_from'];
          }
        }
      }

      final scheduledTime = DateTime(
        today.year,
        today.month,
        today.day,
        hourFrom.floor(),
        ((hourFrom % 1) * 60).round(),
      );

      final diffMinutes = checkIn.difference(scheduledTime).inMinutes;

      if (diffMinutes.abs() <= graceMinutes) {
        onTime++;
        onTimeIds.add(empId);
      } else if (diffMinutes > 0) {
        lateIn++;
        lateInIds.add(empId);
      } else {
        earlyIn++;
        earlyInIds.add(empId);
      }
    }

    return AttendanceStatus(
      onTime: onTime,
      lateIn: lateIn,
      earlyIn: earlyIn,
      onTimeIds: onTimeIds,
      lateInIds: lateInIds,
      earlyInIds: earlyInIds,
    );
  }

  /// Attempts to extract human-readable message from Odoo ValidationError
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

/// DTO / model class for today's attendance punctuality breakdown
class AttendanceStatus {
  final int onTime;
  final int lateIn;
  final int earlyIn;
  final List<int> onTimeIds;
  final List<int> lateInIds;
  final List<int> earlyInIds;

  AttendanceStatus({
    required this.onTime,
    required this.lateIn,
    required this.earlyIn,
    required this.onTimeIds,
    required this.lateInIds,
    required this.earlyInIds,
  });
}
