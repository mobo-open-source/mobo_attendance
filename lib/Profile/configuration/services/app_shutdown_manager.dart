import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../CommonWidgets/core/navigation/global_keys.dart';
import '../../../MainScreens/Attendance/AttendanceCreate/bloc/create_attendance_bloc.dart';
import '../../../MainScreens/Attendance/AttendanceForm/bloc/attendance_form_bloc.dart';
import '../../../MainScreens/Attendance/AttendanceList/bloc/attendance_list_bloc.dart';
import '../../../MainScreens/Calendar/bloc/calendar_bloc.dart';
import '../../../MainScreens/Dashboard/AttendanceDashboard/bloc/attendance_dashboard_bloc.dart';
import '../../../MainScreens/Dashboard/LeaveHistory/bloc/leave_history_bloc.dart';
import '../../../MainScreens/Dashboard/PendingLeaves/bloc/pending_leave_bloc.dart';
import '../../../MainScreens/Dashboard/Report/bloc/report_bloc.dart';
import '../../../MainScreens/Dashboard/RequestAbsence/bloc/request_absence_bloc.dart';
import '../../../MainScreens/Employees/EmployeeCreate/bloc/employee_create_bloc.dart';
import '../../../MainScreens/Employees/EmployeeForm/Form/bloc/employee_form_bloc.dart';
import '../../../MainScreens/Employees/EmployeeForm/SmartTabs/PrivateInfo/bloc/private_info_bloc.dart';
import '../../../MainScreens/Employees/EmployeeForm/SmartTabs/WorkInfo/bloc/work_info_bloc.dart';
import '../../../MainScreens/Employees/EmployeeList/bloc/employee_list_bloc.dart';

/// Utility class responsible for gracefully closing (disposing) all major BLoCs
/// when the application is being shut down or when a full reset is required.
///
/// Typical usage scenarios:
/// - User logs out
/// - App is being closed / force-quit detected
/// - Session expired / forced re-login
/// - Switching accounts (in multi-account setups)
///
/// This prevents memory leaks from lingering BLoC instances after navigation
/// stack is cleared or app lifecycle ends.
///
/// Important: Relies on `navigatorKey.currentContext` being available.
/// If called too early (before widgets are built), it will silently do nothing.
class AppShutdownManager {
  /// Closes all registered BLoCs by accessing them via the global navigator context.
  ///
  /// Safe to call multiple times — BLoC `close()` is idempotent.
  ///
  /// Warning: This method assumes that:
  /// 1. `navigatorKey` is properly initialized
  /// 2. All listed BLoCs are currently provided in the widget tree
  ///    (via `BlocProvider` or `RepositoryProvider`)
  ///
  /// If any BLoC is missing from the tree, `read<T>()` will throw.
  /// In production, consider wrapping in try-catch if robustness is needed.
  static void resetAllBlocs() {
    final ctx = navigatorKey.currentContext;

    // Early exit if context is not yet available (e.g. called before build)
    if (ctx == null) return;

    // ── Dashboard & Overview Blocs ───────────────────────────────────────────
    ctx.read<AttendanceDashboardBloc>().close();
    ctx.read<ReportBloc>().close();
    ctx.read<LeaveHistoryBloc>().close();
    ctx.read<PendingLeaveBloc>().close();
    ctx.read<RequestAbsenceBloc>().close();

    // ── Employee Management Blocs ────────────────────────────────────────────
    ctx.read<EmployeeListBloc>().close();
    ctx.read<EmployeeCreateBloc>().close();
    ctx.read<EmployeeFormBloc>().close();
    ctx.read<PrivateInfoBloc>().close();
    ctx.read<WorkInfoBloc>().close();

    // ── Attendance & Calendar Blocs ──────────────────────────────────────────
    ctx.read<AttendanceListBloc>().close();
    ctx.read<CreateAttendanceBloc>().close();
    ctx.read<AttendanceFormBloc>().close();
    ctx.read<CalendarBloc>().close();
  }
}
