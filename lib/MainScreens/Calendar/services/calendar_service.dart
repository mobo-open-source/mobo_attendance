import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

import '../../../CommonWidgets/core/company/session/company_session_manager.dart';

/// Service class responsible for fetching and processing calendar-related data
/// such as attendance records, leaves, public holidays, mandatory off days,
/// and work schedule for the currently logged-in employee.
///
/// This class communicates with Odoo backend via `CompanySessionManager`
/// and prepares data in a format suitable for the calendar UI.
class CalendarService {
  int? userId;

  static const List<String> months = [
    "January",
    "February",
    "March",
    "April",
    "May",
    "June",
    "July",
    "August",
    "September",
    "October",
    "November",
    "December",
  ];

  /// Initializes the service by checking for an active company session.
  /// Throws exception if no valid session is found.
  Future<void> initializeClient() async {
    final session = await CompanySessionManager.getCurrentSession();
    if (session == null) throw Exception("No active session");
  }

  /// Updates or creates daily attendance summary and calculates worked hours.
  ///
  /// - Keeps the earliest check-in (`first_in`)
  /// - Keeps the latest check-out (`last_out`)
  /// - Computes total worked hours (in decimal format)
  /// - Stores formatted check-in/out strings in the final daily data map
  void _addDailyAttendance(
      String dateStr,
      DateTime firstIn,
      DateTime? lastOut,
      Map<String, Map<String, dynamic>> dailyAttendance,
      Map<String, Map<String, dynamic>> dailyData,
      ) {
    if (!dailyAttendance.containsKey(dateStr)) {
      dailyAttendance[dateStr] = {
        'first_in': firstIn,
        'last_out': lastOut,
      };
    } else {
      final entry = dailyAttendance[dateStr]!;

      if (firstIn.isBefore(entry['first_in'] as DateTime)) {
        entry['first_in'] = firstIn;
      }
      if (lastOut != null &&
          (entry['last_out'] == null ||
              lastOut.isAfter(entry['last_out'] as DateTime))) {
        entry['last_out'] = lastOut;
      }
    }

    final entry = dailyAttendance[dateStr]!;
    final double workedHours = entry['last_out'] != null
        ? (entry['last_out'] as DateTime)
        .difference(entry['first_in'] as DateTime)
        .inMinutes /
        60
        : 0.0;

    dailyData[dateStr]!['type'] = 'attendance';
    dailyData[dateStr]!['data'] = {
      'check_in': DateFormat('yyyy-MM-dd hh:mm a').format(entry['first_in'] as DateTime),
      'check_out': entry['last_out'] != null
          ? DateFormat('yyyy-MM-dd hh:mm a').format(entry['last_out'] as DateTime)
          : null,
      'worked_hours': workedHours,
    };
  }

  /// Main method to fetch and aggregate all calendar data for a given month/year.
  ///
  /// Fetches:
  ///   - Employee record & linked resource calendar
  ///   - Work schedule (resource.calendar.attendance)
  ///   - Attendance records (hr.attendance)
  ///   - Approved leaves (hr.leave)
  ///   - Public holidays (resource.calendar.leaves without holiday_id)
  ///   - Mandatory off days (hr.leave.mandatory.day)
  ///
  /// Processes overlapping/multi-day records and prioritizes data types:
  ///   holiday → mandatory → leave → attendance → normal/weekend/future
  ///
  /// [selectedMonth] English month name (must be in [months] list)
  /// [selectedYear] four-digit year
  /// [onDataLoaded] callback receiving map with:
  ///   - 'attendance': List<Map> of daily data (sorted descending by date)
  ///   - 'work_schedule': Map<int, Map<String,String>> (0=Sunday → 6=Saturday)
  Future<void> fetchAttendanceData({
    required String selectedMonth,
    required int selectedYear,
    required Function(Map<String, dynamic>) onDataLoaded,
  }) async {
    final Map<String, Map<String, dynamic>> dailyAttendance = {};
    final Map<int, Map<String, String>> workSchedule = {};
    final Map<String, Map<String, dynamic>> dailyData = {};

    // ────────────────────────────────────────────────────────────────
    // 1. Get current user & linked employee
    // ────────────────────────────────────────────────────────────────
    final prefs = await SharedPreferences.getInstance();
    userId = prefs.getInt('userId') ?? 0;

    if (userId == null || userId == 0) {
      throw Exception("User not logged in");
    }

    // ────────────────────────────────────────────────────────────────
    // 2. Get employee's resource calendar
    // ────────────────────────────────────────────────────────────────

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
      throw Exception("No employee linked to this user");
    }

    final int employeeId = employeeResult[0]['id'];

    final employeesResult = await CompanySessionManager.callKwWithCompany({
      'model': 'hr.employee',
      'method': 'search_read',
      'args': [
        [
          ['id', '=', employeeId],
        ],
      ],
      'kwargs': {
        'fields': ['resource_calendar_id'],
      },
    }) as List;

