part of 'employee_form_bloc.dart';

/// Immutable state class for [EmployeeFormBloc].
///
/// Holds:
/// - Loading / editing / saving flags
/// - Permission status
/// - Loaded employee record (`employeeDetails`)
/// - Profile image (base64)
/// - Form field values (name, job, department, emails, phones, type, PIN, badge)
/// - Dropdown lists (jobs, departments, users, resume/skill types)
/// - Text controllers for editable fields
/// - Focus node for dropdowns
/// - Messages (error/success/warning)
///
/// Uses `copyWith` pattern for immutable updates with special `XxxIsNull` flags
/// to explicitly clear nullable fields (e.g. `jobId: null`).
class EmployeeFormState {
  final bool isLoading;
  final bool isEditing;
  final bool isSaving;
  final bool hasEditPermission;

  final Map<String, dynamic>? employeeDetails;
  final String? profileImageBase64;

  // ── Form field values (synced with controllers) ───────────────────────────

  final String name;
  final int? jobId;
  final int? departmentId;
  final int? managerId;
  final int? coachId;
  final String workEmail;
  final String workPhone;
  final String mobilePhone;
  final String? employeeType;
  final int? relatedUserId;
  final String pin;
  final String badge;

  // ── Messages (shown via snackbar in UI) ───────────────────────────────────

  final String? errorMessage;
  final String? successMessage;
  final String? warningMessage;

  // ── Dropdown / selection lists (preserved across reloads) ─────────────────

  final List<Map<String, dynamic>> jobList;
  final List<Map<String, dynamic>> departmentList;
  final List<Map<String, dynamic>>
  managerCoachList;
  final List<Map<String, dynamic>> userList;
  final List<Map<String, dynamic>> resumeTypeList;
  final List<Map<String, dynamic>> skillTypeList;

  // ── Controllers & Focus ───────────────────────────────────────────────────

  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController workPhoneController;
  final TextEditingController mobilePhoneController;
  final TextEditingController pinController;
  final TextEditingController badgeController;

  /// Focus node shared across dropdowns (helps with keyboard navigation)
  final FocusNode dropdownFocusNode;

  EmployeeFormState({
    this.isLoading = false,
    this.isEditing = false,
    this.isSaving = false,
    this.hasEditPermission = false,
    this.employeeDetails,
    this.profileImageBase64,
    this.name = '',
    this.jobId,
    this.departmentId,
    this.managerId,
    this.coachId,
    this.workEmail = '',
    this.workPhone = '',
    this.mobilePhone = '',
    this.employeeType,
    this.relatedUserId,
    this.pin = '',
    this.badge = '',
    this.errorMessage,
    this.successMessage,
    this.warningMessage,
    this.jobList = const [],
    this.departmentList = const [],
    this.managerCoachList = const [],
    this.userList = const [],
    this.resumeTypeList = const [],
    this.skillTypeList = const [],
    required this.dropdownFocusNode,
    TextEditingController? nameController,
    TextEditingController? emailController,
    TextEditingController? workPhoneController,
    TextEditingController? mobilePhoneController,
    TextEditingController? pinController,
    TextEditingController? badgeController,
  }) : nameController = nameController ?? TextEditingController(),
       emailController = emailController ?? TextEditingController(),
       workPhoneController = workPhoneController ?? TextEditingController(),
       mobilePhoneController = mobilePhoneController ?? TextEditingController(),
       pinController = pinController ?? TextEditingController(),
       badgeController = badgeController ?? TextEditingController();

