part of 'create_attendance_bloc.dart';

/// Base class for all attendance-related states.
abstract class CreateAttendanceState {}

/// Initial state of attendance creation.
class CreateAttendanceInitial extends CreateAttendanceState {}

/// State emitted when attendance data is loading.
///
/// [employees] holds the list of employees loaded so far (can be empty).
class CreateAttendanceLoading extends CreateAttendanceState {
  final List<Map<String, dynamic>> employees;
  CreateAttendanceLoading({this.employees = const []});
}

/// State representing loaded attendance data and selections.
///
/// Contains employee list, selected employee info, check-in/out times,
/// worked hours, selection status, and optional error messages.
class CreateAttendanceLoaded extends CreateAttendanceState {
  final List<Map<String, dynamic>> employees;
  final int? selectedEmployeeId;
  final String? selectedEmployeeName;
  final String? employeeJob;
  final String? employeeEmail;
  final String? employeeImage;
  final String checkIn;
  final String checkOut;
  final String workedHours;
  final bool isEmployeeSelect;
  final String? errorMessage;

  CreateAttendanceLoaded({
    required this.employees,
    this.selectedEmployeeId,
    this.selectedEmployeeName,
    this.employeeJob,
    this.employeeEmail,
    this.employeeImage,
    required this.checkIn,
    required this.checkOut,
    required this.workedHours,
    this.isEmployeeSelect = false,
    this.errorMessage,

  });

  /// Creates a copy of this state with updated values.
  ///
  /// Use [clearEmployeeImage] to explicitly set [employeeImage] to null.
  CreateAttendanceLoaded copyWith({
    List<Map<String, dynamic>>? employees,
    int? selectedEmployeeId,
    String? selectedEmployeeName,
    String? employeeJob,
    String? employeeEmail,
    String? employeeImage,
    bool clearEmployeeImage = false,
    String? checkIn,
    String? checkOut,
    String? workedHours,
    bool? isEmployeeSelect,
    String? errorMessage,

  }) {
    return CreateAttendanceLoaded(
      employees: employees ?? this.employees,
      selectedEmployeeId: selectedEmployeeId ?? this.selectedEmployeeId,
      selectedEmployeeName: selectedEmployeeName ?? this.selectedEmployeeName,
      employeeJob: employeeJob ?? this.employeeJob,
      employeeEmail: employeeEmail ?? this.employeeEmail,
      employeeImage: clearEmployeeImage
          ? null
          : employeeImage ?? this.employeeImage,
      checkIn: checkIn ?? this.checkIn,
      checkOut: checkOut ?? this.checkOut,
      workedHours: workedHours ?? this.workedHours,
      isEmployeeSelect: isEmployeeSelect ?? this.isEmployeeSelect,
      errorMessage: errorMessage,

    );
  }
}

/// State emitted when attendance is being saved.
///
/// [previous] holds the last loaded state before saving.
class CreateAttendanceSaving extends CreateAttendanceState {
  final CreateAttendanceLoaded previous;

  CreateAttendanceSaving({required this.previous});
}

/// State emitted when attendance is successfully saved.
///
/// Includes the new [attendanceId], success [message], check-in/out times,
/// worked hours, and the employee list.
class CreateAttendanceSuccess extends CreateAttendanceState {
  final int attendanceId;
  final String message;
  final String checkIn;
  final String checkOut;
  final String workedHours;
  final List<Map<String, dynamic>> employees;

  CreateAttendanceSuccess({
    required this.attendanceId,
    required this.message,
    required this.checkIn,
    required this.checkOut,
    this.workedHours = "00:00",
    required this.employees,
  });
}

/// State emitted when an error occurs during attendance operations.
///
/// [message] describes the error.
class CreateAttendanceError extends CreateAttendanceState {
  final String message;

  CreateAttendanceError(this.message);
}
