import 'package:equatable/equatable.dart';
import 'package:file_picker/file_picker.dart';

/// Immutable state class for the "Request Absence / Leave" form
/// managed by [RequestAbsenceBloc].
///
/// Holds all form data, UI visibility flags, loading/saving states,
/// selected values, attachments, and success/error feedback.
class RequestAbsenceState extends Equatable {
  final bool isLoading;
  final bool isSaving;
  final List<Map<String, dynamic>> leaveTypes;
  final List<Map<String, dynamic>> employees;
  final int? selectedHolidayStatusId;
  final Map<String, dynamic>? selectedLeaveType;
  final List<int> selectedEmployeeIds;
  final int? selectedEmployeeId;
  final String dateFrom;
  final String dateTo;
  final String durationDays;
  final String description;
  final bool isHalfDay;
  final bool isCustomHours;
  final String halfDayType;
  final String? hourFrom;
  final String? hourTo;
  final PlatformFile? attachedFile;
  final String? attachedFileName;
  final bool showHalfDayOptions;
  final bool showFilePicker;
  final String? errorMessage;
  final bool success;

  const RequestAbsenceState({
    this.isLoading = false,
    this.isSaving = false,
    this.leaveTypes = const [],
    this.employees = const [],
    this.selectedHolidayStatusId,
    this.selectedLeaveType,
    this.selectedEmployeeIds = const [],
    this.selectedEmployeeId,
    this.dateFrom = '',
    this.dateTo = '',
    this.durationDays = '1',
    this.description = '',
    this.isHalfDay = false,
    this.isCustomHours = false,
    this.halfDayType = 'am',
    this.hourFrom,
    this.hourTo,
    this.attachedFile,
    this.attachedFileName,
    this.showHalfDayOptions = false,
    this.showFilePicker = false,
    this.errorMessage,
    this.success = false,
  });

  /// Creates a new state instance by copying the current one and overriding
  /// only the provided fields.
  RequestAbsenceState copyWith({
    bool? isLoading,
    bool? isSaving,
    List<Map<String, dynamic>>? leaveTypes,
    List<Map<String, dynamic>>? employees,
    int? selectedHolidayStatusId,
    Map<String, dynamic>? selectedLeaveType,
    List<int>? selectedEmployeeIds,
    int? selectedEmployeeId,
    String? dateFrom,
    String? dateTo,
    String? durationDays,
    String? description,
    bool? isHalfDay,
    bool? isCustomHours,
    String? halfDayType,
    String? hourFrom,
    String? hourTo,
    PlatformFile? attachedFile,
    String? attachedFileName,
    bool? showHalfDayOptions,
    bool? showFilePicker,
    String? errorMessage,
    bool? success,
  }) {
    return RequestAbsenceState(
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      leaveTypes: leaveTypes ?? this.leaveTypes,
      employees: employees ?? this.employees,
      selectedHolidayStatusId:
          selectedHolidayStatusId ?? this.selectedHolidayStatusId,
      selectedLeaveType: selectedLeaveType ?? this.selectedLeaveType,
      selectedEmployeeIds: selectedEmployeeIds ?? this.selectedEmployeeIds,
      selectedEmployeeId: selectedEmployeeId ?? this.selectedEmployeeId,
      dateFrom: dateFrom ?? this.dateFrom,
      dateTo: dateTo ?? this.dateTo,
      durationDays: durationDays ?? this.durationDays,
      description: description ?? this.description,
      isHalfDay: isHalfDay ?? this.isHalfDay,
      isCustomHours: isCustomHours ?? this.isCustomHours,
      halfDayType: halfDayType ?? this.halfDayType,
      hourFrom: hourFrom ?? this.hourFrom,
      hourTo: hourTo ?? this.hourTo,
      attachedFile: attachedFile ?? this.attachedFile,
      attachedFileName: attachedFileName ?? this.attachedFileName,
      showHalfDayOptions: showHalfDayOptions ?? this.showHalfDayOptions,
      showFilePicker: showFilePicker ?? this.showFilePicker,
      errorMessage: errorMessage,
      success: success ?? this.success,
    );
  }

  @override
  List<Object?> get props => [
    isLoading,
    isSaving,
    leaveTypes,
    employees,
    selectedHolidayStatusId,
    selectedLeaveType,
    selectedEmployeeIds,
    selectedEmployeeId,
    dateFrom,
    dateTo,
    durationDays,
    description,
    isHalfDay,
    isCustomHours,
    halfDayType,
    hourFrom,
    hourTo,
    attachedFile,
    attachedFileName,
    showHalfDayOptions,
    showFilePicker,
    errorMessage,
    success,
  ];
}

/// Returns a completely reset state with default values.
/// Useful after successful submission or manual reset.
RequestAbsenceState reset() {
  return const RequestAbsenceState();
}
