import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../services/attendance_form_service.dart';

part 'attendance_form_event.dart';

part 'attendance_form_state.dart';

/// Bloc responsible for managing the attendance form workflow, including
/// fetching attendance records, handling employee details, editing, and saving
/// attendance data.
///
/// The `AttendanceFormBloc` communicates with [AttendanceFormService] to
/// perform API calls or local data operations, and emits states defined in
/// `attendance_form_state.dart` based on the result of each operation.
///
/// Events handled by this bloc:
/// - [InitializeAttendance]: Fetches a specific attendance record and formats its worked hours.
/// - [InitializeAttendanceDetails]: Fetches the list of employees and initializes client access details.
/// - [ToggleEditMode]: Enables editing mode for the attendance form.
/// - [CancelEdit]: Cancels editing mode and reverts form changes.
/// - [SaveAttendance]: Saves updates to an attendance record, handles success and error states.
///
/// Example usage:
/// ```dart
/// final bloc = AttendanceFormBloc();
/// bloc.add(InitializeAttendance(attendanceId: 123));
/// ```
class AttendanceFormBloc
    extends Bloc<AttendanceFormEvent, AttendanceFormState> {
  /// Service used to perform attendance-related operations.
  final AttendanceFormService _service;

  /// Creates an instance of [AttendanceFormBloc].
  ///
  /// Optionally accepts a custom [AttendanceFormService] for testing or
  /// overriding default behavior.
  AttendanceFormBloc({AttendanceFormService? service})
    : _service = service ?? AttendanceFormService(),
      super(AttendanceFormInitial()) {
    on<InitializeAttendance>(_onInitialize);
    on<InitializeAttendanceDetails>(_onInitializeDetails);
    on<ToggleEditMode>(_onToggleEdit);
    on<CancelEdit>(_onCancelEdit);
    on<SaveAttendance>(_onSaveAttendance);
  }

  /// Handles the [InitializeAttendance] event.
  ///
  /// Fetches the attendance record with the provided [event.attendanceId],
  /// checks user access, formats worked hours, and emits
  /// [AttendanceFormLoaded] state or [AttendanceFormError] on failure.
  Future<void> _onInitialize(
    InitializeAttendance event,
    Emitter<AttendanceFormState> emit,
  ) async {
    final preservedEmployees = state is AttendanceFormLoaded
        ? (state as AttendanceFormLoaded).employees
        : null;
    final preservedAccess = state is AttendanceFormLoaded
        ? (state as AttendanceFormLoaded).hasEditAccess
        : null;

    emit(
      AttendanceFormLoading(
        employees: preservedEmployees,
        hasEditAccess: preservedAccess,
      ),
    );
    try {
      final hasAccess = await _service.canManageSkills();
      final attendanceData = await _service.fetchAttendance(event.attendanceId);

      if (attendanceData.isEmpty) {
        return emit(const AttendanceFormError('No attendance record found'));
      }

      final record = attendanceData[0];
      final formatted = _formatWorkedHours(record);
      final imageUrl = record['employee_image'] is String
          ? record['employee_image'] as String
          : null;

      emit(
        AttendanceFormLoaded(
          record: record,
          employees: preservedEmployees,
          hasEditAccess: hasAccess,
          formattedHours: formatted,
          imageUrl: imageUrl,
          selectedEmployeeId: record['employee_id'] is List
              ? record['employee_id'][0]
              : null,
        ),
      );
    } catch (e) {
      emit(
        const AttendanceFormError(
          "Something went wrong, please visit again later",
        ),
      );
    }
  }

  /// Handles the [InitializeAttendanceDetails] event.
  ///
  /// Fetches the list of employees and determines whether the current user
  /// has edit access. Updates state accordingly.
  Future<void> _onInitializeDetails(
    InitializeAttendanceDetails event,
    Emitter<AttendanceFormState> emit,
  ) async {
    try {
      await _service.initializeClient();
      final hasAccess = await _service.canManageSkills();
      final employees = await _service.fetchEmployees();

      if (state is AttendanceFormLoaded) {
        final current = state as AttendanceFormLoaded;
        emit(current.copyWith(employees: employees, hasEditAccess: hasAccess));
      } else {
        emit(
          AttendanceFormLoaded(employees: employees, hasEditAccess: hasAccess),
        );
      }
    } catch (e) {
      emit(
        const AttendanceFormError(
          "Something went wrong, please visit again later",
        ),
      );
    }
  }

  /// Handles the [ToggleEditMode] event.
  ///
  /// Enables editing mode in the form by updating [AttendanceFormLoaded.isEditing].
  void _onToggleEdit(ToggleEditMode event, Emitter<AttendanceFormState> emit) {
    if (state is AttendanceFormLoaded) {
      emit((state as AttendanceFormLoaded).copyWith(isEditing: true));
    }
  }

  /// Handles the [CancelEdit] event.
  ///
  /// Disables editing mode in the form by updating [AttendanceFormLoaded.isEditing].
  void _onCancelEdit(CancelEdit event, Emitter<AttendanceFormState> emit) {
    if (state is AttendanceFormLoaded) {
      emit((state as AttendanceFormLoaded).copyWith(isEditing: false));
    }
  }

  /// Converts a local date-time string to Odoo-compatible UTC format.
  ///
  /// Returns `null` if the input is invalid, empty, or 'false'.
  String? toOdooUtc(String? value) {
    if (value == null || value.isEmpty || value == 'false') return null;

    try {
      final local = DateTime.parse(value);
      final utc = local.toUtc();
      return DateFormat('yyyy-MM-dd HH:mm:ss').format(utc);
    } catch (e) {
      return null;
    }
  }

  /// Handles the [SaveAttendance] event.
  ///
  /// Sends updated attendance data to the service, updates the state with
  /// success or error messages, and triggers re-initialization on success.
  Future<void> _onSaveAttendance(
    SaveAttendance event,
    Emitter<AttendanceFormState> emit,
  ) async {
    final current = state as AttendanceFormLoaded;
    try {
      final updatedRecord = await _service.fetchAttendance(
        current.record?['id'],
      );
      final newRecord = updatedRecord[0];

      emit(current.copyWith(isSaving: true));

      final data = {
        'employee_id': event.employeeId,
        'check_in':
            (event.checkIn == null ||
                event.checkIn == 'false' ||
                event.checkIn == false ||
                event.checkIn.isEmpty)
            ? null
            : toOdooUtc(event.checkIn),
        'check_out':
            (event.checkOut == null ||
                event.checkOut == 'false' ||
                event.checkOut == false ||
                event.checkOut.isEmpty)
            ? null
            : toOdooUtc(event.checkOut),
      };

      final result = await _service.updateAttendance(
        current.record?['id'],
        data,
      );

      if (result['success'] == true) {
        emit(
          current.copyWith(
            isSaving: false,
            isEditing: false,
            successMessage: "Attendance updated successfully",
          ),
        );
        add(
          InitializeAttendance(
            attendanceId: current.record?['id'],
            workingHours: current.formattedHours!,
          ),
        );
      } else {
        String msg = result['error']?.toString() ?? 'Update failed';
        if (msg.contains('AccessError')) {
          msg = 'You do not have permission to edit this attendance.';
        }
        emit(
          current.copyWith(
            isSaving: false,
            isEditing: false,
            errorMessage: msg,
            record: newRecord,
            imageUrl: newRecord['employee_image'] is String
                ? newRecord['employee_image']
                : null,
          ),
        );
      }
    } catch (e) {
      emit(
        current.copyWith(
          isSaving: false,
          isEditing: false,
          errorMessage: "Something went wrong, Please try again later",
        ),
      );
    }
  }

  /// Formats the worked hours for display based on check-in and check-out times.
  ///
  /// Returns a string in the format "HH:MM (checkInTime-checkOutTime)".
  /// If check-out is missing, returns "From checkInTime".
  /// Returns "N/A" if the check-in time is missing or invalid.
  String _formatWorkedHours(Map<String, dynamic> record) {
    final checkInStr = record['check_in'];
    final checkOutStr = record['check_out'];
    if (checkInStr == null || checkInStr == false) return 'N/A';

    try {
      final checkIn = DateTime.parse('${checkInStr}Z').toLocal();
      final checkInTime =
          '${checkIn.hour.toString().padLeft(2, '0')}:${checkIn.minute.toString().padLeft(2, '0')}';

      if (checkOutStr == null || checkOutStr == false) {
        return 'From $checkInTime';
      }

      final checkOut = DateTime.parse('${checkOutStr}Z').toLocal();
      final duration = checkOut.difference(checkIn);
      final hours = duration.inHours;
      final minutes = duration.inMinutes % 60;
      final checkOutTime =
          '${checkOut.hour.toString().padLeft(2, '0')}:${checkOut.minute.toString().padLeft(2, '0')}';

      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')} ($checkInTime-$checkOutTime)';
    } catch (e) {
      return 'N/A';
    }
  }
}
