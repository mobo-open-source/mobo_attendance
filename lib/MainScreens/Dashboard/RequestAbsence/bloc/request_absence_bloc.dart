import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../Rating/review_service.dart';
import '../services/request_absence_service.dart';
import 'request_absence_event.dart';
import 'request_absence_state.dart';

/// Manages the state and business logic for the "Request Absence / Leave" form.
///
/// Responsibilities:
/// - Loads available leave types and employees
/// - Handles date range selection with automatic duration calculation
/// - Supports half-day and custom hour options (based on leave type rules)
/// - File attachment (supporting document)
/// - Multi-employee selection (if allowed by leave type)
/// - Form validation and submission to Odoo
/// - Success / error feedback + reset after successful submission
/// - Tracks significant events via ReviewService
class RequestAbsenceBloc
    extends Bloc<RequestAbsenceEvent, RequestAbsenceState> {
  late RequestAbsenceService _service;

  RequestAbsenceBloc({RequestAbsenceService? service})
      : _service = service ?? RequestAbsenceService(),
        super(const RequestAbsenceState()) {
    on<InitializeRequestAbsence>(_onInitialize);
    on<SelectLeaveType>(_onSelectLeaveType);
    on<UpdateDateFrom>(_onUpdateDateFrom);
    on<UpdateDateTo>(_onUpdateDateTo);
    on<UpdateDuration>(_onUpdateDuration);
    on<UpdateDescription>(_onUpdateDescription);
    on<ToggleHalfDay>(_onToggleHalfDay);
    on<ToggleCustomHours>(_onToggleCustomHours);
    on<UpdateHalfDayType>(_onUpdateHalfDayType);
    on<UpdateHourFrom>(_onUpdateHourFrom);
    on<UpdateHourTo>(_onUpdateHourTo);
    on<AttachFile>(_onAttachFile);
    on<RemoveAttachment>(_onRemoveAttachment);
    on<SubmitLeaveRequest>(_onSubmit);
    on<ResetRequestAbsence>(_onReset);
  }

  /// Initializes the form: loads leave types, employees, current user employee ID,
  /// and sets default dates to today.
  Future<void> _onInitialize(
    InitializeRequestAbsence event,
    Emitter<RequestAbsenceState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));

    await _service.initializeClient();
    final leaveTypes = await _service.loadLeaveType();
    final employees = await _service.loadEmployees();
    final currentEmployeeId = await _service.loadCurrentEmployeeId();

    final today = DateTime.now();
    final todayStr =
        "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";

    emit(
      state.copyWith(
        isLoading: false,
        leaveTypes: leaveTypes,
        employees: employees,
        selectedEmployeeId: currentEmployeeId,
        selectedEmployeeIds: currentEmployeeId != null && currentEmployeeId > 0
            ? [currentEmployeeId]
            : [],
        dateFrom: todayStr,
        dateTo: todayStr,
      ),
    );
  }

  /// Called when user selects a leave type from dropdown.
  ///
  /// Updates state with selected type and shows/hides UI sections:
  /// - Half-day options (if request_unit == 'hour')
  /// - File picker (if support_document == true)
  void _onSelectLeaveType(
    SelectLeaveType event,
    Emitter<RequestAbsenceState> emit,
  ) {
    final selectedLeaveType = state.leaveTypes.firstWhere(
      (e) => e['id'] == event.holidayStatusId,
      orElse: () => <String, dynamic>{},
    );

    final showHalfDay = selectedLeaveType['request_unit'] == 'hour';
    final showFile = selectedLeaveType['support_document'] == true;

    emit(
      state.copyWith(
        selectedHolidayStatusId: event.holidayStatusId,
        selectedLeaveType: selectedLeaveType.isNotEmpty
            ? selectedLeaveType
            : null,
        showHalfDayOptions: showHalfDay,
        showFilePicker: showFile,
      ),
    );
  }

  /// Updates start date and adjusts end date if necessary.
  /// Recalculates duration automatically.
  void _onUpdateDateFrom(
    UpdateDateFrom event,
    Emitter<RequestAbsenceState> emit,
  ) {
    DateTime newFrom = DateTime.parse(event.date);
    DateTime? currentTo = state.dateTo.isNotEmpty
        ? DateTime.parse(state.dateTo)
        : null;

    String updatedTo = state.dateTo;
    if (currentTo == null || newFrom.isAfter(currentTo)) {
      updatedTo = event.date;
    }

    final duration = _calculateDuration(event.date, updatedTo);

    emit(
      state.copyWith(
        dateFrom: event.date,
        dateTo: updatedTo,
        durationDays: duration,
      ),
    );
  }

  /// Updates end date and recalculates duration.
  void _onUpdateDateTo(UpdateDateTo event, Emitter<RequestAbsenceState> emit) {
    final from = state.dateFrom.isNotEmpty ? state.dateFrom : event.date;

    final duration = _calculateDuration(from, event.date);

    emit(state.copyWith(dateTo: event.date, durationDays: duration));
  }

  /// Calculates inclusive number of days between two date strings.
  /// Returns '1' on invalid input or errors.
  String _calculateDuration(String from, String to) {
    try {
      final fromDate = DateTime.parse(from);
      final toDate = DateTime.parse(to);

      final days = toDate.difference(fromDate).inDays + 1;
      return days < 1 ? '1' : days.toString();
    } catch (_) {
      return '1';
    }
  }

  /// Manual duration update (rarely used — usually auto-calculated)
  void _onUpdateDuration(
    UpdateDuration event,
    Emitter<RequestAbsenceState> emit,
  ) {
    emit(state.copyWith(durationDays: event.days));
  }

  /// Updates leave description / reason field
  void _onUpdateDescription(
    UpdateDescription event,
    Emitter<RequestAbsenceState> emit,
  ) {
    emit(state.copyWith(description: event.text));
  }

  /// Toggles half-day mode (AM/PM).
  /// Disables custom hours when enabled.
  void _onToggleHalfDay(
    ToggleHalfDay event,
    Emitter<RequestAbsenceState> emit,
  ) {
    emit(
      state.copyWith(
        isHalfDay: event.value,
        isCustomHours: false,
        halfDayType: event.value ? 'am' : state.halfDayType,
      ),
    );
  }

  /// Toggles custom hour input mode.
  /// Disables half-day when enabled.
  void _onToggleCustomHours(
    ToggleCustomHours event,
    Emitter<RequestAbsenceState> emit,
  ) {
    emit(
      state.copyWith(
        isCustomHours: event.value,
        isHalfDay: false,
        hourFrom: event.value ? '0.0' : null,
        hourTo: event.value ? '0.5' : null,
      ),
    );
  }

  /// Updates half-day period ('am' or 'pm')
  void _onUpdateHalfDayType(
    UpdateHalfDayType event,
    Emitter<RequestAbsenceState> emit,
  ) {
    emit(state.copyWith(halfDayType: event.type));
  }

  /// Updates start hour for custom hours mode
  void _onUpdateHourFrom(
    UpdateHourFrom event,
    Emitter<RequestAbsenceState> emit,
  ) {
    emit(state.copyWith(hourFrom: event.hour));
  }

  /// Updates end hour for custom hours mode
  void _onUpdateHourTo(UpdateHourTo event, Emitter<RequestAbsenceState> emit) {
    emit(state.copyWith(hourTo: event.hour));
  }

  /// Stores selected file attachment
  void _onAttachFile(AttachFile event, Emitter<RequestAbsenceState> emit) {
    emit(
      state.copyWith(
        attachedFile: event.file,
        attachedFileName: event.file.name,
      ),
    );
  }

  /// Clears current file attachment
  void _onRemoveAttachment(
    RemoveAttachment event,
    Emitter<RequestAbsenceState> emit,
  ) {
    emit(state.copyWith(attachedFile: null, attachedFileName: null));
  }

  /// Submits the leave request to Odoo.
  ///
  /// Steps:
  /// 1. Validates required fields (leave type)
  /// 2. Uploads attachment if present
  /// 3. Builds Odoo-compatible data payload
  /// 4. Creates leave record
  /// 5. Tracks event via ReviewService
  /// 6. On success: resets form (preserves types/employees), shows success
  /// 7. On failure: shows error for 5 seconds
  Future<void> _onSubmit(
    SubmitLeaveRequest event,
    Emitter<RequestAbsenceState> emit,
  ) async {

    emit(state.copyWith(isSaving: true, errorMessage: null));

    if (state.selectedHolidayStatusId == null) {
      emit(state.copyWith(errorMessage: "Please select a Time Off Type",isSaving:false));
      return;
    }

    int? attachmentId;
    if (state.attachedFile != null) {
      await _service.initializeClient();
      attachmentId = await _service.uploadAttachment(
        file: state.attachedFile!,
        model: 'hr.leave',
      );
    }

    final data = {
      'holiday_status_id': state.selectedHolidayStatusId,
      'request_date_from': state.dateFrom,
      if (state.dateTo.isNotEmpty) 'request_date_to': state.dateTo,
      'number_of_days_display': state.durationDays,
      'name': state.description,
      'employee_ids': state.selectedEmployeeIds,
      'employee_id': state.selectedEmployeeId,
      'request_unit_half': state.isHalfDay,
      'request_unit_hours': state.isCustomHours,
      if (state.isHalfDay) 'request_date_from_period': state.halfDayType,
      if (state.isCustomHours) 'request_hour_from': state.hourFrom,
      if (state.isCustomHours) 'request_hour_to': state.hourTo,
      if (attachmentId != null)
        'supported_attachment_ids': [
          [
            6,
            0,
            [attachmentId],
          ],
        ],
    };

    final result = await _service.createRequestAbsence(data);

    // Preserve dropdown data across reset
    final preservedLeaveTypes = state.leaveTypes;
    final preservedEmployees = state.employees;
    final preservedEmployeeId = state.selectedEmployeeId;
    final preservedEmployeeIds = state.selectedEmployeeIds;
    final today = DateTime.now();
    final todayStr =
        "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";

    if (result['success'] == true) {
      emit(state.copyWith(success: true, isSaving: false));

      // Small delay for success feedback, then reset form
      await Future.delayed(const Duration(milliseconds: 300));
      emit(RequestAbsenceState().copyWith(
        leaveTypes: preservedLeaveTypes,
        employees: preservedEmployees,
        selectedEmployeeId: preservedEmployeeId,
        selectedEmployeeIds: preservedEmployeeIds,
        dateFrom: todayStr,
        dateTo: todayStr,
      ));
      ReviewService().trackSignificantEvent();
    } else {
      emit(
        state.copyWith(
          errorMessage: result['error'] ?? "Failed to create leave request",
          isSaving: false,
        ),
      );
      // Auto-clear error after 5 seconds
      Future.delayed(const Duration(seconds: 5), () {
        emit(state.copyWith(errorMessage: null));
      });
    }
  }

  /// Resets the form to initial state (today's date, current employee selected)
  /// while preserving loaded leave types and employees.
  void _onReset(
      ResetRequestAbsence event,
      Emitter<RequestAbsenceState> emit,
      ) {
    final preservedLeaveTypes = state.leaveTypes;
    final preservedEmployees = state.employees;
    final preservedEmployeeId = state.selectedEmployeeId;
    final preservedEmployeeIds = state.selectedEmployeeIds;
    final today = DateTime.now();
    final todayStr =
        "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";

    emit(RequestAbsenceState(
      leaveTypes: preservedLeaveTypes,
      employees: preservedEmployees,
      selectedEmployeeId: preservedEmployeeId,
      selectedEmployeeIds: preservedEmployeeIds,
      dateFrom: todayStr,
      dateTo: todayStr,
    ));
  }
}
