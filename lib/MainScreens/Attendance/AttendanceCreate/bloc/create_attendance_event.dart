part of 'create_attendance_bloc.dart';

/// Base class for all attendance-related events.
abstract class CreateAttendanceEvent {}

/// Event to initialize attendance creation.
/// Typically loads initial state and preserves previously loaded employees.
class InitializeCreateAttendance extends CreateAttendanceEvent {}

/// Event to fetch detailed employee information for attendance creation.
class InitializeCreateAttendanceDetails extends CreateAttendanceEvent {}

/// Event to select a specific employee for attendance.
///
/// [employee] contains employee details such as `id` and `name`.
class SelectEmployee extends CreateAttendanceEvent {
  final Map<String, dynamic> employee;

  SelectEmployee(this.employee);
}

/// Event to update the check-in time for the selected employee.
///
/// [checkIn] should be in `HH:MM` format.
class UpdateCheckIn extends CreateAttendanceEvent {
  final String checkIn;

  UpdateCheckIn(this.checkIn);
}

/// Event to update the check-out time for the selected employee.
///
/// [checkOut] should be in `HH:MM` format.
class UpdateCheckOut extends CreateAttendanceEvent {
  final String checkOut;

  UpdateCheckOut(this.checkOut);
}

/// Event to save the current attendance entry.
class SaveAttendance extends CreateAttendanceEvent {}

/// Event to clear the currently selected employee from the state.
class ClearSelectedEmployee extends CreateAttendanceEvent {}
