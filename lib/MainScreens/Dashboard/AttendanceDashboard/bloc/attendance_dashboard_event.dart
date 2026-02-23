part of 'attendance_dashboard_bloc.dart';

/// Abstract base class for all events dispatched to [AttendanceDashboardBloc].
///
/// Inherits from [Equatable] to provide value-based equality,
/// which helps Bloc avoid unnecessary state emissions when events are identical.
abstract class AttendanceDashboardEvent extends Equatable {
  const AttendanceDashboardEvent();

  @override
  List<Object?> get props => [];
}

/// Event emitted when the dashboard should load or reload all data.
///
/// This is typically the first event added when the screen is opened,
/// or when the user pulls to refresh, switches organization, or after
/// a successful check-in/check-out action.
class LoadDashboardData extends AttendanceDashboardEvent {}

/// Event indicating the user wants to perform a check-in action.
class CheckInRequested extends AttendanceDashboardEvent {}

/// Event indicating the user wants to perform a check-out action.
class CheckOutRequested extends AttendanceDashboardEvent {}

/// Lightweight event to trigger a full dashboard refresh without additional context.
///
/// Often added automatically after successful check-in or check-out operations.
class RefreshDashboard extends AttendanceDashboardEvent {}
