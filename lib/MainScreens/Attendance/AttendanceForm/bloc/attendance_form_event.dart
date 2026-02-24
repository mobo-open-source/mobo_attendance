part of 'attendance_form_bloc.dart';

/// Base class for all events handled by [AttendanceFormBloc].
/// Extends [Equatable] to support value-based comparisons.
abstract class AttendanceFormEvent extends Equatable {
  const AttendanceFormEvent();

  @override
  List<Object?> get props => [];
}

/// Event to initialize the attendance form with a specific record.
///
/// Fetches the attendance data for the provided [attendanceId] and
/// optionally sets the [workingHours] for display.
class InitializeAttendance extends AttendanceFormEvent {
  final int attendanceId;
  final String workingHours;

  const InitializeAttendance({
    required this.attendanceId,
    required this.workingHours,
  });

  @override
  List<Object?> get props => [attendanceId, workingHours];
}

/// Event to fetch all required employee details and user access rights.
///
/// Typically used to populate employee dropdowns and determine if
/// the current user can edit attendance records.
class InitializeAttendanceDetails extends AttendanceFormEvent {
  InitializeAttendanceDetails();
}

/// Event to enable editing mode for the attendance form.
///
/// When handled, [AttendanceFormBloc] sets the form to an editable state.
class ToggleEditMode extends AttendanceFormEvent {}

/// Event to cancel editing mode for the attendance form.
///
/// Reverts any unsaved changes and sets the form back to view-only state.
class CancelEdit extends AttendanceFormEvent {}

/// Event to save updates to an attendance record.
///
/// Requires the [employeeId] being updated, the [checkIn] and [checkOut]
/// times (as strings), and the [employeeName] for tracking or display purposes.
class SaveAttendance extends AttendanceFormEvent {
  final int employeeId;
  final String checkIn;
  final String checkOut;
  final String employeeName;

  const SaveAttendance({
    required this.employeeId,
    required this.checkIn,
    required this.checkOut,
    required this.employeeName,
  });

  @override
  List<Object?> get props => [employeeId, employeeName, checkIn, checkOut];
}
