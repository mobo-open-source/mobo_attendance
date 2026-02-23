import 'dart:async';
import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../CommonWidgets/core/company/infrastructure/company_refresh_bus.dart';
import '../../../LoginPages/credetials/services/app_install_check.dart';
import '../services/calendar_service.dart';
import 'calendar_event.dart';
import 'calendar_state.dart';

/// BLoC responsible for managing the calendar view state (monthly attendance + work schedule).
///
/// Main responsibilities:
///   - Load attendance records and work schedule for a given month/year
///   - React to company/session refresh events via CompanyRefreshBus
///   - Handle different error cases:
///     - Network failure (SocketException)
///     - Leave/attendance module not installed in Odoo
///     - Generic failures
///
/// States emitted:
///   - CalendarInitial       → initial / idle
///   - CalendarLoading       → fetching data
///   - CalendarLoaded        → success or handled error with flags
class CalendarBloc extends Bloc<CalendarEvent, CalendarState> {
  /// Service that handles all Odoo RPC calls for calendar data
  final CalendarService _calendarService = CalendarService();

  /// Subscription to company refresh events (e.g. session change, company switch)
  late final StreamSubscription companySub;

  /// Currently displayed/viewed month (as string "1"–"12")
  String _currentMonth = DateTime.now().month.toString();

  /// Currently displayed/viewed year
  int _currentYear = DateTime.now().year;

  CalendarBloc() : super(CalendarInitial()) {
    on<LoadCalendarData>(_onLoadCalendarData);

    // Listen to global company refresh events and reload current month
    companySub = CompanyRefreshBus.stream.listen((_) {
      add(LoadCalendarData(month: _currentMonth, year: _currentYear));
    });
  }

  /// Handler for LoadCalendarData event.
  ///
  /// Flow:
  ///   1. Emit loading state
  ///   2. Initialize Odoo client (session check)
  ///   3. Fetch attendance + work schedule via CalendarService
  ///   4. Emit success state with data
  ///
  /// Error handling:
  ///   - SocketException          → connection error flag
  ///   - AppInstallCheck failure  → module not installed flag
  ///   - Other errors             → generic catchError flag
  Future<void> _onLoadCalendarData(
    LoadCalendarData event,
    Emitter<CalendarState> emit,
  ) async {
    emit(CalendarLoading());

    try {
      await _calendarService.initializeClient();

      // Fetch data and emit loaded state via callback
      await _calendarService.fetchAttendanceData(
        selectedMonth: event.month,
        selectedYear: event.year,
        onDataLoaded: (data) {
          emit(
            CalendarLoaded(
              attendanceData: data['attendance'] as List<Map<String, dynamic>>,
              workSchedule:
                  data['work_schedule'] as Map<int, Map<String, String>>,
              isAppNotInstalled: false,
              catchError: false,
            ),
          );
        },
      );
    } on SocketException catch (_) {
      // No internet / server unreachable
      emit(
        CalendarLoaded(
          attendanceData: const [],
          workSchedule: const {},
          catchError: false,
          connectionError: true,
          isAppNotInstalled: false,
        ),
      );
    } catch (e) {
      // Check if the attendance/leave module is installed in Odoo
      bool success = await AppInstallCheck().checkLeaveModule();
      if (!success) {
        emit(
          CalendarLoaded(
            attendanceData: const [],
            workSchedule: const {},
            catchError: false,
            connectionError: false,
            isAppNotInstalled: true,
          ),
        );
      } else {
        // Generic error (e.g. RPC exception, parsing issue, etc.)
        emit(
          CalendarLoaded(
            attendanceData: const [],
            workSchedule: const {},
            catchError: true,
            connectionError: false,
            isAppNotInstalled: false,
          ),
        );
      }
    }
  }
}
