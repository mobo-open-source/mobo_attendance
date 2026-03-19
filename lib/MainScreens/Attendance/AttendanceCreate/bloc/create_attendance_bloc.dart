import 'package:bloc/bloc.dart';

import '../services/attendance_create_service.dart';

part 'create_attendance_event.dart';

part 'create_attendance_state.dart';

/// Bloc responsible for managing attendance creation operations.
///
/// Handles initializing employees, selecting employees, updating
/// check-in/check-out times, calculating worked hours, saving attendance,
/// and clearing selected employees.
class CreateAttendanceBloc
    extends Bloc<CreateAttendanceEvent, CreateAttendanceState> {
  final AttendanceCreateService _service;

  /// Creates a [CreateAttendanceBloc] with the given [AttendanceCreateService].
  ///
  /// Initializes event handlers for attendance operations.
  CreateAttendanceBloc(this._service) : super(CreateAttendanceInitial()) {
    on<InitializeCreateAttendance>(_onInitialize);
    on<InitializeCreateAttendanceDetails>(_onInitializeDetails);
    on<SelectEmployee>(_onSelectEmployee);
    on<UpdateCheckIn>(_onUpdateCheckIn);
    on<UpdateCheckOut>(_onUpdateCheckOut);
    on<SaveAttendance>(_onSaveAttendance);
    on<ClearSelectedEmployee>(_onClearSelectedEmployee);
  }

  /// Returns the current date and time in `YYYY-MM-DD HH:MM` format.
  String _getCurrentDateTime() {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} "
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
  }

  /// Calculates worked hours between [checkIn] and [checkOut] times.
  ///
  /// Returns "00:00" if either time is empty or invalid.
  String _calculateWorkedHours(String checkIn, String checkOut) {
    if (checkIn.isEmpty || checkOut.isEmpty) return "00:00";
    try {
      final inTime = DateTime.parse("$checkIn:00");
      final outTime = DateTime.parse("$checkOut:00");
      final diff = outTime.difference(inTime);
      if (diff.inMinutes <= 0) return "00:00";
      final hours = diff.inHours;
      final minutes = diff.inMinutes % 60;
      return "${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}";
    } catch (e) {
      return "00:00";
    }
  }

  /// Handles the [InitializeCreateAttendance] event.
  ///
  /// Preserves previously loaded employees if available,
  /// initializes the client, and sets initial check-in time.
  Future<void> _onInitialize(
    InitializeCreateAttendance event,
    Emitter<CreateAttendanceState> emit,
  ) async {
    List<Map<String, dynamic>> preservedEmployees = [];

    if (state is CreateAttendanceLoaded) {
      preservedEmployees = (state as CreateAttendanceLoaded).employees;
    } else if (state is CreateAttendanceSuccess) {
      preservedEmployees = (state as CreateAttendanceSuccess).employees;
    }

    emit(CreateAttendanceLoading(employees: preservedEmployees));
    try {
      await _service.initializeClient();
      final checkIn = _getCurrentDateTime();

      emit(
        CreateAttendanceLoaded(
          employees: preservedEmployees,
          checkIn: checkIn,
          checkOut: "",
          workedHours: "00:00",
        ),
      );
    } catch (e) {
      emit(CreateAttendanceError("Failed to load employees: ${e.toString()}"));
    }
  }

  /// Handles the [InitializeCreateAttendanceDetails] event.
  ///
  /// Fetches the list of employees and emits a loaded state.
  Future<void> _onInitializeDetails(
    InitializeCreateAttendanceDetails event,
    Emitter<CreateAttendanceState> emit,
  ) async {
    try {
      await _service.initializeClient();
      final employees = await _service.fetchEmployees();

      emit(
        CreateAttendanceLoaded(
          employees: employees,
          checkIn: "",
          checkOut: "",
          workedHours: "00:00",
        ),
      );
    } catch (e) {
      emit(CreateAttendanceError("Failed to load employees: ${e.toString()}"));
    }
  }

  /// Handles the [SelectEmployee] event.
  ///
  /// Fetches employee details and updates the state with selected employee info.
  Future<void> _onSelectEmployee(
    SelectEmployee event,
    Emitter<CreateAttendanceState> emit,
  ) async {
    final currentState = state as CreateAttendanceLoaded;
    try {
      final details = await _service.fetchEmployeeDetails(event.employee['id']);
      final emp = details.isNotEmpty ? details.first : {};

      final job = (emp['job_id'] is List && emp['job_id'].length > 1)
          ? emp['job_id'][1].toString()
          : 'N/A';

      final email =
          (emp['work_email'] is String &&
              emp['work_email'].toString().trim().isNotEmpty)
          ? emp['work_email']
          : 'N/A';

      String? image;
      final rawImage = emp['image_1920'];

      if (rawImage is String && rawImage.trim().isNotEmpty) {
        image = rawImage;
      } else if (rawImage == false) {
        image = null;
      } else if (rawImage == null) {
        image = null;
      }

      emit(
        currentState.copyWith(
          isEmployeeSelect: true,
          selectedEmployeeId: event.employee['id'],
          selectedEmployeeName: event.employee['name'],
          employeeJob: job,
          employeeEmail: email,
          employeeImage: image,
          clearEmployeeImage: image == null,
        ),
      );
    } catch (e) {
      emit(CreateAttendanceError("Failed to load employee details"));
    }
  }

  /// Handles the [UpdateCheckIn] event.
  ///
  /// Updates the check-in time and recalculates worked hours.
  void _onUpdateCheckIn(
    UpdateCheckIn event,
    Emitter<CreateAttendanceState> emit,
  ) {
    final current = state as CreateAttendanceLoaded;
    final newWorkedHours = _calculateWorkedHours(
      event.checkIn,
      current.checkOut,
    );
    emit(current.copyWith(checkIn: event.checkIn, workedHours: newWorkedHours));
  }

  /// Handles the [UpdateCheckOut] event.
  ///
  /// Updates the check-out time and recalculates worked hours.
  void _onUpdateCheckOut(
    UpdateCheckOut event,
    Emitter<CreateAttendanceState> emit,
  ) {
    final current = state as CreateAttendanceLoaded;
    final newWorkedHours = _calculateWorkedHours(
      current.checkIn,
      event.checkOut,
    );
    emit(
      current.copyWith(checkOut: event.checkOut, workedHours: newWorkedHours),
    );
  }

  /// Handles the [SaveAttendance] event.
  ///
  /// Validates selected employee, prevents duplicate check-ins, and saves attendance.
  Future<void> _onSaveAttendance(
    SaveAttendance event,
    Emitter<CreateAttendanceState> emit,
  ) async {
    final current = state as CreateAttendanceLoaded;
    if (current.selectedEmployeeId == null) {
      emit(CreateAttendanceError("Please select an employee"));
      emit(current);
      return;
    }

    emit(CreateAttendanceSaving(previous: current));

    final alreadyCheckedIn = await _service.isEmployeeAlreadyCheckedIn(
      current.selectedEmployeeId!,
    );

    if (alreadyCheckedIn) {
      emit(
        current.copyWith(
          errorMessage:
              "Cannot create new attendance for ${current.selectedEmployeeName}. Employee hasn't checked out yet.",
        ),
      );

      return;
    }

    String normalizeDate(String date) => date.length == 16 ? "$date:00" : date;

    final data = {
      'employee_id': current.selectedEmployeeId,
      'check_in': current.checkIn.isNotEmpty
          ? normalizeDate(current.checkIn)
          : null,
      'check_out': current.checkOut.isNotEmpty
          ? normalizeDate(current.checkOut)
          : null,
    };

    final result = await _service.createAttendanceDetails(data);

    if (result['success'] == true) {
      emit(
        CreateAttendanceSuccess(
          attendanceId: result['attendance_id'],
          message: "Attendance created successfully",
          checkIn: current.checkIn,
          checkOut: current.checkOut,
          workedHours: current.workedHours,
          employees: current.employees,
        ),
      );
    } else {
      emit(current.copyWith(errorMessage: result['error']));
    }
  }

  /// Handles the [ClearSelectedEmployee] event.
  ///
  /// Clears the selected employee from the current state.
  void _onClearSelectedEmployee(
    ClearSelectedEmployee event,
    Emitter<CreateAttendanceState> emit,
  ) {
    final current = state as CreateAttendanceLoaded;

    emit(current.copyWith(isEmployeeSelect: false));
  }
}
