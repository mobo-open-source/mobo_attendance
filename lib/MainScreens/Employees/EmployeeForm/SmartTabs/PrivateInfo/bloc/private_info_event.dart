import 'dart:typed_data';

/// Base class for all events dispatched to [PrivateInfoBloc].
///
/// All events extend this abstract class to ensure proper value-based equality
/// comparison (via Equatable or similar in the bloc implementation), which helps
/// prevent unnecessary state rebuilds when identical events are dispatched.
abstract class PrivateInfoEvent {}

/// Triggered when navigating to the Private Information page.
///
/// Loads core private employee data (address, contact, IDs, DOB, marital, etc.)
/// and initializes form controllers. Usually dispatched in `didChangeDependencies()`
class LoadPrivateInfo extends PrivateInfoEvent {
  final int employeeId;
  final bool showLoading;

  LoadPrivateInfo(this.employeeId, {this.showLoading = true});
}

/// Loads supporting dropdown lists and static data (countries, states, languages).
///
/// Dispatched after or alongside `LoadPrivateInfo` to populate selection options.
/// Preserves previously loaded lists when refreshing employee data.
class LoadPrivateInfoDetails extends PrivateInfoEvent {
  LoadPrivateInfoDetails();
}

/// Switches the UI from view mode to edit mode.
///
/// Enables form fields, shows save button, and allows changes to be tracked.
class ToggleEditMode extends PrivateInfoEvent {}

/// Exits edit mode and discards unsaved changes.
///
/// Usually triggered by cancel button or back navigation after confirmation.
class CancelEdit extends PrivateInfoEvent {}

/// Updates a single private information field (dropdown selection or text).
///
/// Used for both dropdowns (country, state, gender, etc.) and free-text fields.
class UpdateField extends PrivateInfoEvent {
  final String field;
  final dynamic value;

  UpdateField(this.field, this.value);
}

/// Triggers validation and saving of updated private fields to Odoo.
///
/// Dispatched when user presses "Save Changes" button in edit mode.
class SavePrivateInfo extends PrivateInfoEvent {
  final int employeeId;
  SavePrivateInfo(this.employeeId);
}

/// Uploads a new work permit document (PDF/image) as base64 string.
///
/// Stores the file in the `has_work_permit` binary field.
class UploadWorkPermit extends PrivateInfoEvent {
  final int employeeId;
  final Uint8List fileBytes;
  final String base64String;

  UploadWorkPermit(this.employeeId, this.fileBytes, this.base64String);
}

/// Deletes the existing work permit document.
///
/// Clears the `has_work_permit` binary field.
class DeleteWorkPermit extends PrivateInfoEvent {
  final int employeeId;
  DeleteWorkPermit(this.employeeId);
}