  /// Creates a new state instance with updated values.
  ///
  /// Special `XxxIsNull` flags allow explicitly clearing nullable fields
  /// (e.g. `jobIdIsNull: true` → `jobId = null` even if `jobId` param is omitted).
  EmployeeFormState copyWith({
    bool? isLoading,
    bool? isEditing,
    bool? isSaving,
    bool? hasEditPermission,
    Map<String, dynamic>? employeeDetails,
    String? profileImageBase64,
    String? name,
    int? jobId,
    bool jobIdIsNull = false,
    int? departmentId,
    bool departmentIdIsNull = false,
    int? managerId,
    bool managerIdIsNull = false,
    int? coachId,
    bool coachIdIsNull = false,
    String? workEmail,
    String? workPhone,
    String? mobilePhone,
    String? employeeType,
    int? relatedUserId,
    bool relatedUserIdIsNull = false,
    String? pin,
    String? badge,
    String? errorMessage,
    String? successMessage,
    String? warningMessage,
    List<Map<String, dynamic>>? jobList,
    List<Map<String, dynamic>>? departmentList,
    List<Map<String, dynamic>>? managerCoachList,
    List<Map<String, dynamic>>? userList,
    List<Map<String, dynamic>>? resumeTypeList,
    List<Map<String, dynamic>>? skillTypeList,
    bool clearMessage = false,
    FocusNode? dropdownFocusNode,
  }) {
    return EmployeeFormState(
      isLoading: isLoading ?? this.isLoading,
      isEditing: isEditing ?? this.isEditing,
      isSaving: isSaving ?? this.isSaving,
      hasEditPermission: hasEditPermission ?? this.hasEditPermission,
      employeeDetails: employeeDetails ?? this.employeeDetails,
      profileImageBase64: profileImageBase64 ?? this.profileImageBase64,
      name: name ?? this.name,
      jobId: jobIdIsNull ? null : jobId ?? this.jobId,
      departmentId: departmentIdIsNull
          ? null
          : departmentId ?? this.departmentId,
      managerId: managerIdIsNull ? null : managerId ?? this.managerId,
      coachId: coachIdIsNull ? null : coachId ?? this.coachId,
      workEmail: workEmail ?? this.workEmail,
      workPhone: workPhone ?? this.workPhone,
      mobilePhone: mobilePhone ?? this.mobilePhone,
      employeeType: employeeType ?? this.employeeType,
      relatedUserId: relatedUserIdIsNull
          ? null
          : relatedUserId ?? this.relatedUserId,
      pin: pin ?? this.pin,
      badge: badge ?? this.badge,
      errorMessage: clearMessage ? null : errorMessage ?? this.errorMessage,
      successMessage: clearMessage
          ? null
          : successMessage ?? this.successMessage,
      warningMessage: clearMessage
          ? null
          : warningMessage ?? this.warningMessage,
      jobList: jobList ?? this.jobList,
      departmentList: departmentList ?? this.departmentList,
      managerCoachList: managerCoachList ?? this.managerCoachList,
      userList: userList ?? this.userList,
      resumeTypeList: resumeTypeList ?? this.resumeTypeList,
      skillTypeList: skillTypeList ?? this.skillTypeList,
      nameController: nameController,
      emailController: emailController,
      workPhoneController: workPhoneController,
      mobilePhoneController: mobilePhoneController,
      pinController: pinController,
      badgeController: badgeController,
      dropdownFocusNode: dropdownFocusNode ?? this.dropdownFocusNode,
    );
  }

  /// Returns `true` if any form field differs from the original loaded data.
  ///
  /// Compares:
  /// - Text controllers vs original Odoo values
  /// - Dropdown IDs vs original many2one values
  /// - Profile image base64
  ///
  /// Used to enable/disable the "Save Changes" button and show unsaved changes warning.
  bool get hasChanges {
    if (employeeDetails == null) return false;

    String original(dynamic v) => v == false || v == null ? '' : v.toString();

    int? originalId(dynamic v) =>
        (v is List && v.isNotEmpty) ? v.first : (v is int ? v : null);

    return nameController.text.trim() != original(employeeDetails!['name']) ||
        jobId != originalId(employeeDetails!['job_id']) ||
        departmentId != originalId(employeeDetails!['department_id']) ||
        managerId != originalId(employeeDetails!['parent_id']) ||
        coachId != originalId(employeeDetails!['coach_id']) ||
        emailController.text.trim() !=
            original(employeeDetails!['work_email']) ||
        workPhoneController.text.trim() !=
            original(employeeDetails!['work_phone']) ||
        mobilePhoneController.text.trim() !=
            original(employeeDetails!['mobile_phone']) ||
        employeeType != original(employeeDetails!['employee_type']) ||
        relatedUserId != originalId(employeeDetails!['user_id']) ||
        profileImageBase64 != employeeDetails!['image_1920'] ||
        badgeController.text.trim() != original(employeeDetails!['barcode']) ||
        pinController.text.trim() != original(employeeDetails!['pin']);
  }
}

/// Initial empty state (before any employee is loaded)
class EmployeeInitial extends EmployeeFormState {
  EmployeeInitial({required super.dropdownFocusNode});
}

/// Generic event to mark that a form field was changed.
///
/// Triggers `hasChanges = true` in the bloc (used for save button enablement).
class FormFieldChanged extends EmployeeFormEvent {}
