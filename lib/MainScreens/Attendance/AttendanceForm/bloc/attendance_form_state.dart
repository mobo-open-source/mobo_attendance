part of 'attendance_form_bloc.dart';

/// Base class for all states emitted by [AttendanceFormBloc].
/// Extends [Equatable] to support value-based comparisons.
abstract class AttendanceFormState extends Equatable {
  const AttendanceFormState();

  @override
  List<Object?> get props => [];
}

/// Initial state of the attendance form.
/// Typically emitted before any data is loaded.
class AttendanceFormInitial extends AttendanceFormState {}

/// State emitted when the attendance form is loading data.
///
/// Optionally contains:
/// - [employees]: List of employees fetched so far.
/// - [hasEditAccess]: Boolean indicating if the current user can edit attendance.
class AttendanceFormLoading extends AttendanceFormState {
  final List<Map<String, dynamic>>? employees;
  final bool? hasEditAccess;

  const AttendanceFormLoading({this.employees, this.hasEditAccess});

  @override
  List<Object?> get props => [employees, hasEditAccess];
}

/// State emitted when the attendance form has successfully loaded.
///
/// Contains:
/// - [record]: The attendance record data.
/// - [employees]: List of employees.
/// - [isEditing]: Whether the form is currently in edit mode.
/// - [isSaving]: Whether a save operation is in progress.
/// - [isLoading]: Whether additional loading is in progress.
/// - [hasEditAccess]: Whether the user has permission to edit.
/// - [formattedHours]: Formatted worked hours string.
/// - [imageUrl]: Employee profile image URL.
/// - [selectedEmployeeId]: Currently selected employee ID.
/// - [errorMessage]: Optional error message.
/// - [checkIn], [checkOut]: Check-in and check-out times.
/// - [successMessage]: Optional success message.
/// - [isEmployeeSelect]: Whether an employee has been selected.
class AttendanceFormLoaded extends AttendanceFormState {
  final Map<String, dynamic>? record;
  final List<Map<String, dynamic>>? employees;
  final bool isEditing;
  final bool isSaving;
  final bool isLoading;
  final bool? hasEditAccess;
  final String? formattedHours;
  final String? imageUrl;
  final int? selectedEmployeeId;
  final String? errorMessage;
  final String? checkIn;
  final String? checkOut;
  final String? successMessage;
  final bool isEmployeeSelect;

  const AttendanceFormLoaded({
    this.record,
    this.employees,
    this.isEditing = false,
    this.isSaving = false,
    this.isLoading = true,
    this.hasEditAccess,
    this.formattedHours,
    this.imageUrl,
    this.selectedEmployeeId,
    this.errorMessage,
    this.checkIn,
    this.checkOut,
    this.successMessage,
    this.isEmployeeSelect = false,
  });

  /// Returns a copy of this state with updated fields.
  ///
  /// Useful for modifying individual properties without recreating
  /// the entire state.
  AttendanceFormLoaded copyWith({
    Map<String, dynamic>? record,
    List<Map<String, dynamic>>? employees,
    bool? isEditing,
    bool? isSaving,
    bool? isLoading,
    bool? hasEditAccess,
    String? formattedHours,
    String? imageUrl,
    bool clearEmployeeImage = false,
    String? errorMessage,
    int? selectedEmployeeId,
    String? checkIn,
    String? checkOut,
    String? successMessage,
    bool? isEmployeeSelect,
  }) {
    return AttendanceFormLoaded(
      record: record ?? this.record,
      employees: employees ?? this.employees,
      isEditing: isEditing ?? this.isEditing,
      isSaving: isSaving ?? this.isSaving,
      isLoading: isLoading ?? this.isLoading,
      hasEditAccess: hasEditAccess ?? this.hasEditAccess,
      formattedHours: formattedHours ?? this.formattedHours,
      imageUrl: clearEmployeeImage ? null : imageUrl ?? this.imageUrl,
      selectedEmployeeId: selectedEmployeeId ?? this.selectedEmployeeId,
      errorMessage: errorMessage,
      checkIn: checkIn ?? this.checkIn,
      checkOut: checkOut ?? this.checkOut,
      successMessage: successMessage,
      isEmployeeSelect: isEmployeeSelect ?? this.isEmployeeSelect,
    );
  }

  @override
  List<Object?> get props => [
    record,
    employees,
    isEditing,
    isSaving,
    hasEditAccess,
    formattedHours,
    imageUrl,
    selectedEmployeeId,
    errorMessage,
    checkIn,
    checkOut,
    isEmployeeSelect,
  ];
}

/// State emitted when there is an error in the attendance form.
///
/// Contains:
/// - [message]: Error description.
class AttendanceFormError extends AttendanceFormState {
  final String message;

  const AttendanceFormError(this.message);

  @override
  List<Object?> get props => [message];
}

/// State emitted when an operation succeeds in the attendance form.
///
/// Contains:
/// - [message]: Success description.
class AttendanceFormSuccess extends AttendanceFormState {
  final String message;

  const AttendanceFormSuccess(this.message);
}
