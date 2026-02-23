import 'package:equatable/equatable.dart';
import 'package:file_picker/file_picker.dart';

/// Base class for all events dispatched to [RequestAbsenceBloc].
///
/// All events extend this abstract class to ensure proper value-based equality
/// comparison via [Equatable], which prevents unnecessary state rebuilds when
/// identical events are dispatched.
abstract class RequestAbsenceEvent extends Equatable {
  const RequestAbsenceEvent();

  @override
  List<Object?> get props => [];
}

/// Triggered when the "Request Absence" screen is first opened.
///
/// Usually dispatched in `initState()` or on navigation to the page.
/// It initializes the form by loading leave types, employees, current user,
/// and setting default dates to today.
class InitializeRequestAbsence extends RequestAbsenceEvent {}

/// Event dispatched when the user selects a leave/time-off type from the dropdown.
///
/// Carries the selected `holiday_status_id` and updates:
/// - Selected leave type data
/// - Whether to show half-day / custom hours options
/// - Whether to show file attachment field
class SelectLeaveType extends RequestAbsenceEvent {
  final int holidayStatusId;

  const SelectLeaveType(this.holidayStatusId);

  @override
  List<Object> get props => [holidayStatusId];
}

/// Event dispatched when the user changes the start date (`request_date_from`).
///
/// Automatically adjusts end date if needed and recalculates duration.
class UpdateDateFrom extends RequestAbsenceEvent {
  final String date;

  const UpdateDateFrom(this.date);

  @override
  List<Object> get props => [date];
}

/// Event dispatched when the user changes the end date (`request_date_to`).
///
/// Recalculates duration automatically.
class UpdateDateTo extends RequestAbsenceEvent {
  final String date;

  const UpdateDateTo(this.date);

  @override
  List<Object> get props => [date];
}

/// Event dispatched when the user manually changes the duration (days).
///
/// Rarely used — duration is usually auto-calculated from dates.
class UpdateDuration extends RequestAbsenceEvent {
  final String days;

  const UpdateDuration(this.days);

  @override
  List<Object> get props => [days];
}

/// Event dispatched when the user types in the description/reason field.
class UpdateDescription extends RequestAbsenceEvent {
  final String text;

  const UpdateDescription(this.text);

  @override
  List<Object> get props => [text];
}

/// Event dispatched when the user toggles half-day mode (AM/PM).
///
/// Disables custom hours when enabled.
class ToggleHalfDay extends RequestAbsenceEvent {
  final bool value;

  const ToggleHalfDay(this.value);

  @override
  List<Object> get props => [value];
}

/// Event dispatched when the user toggles custom hours input mode.
///
/// Disables half-day when enabled and sets default hours (0.0 → 0.5).
class ToggleCustomHours extends RequestAbsenceEvent {
  final bool value;

  const ToggleCustomHours(this.value);

  @override
  List<Object> get props => [value];
}

/// Event dispatched when the user selects AM or PM for half-day mode.
class UpdateHalfDayType extends RequestAbsenceEvent {
  final String type;

  const UpdateHalfDayType(this.type);

  @override
  List<Object> get props => [type];
}

/// Event dispatched when the user changes the start hour for custom hours.
class UpdateHourFrom extends RequestAbsenceEvent {
  final String hour;

  const UpdateHourFrom(this.hour);

  @override
  List<Object> get props => [hour];
}

/// Event dispatched when the user changes the end hour for custom hours.
class UpdateHourTo extends RequestAbsenceEvent {
  final String hour;

  const UpdateHourTo(this.hour);

  @override
  List<Object> get props => [hour];
}

/// Event dispatched when the user picks a file to attach as supporting document.
class AttachFile extends RequestAbsenceEvent {
  final PlatformFile file;

  const AttachFile(this.file);

  @override
  List<Object?> get props => [file];
}

/// Event dispatched when the user removes the attached file.
class RemoveAttachment extends RequestAbsenceEvent {}

/// Event dispatched when the user presses the "Submit Request" button.
///
/// Triggers validation, attachment upload (if any), and creation of the leave
/// request record in Odoo.
class SubmitLeaveRequest extends RequestAbsenceEvent {}

/// Event dispatched to reset the form to initial/default values.
///
/// Usually triggered after successful submission or via a "Reset" button.
/// Preserves loaded leave types and employees.
class ResetRequestAbsence extends RequestAbsenceEvent {}
