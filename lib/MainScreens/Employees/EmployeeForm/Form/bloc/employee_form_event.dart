part of 'employee_form_bloc.dart';

/// Base class for all events dispatched to [EmployeeFormBloc].
///
/// All events extend this abstract class to ensure proper value-based equality
/// comparison (via Equatable in the bloc implementation), which helps prevent
/// unnecessary state rebuilds when identical events are dispatched.
abstract class EmployeeFormEvent {}

/// Triggered when navigating to the employee detail page.
///
/// Loads core employee data and initializes form controllers.
/// Usually dispatched in `didChangeDependencies()` of the page.
class LoadEmployee extends EmployeeFormEvent {
  final int employeeId;
  LoadEmployee(this.employeeId);
}

/// Loads supporting dropdown lists (jobs, departments, users, resume types, skill types).
///
/// Dispatched after or alongside `LoadEmployee` to populate selection options.
/// Preserves previously loaded lists when refreshing employee data.
class LoadEmployeeDetails extends EmployeeFormEvent {
  LoadEmployeeDetails();
}

/// Switches the UI from view mode to edit mode.
///
/// Enables form fields, shows save button, and allows changes to be tracked.
class ToggleEditMode extends EmployeeFormEvent {}

/// Exits edit mode and discards unsaved changes.
///
/// Usually triggered by cancel button or back navigation after confirmation.
class CancelEdit extends EmployeeFormEvent {}

/// Updates the employee's full name field.
class UpdateName extends EmployeeFormEvent {
  final String name;
  UpdateName(this.name);
}

/// Updates the selected job position (many2one field).
class UpdateJob extends EmployeeFormEvent {
  final int? jobId;
  UpdateJob(this.jobId);
}

/// Updates the selected department (many2one field).
class UpdateDepartment extends EmployeeFormEvent {
  final int? departmentId;
  UpdateDepartment(this.departmentId);
}

/// Updates the selected manager (parent_id - many2one to hr.employee).
class UpdateManager extends EmployeeFormEvent {
  final int? managerId;
  UpdateManager(this.managerId);
}

/// Updates the selected coach/mentor (coach_id - many2one to hr.employee).
class UpdateCoach extends EmployeeFormEvent {
  final int? coachId;
  UpdateCoach(this.coachId);
}

/// Updates the work email address.
class UpdateWorkEmail extends EmployeeFormEvent {
  final String email;
  UpdateWorkEmail(this.email);
}

/// Updates the work phone number.
class UpdateWorkPhone extends EmployeeFormEvent {
  final String phone;
  UpdateWorkPhone(this.phone);
}

/// Updates the mobile/personal phone number.
class UpdateMobilePhone extends EmployeeFormEvent {
  final String mobile;
  UpdateMobilePhone(this.mobile);
}

/// Updates the employee type/category (selection field).
class UpdateEmployeeType extends EmployeeFormEvent {
  final String? type;
  UpdateEmployeeType(this.type);
}

/// Updates the linked Odoo user (res.users record).
class UpdateRelatedUser extends EmployeeFormEvent {
  final int? userId;
  UpdateRelatedUser(this.userId);
}

/// Updates the internal PIN/code.
class UpdatePin extends EmployeeFormEvent {
  final String pin;
  UpdatePin(this.pin);
}

/// Updates the badge/ID card number.
class UpdateBadge extends EmployeeFormEvent {
  final String badge;
  UpdateBadge(this.badge);
}

/// Updates the profile image (base64 string from gallery picker).
class UpdateProfileImage extends EmployeeFormEvent {
  final String? base64Image;
  UpdateProfileImage(this.base64Image);
}

/// Triggers validation and saving of updated employee fields to Odoo.
///
/// Dispatched when user presses "Save Changes" button in edit mode.
class SaveEmployee extends EmployeeFormEvent {}

/// Generates a new badge number for the employee via Odoo.
///
/// Usually triggered by "Generate Badge" button when badge is empty.
class GenerateBadge extends EmployeeFormEvent {}

/// Adds a new resume line (experience/education/certification).
class AddResumeLine extends EmployeeFormEvent {
  final Map<String, dynamic> data;
  AddResumeLine(this.data);
}

/// Updates an existing resume line.
class UpdateResumeLine extends EmployeeFormEvent {
  final int lineId;
  final Map<String, dynamic> data;
  UpdateResumeLine(this.lineId, this.data);
}

/// Deletes an existing resume line.
class DeleteResumeLine extends EmployeeFormEvent {
  final int lineId;
  DeleteResumeLine(this.lineId);
}

/// Adds a new skill entry to the employee.
class AddSkill extends EmployeeFormEvent {
  final Map<String, dynamic> data;
  AddSkill(this.data);
}

/// Updates an existing employee skill.
class UpdateSkill extends EmployeeFormEvent {
  final int skillId;
  final Map<String, dynamic> data;
  UpdateSkill(this.skillId, this.data);
}

/// Deletes an existing employee skill.
class DeleteSkill extends EmployeeFormEvent {
  final int skillId;
  DeleteSkill(this.skillId);
}