    if (employeesResult.isEmpty || employeesResult[0]['resource_calendar_id'] == false) {
      throw Exception("Employee has no work schedule assigned");
    }

    final int calendarId = (employeesResult[0]['resource_calendar_id'] as List).first;

    // ────────────────────────────────────────────────────────────────
    // 3. Load work schedule (possibly multiple shifts per weekday)
    //    → keep earliest start & latest end per weekday
    // ────────────────────────────────────────────────────────────────

    final resourceAttendances = await CompanySessionManager.callKwWithCompany({
      'model': 'resource.calendar.attendance',
      'method': 'search_read',
      'args': [
        [
          ['calendar_id', '=', calendarId],
        ],
      ],
      'kwargs': {
        'fields': ['dayofweek', 'hour_from', 'hour_to'],
      },
    }) as List;

    for (var att in resourceAttendances) {
      final int dayOfWeek = int.parse(att['dayofweek'].toString());
      final double hourFrom = (att['hour_from'] as num).toDouble();
      final double hourTo = (att['hour_to'] as num).toDouble();

      if (!workSchedule.containsKey(dayOfWeek)) {
        workSchedule[dayOfWeek] = {
          'work_from': hourFrom.toString(),
          'work_to': hourTo.toString(),
        };
      } else {
        final double currentFrom = double.parse(workSchedule[dayOfWeek]!['work_from']!);
        final double currentTo = double.parse(workSchedule[dayOfWeek]!['work_to']!);

        workSchedule[dayOfWeek]!['work_from'] =
            (hourFrom < currentFrom ? hourFrom : currentFrom).toString();
        workSchedule[dayOfWeek]!['work_to'] =
            (hourTo > currentTo ? hourTo : currentTo).toString();
      }
    }

    // ────────────────────────────────────────────────────────────────
    // 4. Prepare date range & initialize every day as 'normal'
    // ────────────────────────────────────────────────────────────────
    final int monthIndex = months.indexOf(selectedMonth) + 1;
    if (monthIndex == 0) throw Exception("Invalid month: $selectedMonth");

    final DateTime firstDay = DateTime(selectedYear, monthIndex, 1);
    final DateTime lastDay = DateTime(selectedYear, monthIndex + 1, 0);

    final String firstDayStr = DateFormat('yyyy-MM-dd').format(firstDay);
    final String lastDayStr = DateFormat('yyyy-MM-dd').format(lastDay);

