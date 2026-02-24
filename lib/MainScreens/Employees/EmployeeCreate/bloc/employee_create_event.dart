import 'package:equatable/equatable.dart';

/// Base class for all events dispatched to [EmployeeCreateBloc].
///
/// All events extend this abstract class to ensure proper value-based equality
/// comparison via [Equatable], which helps prevent unnecessary state rebuilds
/// when identical events are dispatched.
abstract class EmployeeCreateEvent extends Equatable {
  const EmployeeCreateEvent();

  @override
  List<Object?> get props => [];
}

/// Triggered when the employee creation/editing screen is first opened.
///
/// Dispatched in `initState()` or on navigation to load dropdown data
/// (users, departments, jobs, countries, etc.) from Odoo.
class InitializeCreateEmployee extends EmployeeCreateEvent {}

/// Event dispatched when the user types or changes the employee's full name.
class UpdateName extends EmployeeCreateEvent {
  final String name;

  const UpdateName(this.name);

  @override
  List<Object> get props => [name];
}

/// Event dispatched when the user updates the work email address.
class UpdateWorkEmail extends EmployeeCreateEvent {
  final String email;

  const UpdateWorkEmail(this.email);

  @override
  List<Object> get props => [email];
}

/// Event dispatched when the user updates the work phone number.
class UpdateWorkPhone extends EmployeeCreateEvent {
  final String phone;

  const UpdateWorkPhone(this.phone);

  @override
  List<Object> get props => [phone];
}

/// Event dispatched when the user updates the mobile phone number.
class UpdateMobilePhone extends EmployeeCreateEvent {
  final String mobile;

  const UpdateMobilePhone(this.mobile);

  @override
  List<Object> get props => [mobile];
}

/// Event dispatched when the user sets or changes the employee's internal PIN/code.
class UpdatePin extends EmployeeCreateEvent {
  final String pin;

  const UpdatePin(this.pin);

  @override
  List<Object> get props => [pin];
}

/// Event dispatched when the user sets or changes the employee's badge/ID number.
class UpdateBadge extends EmployeeCreateEvent {
  final String badge;

  const UpdateBadge(this.badge);

  @override
  List<Object> get props => [badge];
}

/// Event dispatched when the user picks a profile picture from the gallery.
class PickImage extends EmployeeCreateEvent {}

/// Event dispatched when the user selects a department from the dropdown.
class UpdateDepartment extends EmployeeCreateEvent {
  final int? id;

  const UpdateDepartment(this.id);

  @override
  List<Object?> get props => [id];
}

/// Event dispatched when the user selects a job position from the dropdown.
class UpdateJob extends EmployeeCreateEvent {
  final int? id;

  const UpdateJob(this.id);

  @override
  List<Object?> get props => [id];
}

/// Event dispatched when the user selects a manager from the employee list.
class UpdateManager extends EmployeeCreateEvent {
  final int? id;

  const UpdateManager(this.id);

  @override
  List<Object?> get props => [id];
}

/// Event dispatched when the user selects a coach/mentor from the employee list.
class UpdateCoach extends EmployeeCreateEvent {
  final int? id;

  const UpdateCoach(this.id);

  @override
  List<Object?> get props => [id];
}

/// Event dispatched when the user links an existing Odoo user to this employee.
class UpdateUser extends EmployeeCreateEvent {
  final int? id;

  const UpdateUser(this.id);

  @override
  List<Object?> get props => [id];
}

/// Event dispatched when the user changes the employee type/category.
class UpdateEmployeeType extends EmployeeCreateEvent {
  final String type;

  const UpdateEmployeeType(this.type);

  @override
  List<Object> get props => [type];
}

/// ── Private Address & Contact Events ───────────────────────────────────────

class UpdatePrivateStreet extends EmployeeCreateEvent {
  final String street;

  const UpdatePrivateStreet(this.street);

  @override
  List<Object> get props => [street];
}

class UpdatePrivateStreet2 extends EmployeeCreateEvent {
  final String street2;

  const UpdatePrivateStreet2(this.street2);

  @override
  List<Object> get props => [street2];
}

class UpdatePrivateCity extends EmployeeCreateEvent {
  final String city;

  const UpdatePrivateCity(this.city);

  @override
  List<Object> get props => [city];
}

class UpdatePrivateState extends EmployeeCreateEvent {
  final int? id;

  const UpdatePrivateState(this.id);

  @override
  List<Object?> get props => [id];
}

class UpdatePrivateCountry extends EmployeeCreateEvent {
  final int? id;

  const UpdatePrivateCountry(this.id);

  @override
  List<Object?> get props => [id];
}

class UpdatePrivateEmail extends EmployeeCreateEvent {
  final String email;

  const UpdatePrivateEmail(this.email);

  @override
  List<Object> get props => [email];
}

class UpdatePrivatePhone extends EmployeeCreateEvent {
  final String phone;

  const UpdatePrivatePhone(this.phone);

  @override
  List<Object> get props => [phone];
}

class UpdatePrivateBank extends EmployeeCreateEvent {
  final int? id;

  const UpdatePrivateBank(this.id);

  @override
  List<Object?> get props => [id];
}

class UpdatePrivateLang extends EmployeeCreateEvent {
  final String? langCode;

  const UpdatePrivateLang(this.langCode);

  @override
  List<Object?> get props => [langCode];
}

class UpdateKmHomeWork extends EmployeeCreateEvent {
  final String km;

  const UpdateKmHomeWork(this.km);

  @override
  List<Object> get props => [km];
}

class UpdatePrivateCarPlate extends EmployeeCreateEvent {
  final String plate;

  const UpdatePrivateCarPlate(this.plate);

  @override
  List<Object> get props => [plate];
}

