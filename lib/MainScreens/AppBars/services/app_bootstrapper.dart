import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../MainScreens/Attendance/AttendanceCreate/bloc/create_attendance_bloc.dart';
import '../../../MainScreens/Attendance/AttendanceForm/bloc/attendance_form_bloc.dart';
import '../../../MainScreens/Attendance/AttendanceList/bloc/attendance_list_bloc.dart';
import '../../../MainScreens/Calendar/bloc/calendar_bloc.dart';
import '../../../MainScreens/Calendar/bloc/calendar_event.dart';
import '../../../MainScreens/Dashboard/AttendanceDashboard/bloc/attendance_dashboard_bloc.dart';
import '../../../MainScreens/Dashboard/LeaveHistory/bloc/leave_history_bloc.dart';
import '../../../MainScreens/Dashboard/PendingLeaves/bloc/pending_leave_bloc.dart';
import '../../../MainScreens/Dashboard/Report/bloc/report_bloc.dart';
import '../../../MainScreens/Dashboard/Report/bloc/report_event.dart';
import '../../../MainScreens/Dashboard/RequestAbsence/bloc/request_absence_bloc.dart';
import '../../../MainScreens/Dashboard/RequestAbsence/bloc/request_absence_event.dart';
import '../../../MainScreens/Employees/EmployeeCreate/bloc/employee_create_bloc.dart';
import '../../../MainScreens/Employees/EmployeeCreate/bloc/employee_create_event.dart';
import '../../../MainScreens/Employees/EmployeeForm/Form/bloc/employee_form_bloc.dart';
import '../../../MainScreens/Employees/EmployeeForm/SmartTabs/PrivateInfo/bloc/private_info_bloc.dart';
import '../../../MainScreens/Employees/EmployeeForm/SmartTabs/PrivateInfo/bloc/private_info_event.dart';
import '../../../MainScreens/Employees/EmployeeForm/SmartTabs/WorkInfo/bloc/work_info_bloc.dart';
import '../../../MainScreens/Employees/EmployeeList/bloc/employee_list_bloc.dart';
import 'package:intl/intl.dart';

/// Utility class to reload all BLoCs in the app to refresh data.
///
/// Typically used after switching company, logging in, or when global state needs resetting.
class AppBootstrapper {

  /// Dispatches initialization events for all app BLoCs.
  ///
  /// This forces all parts of the app to reload their data, including:
  /// - Dashboard and reports
  /// - Attendance lists and forms
  /// - Employee lists, forms, and private/work info
  /// - Calendar data
  ///
  /// Should be called with a valid [BuildContext] where all BLoCs are available.
  static void reloadAppBlocs(BuildContext context) {
    context.read<AttendanceDashboardBloc>().add(LoadDashboardData());
    context.read<ReportBloc>().add(InitializeReport());
    context.read<LeaveHistoryBloc>().add(InitializeLeaveHistory());
    context.read<PendingLeaveBloc>().add(InitializePendingLeave());
    context.read<RequestAbsenceBloc>().add(InitializeRequestAbsence());
    context.read<EmployeeListBloc>().add(InitializeEmployeeList());
    context.read<AttendanceListBloc>().add(const LoadAttendance(page: 0));
    context.read<CalendarBloc>().add(LoadCalendarData(
      month: DateFormat.MMMM().format(DateTime.now()),
      year: DateTime.now().year,
    ));
    context.read<EmployeeCreateBloc>().add(InitializeCreateEmployee());
    context.read<EmployeeFormBloc>().add(LoadEmployeeDetails());
    context.read<AttendanceFormBloc>().add(InitializeAttendanceDetails());
    context.read<PrivateInfoBloc>().add(LoadPrivateInfoDetails());
    context.read<WorkInfoBloc>().add(LoadWorkInfoDetails());
    context.read<CreateAttendanceBloc>().add(InitializeCreateAttendanceDetails());
  }
}