    try {
      // ────────────────────────────────────────────────────────────────
      // 5. Fetch all relevant records
      // ────────────────────────────────────────────────────────────────
      final attendances = await CompanySessionManager.callKwWithCompany({
        'model': 'hr.attendance',
        'method': 'search_read',
        'args': [
          [
            ['employee_id', '=', employeeId],
            ['check_in', '>=', '$firstDayStr 00:00:00'],
            ['check_in', '<=', '$lastDayStr 23:59:59'],
          ],
        ],
        'kwargs': {
          'fields': ['check_in', 'check_out', 'worked_hours'],
        },
      }) as List;

      final leaves = await CompanySessionManager.callKwWithCompany({
        'model': 'hr.leave',
        'method': 'search_read',
        'args': [
          [
            ['employee_id', '=', employeeId],
            ['state', '=', 'validate'],
            ['date_from', '<=', '$lastDayStr 23:59:59'],
            ['date_to', '>=', '$firstDayStr 00:00:00'],
          ],
        ],
        'kwargs': {
          'fields': ['name', 'date_from', 'date_to'],
        },
      }) as List;

      final publicHolidays = await CompanySessionManager.callKwWithCompany({
        'model': 'resource.calendar.leaves',
        'method': 'search_read',
        'args': [
          [
            ['holiday_id', '=', false],
            ['date_from', '<=', '$lastDayStr 23:59:59'],
            ['date_to', '>=', '$firstDayStr 00:00:00'],
          ],
        ],
        'kwargs': {
          'fields': ['name', 'date_from', 'date_to', 'holiday_id'],
        },
      }) as List;

      final mandatoryDays = await CompanySessionManager.callKwWithCompany({
        'model': 'hr.leave.mandatory.day',
        'method': 'search_read',
        'args': [
          [
            ['start_date', '<=', '$lastDayStr 23:59:59'],
            ['end_date', '>=', '$firstDayStr 00:00:00'],
          ],
        ],
        'kwargs': {
          'fields': ['name', 'start_date', 'end_date'],
        },
      }) as List;

      for (var day = firstDay;
      day.isBefore(lastDay.add(const Duration(days: 1)));
      day = day.add(const Duration(days: 1))) {
        final String dateStr = DateFormat('yyyy-MM-dd').format(day);
        final String dayName = DateFormat('EEE').format(day).toUpperCase();
        final String dateNum = day.day.toString();

        dailyData[dateStr] = {
          'date': dateNum,
          'day': dayName,
          'type': 'normal',
          'data': null,
        };
      }

      // ────────────────────────────────────────────────────────────────
      // 6. Process attendances (handle overnight shifts)
      // ────────────────────────────────────────────────────────────────
      for (var att in attendances) {
        final checkInRaw = att['check_in'];
        if (checkInRaw == null || checkInRaw == false) continue;

        final DateTime checkIn = DateTime.parse("${checkInRaw as String}Z").toLocal();

        final checkOutRaw = att['check_out'];
        DateTime? checkOut = (checkOutRaw != null && checkOutRaw != false)
            ? DateTime.parse("${checkOutRaw as String}Z").toLocal()
            : null;

        final DateTime midnight = DateTime(checkIn.year, checkIn.month, checkIn.day, 24, 0);

        if (checkOut != null && checkOut.isAfter(midnight)) {
          // Split overnight attendance into two days
          _addDailyAttendance(
            DateFormat('yyyy-MM-dd').format(checkIn),
            checkIn,
            midnight,
            dailyAttendance,
            dailyData,
          );
          _addDailyAttendance(
            DateFormat('yyyy-MM-dd').format(midnight),
            midnight,
            checkOut,
            dailyAttendance,
            dailyData,
          );
        } else {
          _addDailyAttendance(
            DateFormat('yyyy-MM-dd').format(checkIn),
            checkIn,
            checkOut,
            dailyAttendance,
            dailyData,
          );
        }
      }

      // ────────────────────────────────────────────────────────────────
      // 7. Apply public holidays (highest priority)
      // ────────────────────────────────────────────────────────────────
      for (var h in publicHolidays) {
        final fromRaw = h['date_from'];
        final toRaw = h['date_to'];
        final name = h['name'] as String? ?? 'Public Holiday';
        if (fromRaw == null || toRaw == null) continue;

        final from = DateTime.parse((fromRaw as String).substring(0, 10));
        final to = DateTime.parse((toRaw as String).substring(0, 10));

        for (var d = from;
        d.isBefore(to.add(const Duration(days: 1)));
        d = d.add(const Duration(days: 1))) {
          final dateStr = DateFormat('yyyy-MM-dd').format(d);
          if (dailyData.containsKey(dateStr)) {
            dailyData[dateStr]!['type'] = 'holiday';
            dailyData[dateStr]!['data'] = name;
          }
        }
      }

      // ────────────────────────────────────────────────────────────────
      // 8. Apply mandatory days
      // ────────────────────────────────────────────────────────────────
      for (var m in mandatoryDays) {
        final fromRaw = m['start_date'];
        final toRaw = m['end_date'];
        final name = m['name'] as String? ?? 'Mandatory Day';
        if (fromRaw == null || toRaw == null) continue;

        final from = DateTime.parse((fromRaw as String).substring(0, 10));
        final to = DateTime.parse((toRaw as String).substring(0, 10));

        for (var d = from;
        d.isBefore(to.add(const Duration(days: 1)));
        d = d.add(const Duration(days: 1))) {
          final dateStr = DateFormat('yyyy-MM-dd').format(d);
          if (dailyData.containsKey(dateStr)) {
            dailyData[dateStr]!['type'] = 'mandatory';
            dailyData[dateStr]!['data'] = name;
          }
        }
      }

      // ────────────────────────────────────────────────────────────────
      // 9. Apply approved leaves
      // ────────────────────────────────────────────────────────────────
      for (var leave in leaves) {
        final fromRaw = leave['date_from'];
        final toRaw = leave['date_to'];
        final dynamic rawName = leave['name'];
        final String name = (rawName is String && rawName.isNotEmpty) ? rawName : 'On Leave';
        if (fromRaw == null || toRaw == null) continue;

        final from = DateTime.parse(fromRaw as String);
        final to = DateTime.parse(toRaw as String);

        for (var d = from;
        d.isBefore(to.add(const Duration(days: 1)));
        d = d.add(const Duration(days: 1))) {
          final dateStr = DateFormat('yyyy-MM-dd').format(d);
          if (dailyData.containsKey(dateStr)) {
            dailyData[dateStr]!['type'] = 'leave';
            dailyData[dateStr]!['data'] = name;
          }
        }
      }

      // ────────────────────────────────────────────────────────────────
      // 10. Prepare final sorted output (newest first)
      // ────────────────────────────────────────────────────────────────
      final sortedKeys = dailyData.keys.toList()..sort((a, b) => b.compareTo(a));
      final List<Map<String, dynamic>> attendanceData =
      sortedKeys.map((key) => dailyData[key]!).toList();

      onDataLoaded({
        'attendance': attendanceData,
        'work_schedule': workSchedule,
      });
    } catch (e) {
      rethrow;
    }
  }
}