/// ── Identification & Personal Info Events ──────────────────────────────────

class UpdateCountry extends EmployeeCreateEvent {
  final int? id;

  const UpdateCountry(this.id);

  @override
  List<Object?> get props => [id];
}

class UpdateIdentificationId extends EmployeeCreateEvent {
  final String idNo;

  const UpdateIdentificationId(this.idNo);

  @override
  List<Object> get props => [idNo];
}

class UpdateSsnId extends EmployeeCreateEvent {
  final String ssn;

  const UpdateSsnId(this.ssn);

  @override
  List<Object> get props => [ssn];
}

class UpdatePassportId extends EmployeeCreateEvent {
  final String passport;

  const UpdatePassportId(this.passport);

  @override
  List<Object> get props => [passport];
}

class UpdateBirthday extends EmployeeCreateEvent {
  final String date;

  const UpdateBirthday(this.date);

  @override
  List<Object> get props => [date];
}

class UpdateGender extends EmployeeCreateEvent {
  final String? gender;

  const UpdateGender(this.gender);

  @override
  List<Object?> get props => [gender];
}

class UpdatePlaceOfBirth extends EmployeeCreateEvent {
  final String place;

  const UpdatePlaceOfBirth(this.place);

  @override
  List<Object> get props => [place];
}

class UpdateCountryOfBirth extends EmployeeCreateEvent {
  final int? id;

  const UpdateCountryOfBirth(this.id);

  @override
  List<Object?> get props => [id];
}

class UpdateMaritalStatus extends EmployeeCreateEvent {
  final String? status;

  const UpdateMaritalStatus(this.status);

  @override
  List<Object?> get props => [status];
}

class UpdateSpouseName extends EmployeeCreateEvent {
  final String name;

  const UpdateSpouseName(this.name);

  @override
  List<Object> get props => [name];
}

class UpdateSpouseBirthday extends EmployeeCreateEvent {
  final String date;

  const UpdateSpouseBirthday(this.date);

  @override
  List<Object> get props => [date];
}

class UpdateChildren extends EmployeeCreateEvent {
  final String count;

  const UpdateChildren(this.count);

  @override
  List<Object> get props => [count];
}

class UpdateCertificate extends EmployeeCreateEvent {
  final String? level;

  const UpdateCertificate(this.level);

  @override
  List<Object?> get props => [level];
}

class UpdateFieldOfStudy extends EmployeeCreateEvent {
  final String field;

  const UpdateFieldOfStudy(this.field);

  @override
  List<Object> get props => [field];
}

class UpdateStudySchool extends EmployeeCreateEvent {
  final String school;

  const UpdateStudySchool(this.school);

  @override
  List<Object> get props => [school];
}

/// ── Visa & Work Permit Events ──────────────────────────────────────────────

class UpdateVisaNo extends EmployeeCreateEvent {
  final String visa;

  const UpdateVisaNo(this.visa);

  @override
  List<Object> get props => [visa];
}

class UpdatePermitNo extends EmployeeCreateEvent {
  final String permit;

  const UpdatePermitNo(this.permit);

  @override
  List<Object> get props => [permit];
}

class UpdateVisaExpire extends EmployeeCreateEvent {
  final String date;

  const UpdateVisaExpire(this.date);

  @override
  List<Object> get props => [date];
}

class UpdateWorkPermitExpire extends EmployeeCreateEvent {
  final String date;

  const UpdateWorkPermitExpire(this.date);

  @override
  List<Object> get props => [date];
}

/// ── Work Location & Settings Events ────────────────────────────────────────

class UpdateAddress extends EmployeeCreateEvent {
  final int? id;

  const UpdateAddress(this.id);

  @override
  List<Object?> get props => [id];
}

class UpdateWorkLocation extends EmployeeCreateEvent {
  final int? id;

  const UpdateWorkLocation(this.id);

  @override
  List<Object?> get props => [id];
}

class UpdateExpenseManager extends EmployeeCreateEvent {
  final int? id;

  const UpdateExpenseManager(this.id);

  @override
  List<Object?> get props => [id];
}

class UpdateWorkingHours extends EmployeeCreateEvent {
  final int? id;

  const UpdateWorkingHours(this.id);

  @override
  List<Object?> get props => [id];
}

class UpdateTimezone extends EmployeeCreateEvent {
  final String? tz;

  const UpdateTimezone(this.tz);

  @override
  List<Object?> get props => [tz];
}

/// ── Resume & Skills Management Events ──────────────────────────────────────

/// Event dispatched when a new resume line is added (via dialog).
class AddResumeLine extends EmployeeCreateEvent {
  final Map<String, dynamic> line;

  const AddResumeLine(this.line);

  @override
  List<Object> get props => [line];
}

/// Event dispatched when a resume line is removed.
class RemoveResumeLine extends EmployeeCreateEvent {
  final int index;

  const RemoveResumeLine(this.index);

  @override
  List<Object> get props => [index];
}

/// Event dispatched when a new skill is added (via dialog).
class AddSkill extends EmployeeCreateEvent {
  final Map<String, dynamic> skill;

  const AddSkill(this.skill);

  @override
  List<Object> get props => [skill];
}

/// Event dispatched when a skill entry is removed.
class RemoveSkill extends EmployeeCreateEvent {
  final int index;

  const RemoveSkill(this.index);

  @override
  List<Object> get props => [index];
}

/// Event dispatched when the user presses the "Create Employee" button.
///
/// Triggers validation, payload preparation, and submission to Odoo.
class CreateEmployee extends EmployeeCreateEvent {}

/// Event dispatched to reset the entire form to default/empty values.
///
/// Usually triggered after successful creation or via a reset button.
class ResetForm extends EmployeeCreateEvent {}
