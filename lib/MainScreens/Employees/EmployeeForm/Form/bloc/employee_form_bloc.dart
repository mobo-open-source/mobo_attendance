import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../services/employee_form_service.dart';

part 'employee_form_event.dart';

part 'employee_form_state.dart';

/// Manages the state and business logic for viewing and editing a single employee's detailed information.
///
/// Features:
/// - Loading employee data + related dropdown lists (jobs, departments, users, resume types, skill types)
/// - View vs Edit mode toggling
/// - Real-time form field updates (name, job, department, emails, phones, type, PIN, badge, profile image)
/// - Profile image upload (gallery → base64)
/// - Resume lines CRUD (add/edit/delete)
/// - Skills CRUD (add/edit/delete)
/// - Badge auto-generation
/// - Permission-aware editing (canManageSkills)
/// - Success/error messaging
/// - Preserves dropdown lists across reloads
class EmployeeFormBloc extends Bloc<EmployeeFormEvent, EmployeeFormState> {
  late EmployeeFormService _service;

  EmployeeFormBloc({EmployeeFormService? service})
      : _service = service ?? EmployeeFormService(),
        super(EmployeeInitial(dropdownFocusNode: FocusNode())) {
    on<LoadEmployee>(_onLoadEmployee);
    on<LoadEmployeeDetails>(_onLoadEmployeeDetails);
    on<ToggleEditMode>(_onToggleEditMode);
    on<CancelEdit>(_onCancelEdit);
    on<UpdateName>(_onUpdateName);
    on<UpdateJob>(_onUpdateJob);
    on<UpdateDepartment>(_onUpdateDepartment);
    on<UpdateManager>(_onUpdateManager);
    on<UpdateCoach>(_onUpdateCoach);
    on<UpdateWorkEmail>(_onUpdateWorkEmail);
    on<UpdateWorkPhone>(_onUpdateWorkPhone);
    on<UpdateMobilePhone>(_onUpdateMobilePhone);
    on<UpdateEmployeeType>(_onUpdateEmployeeType);
    on<UpdateRelatedUser>(_onUpdateRelatedUser);
    on<UpdatePin>(_onUpdatePin);
    on<UpdateBadge>(_onUpdateBadge);
    on<UpdateProfileImage>(_onUpdateProfileImage);
    on<SaveEmployee>(_onSaveEmployee);
    on<GenerateBadge>(_onGenerateBadge);
    on<AddResumeLine>(_onAddResumeLine);
    on<UpdateResumeLine>(_onUpdateResumeLine);
    on<DeleteResumeLine>(_onDeleteResumeLine);
    on<AddSkill>(_onAddSkill);
    on<UpdateSkill>(_onUpdateSkill);
    on<DeleteSkill>(_onDeleteSkill);
    // Generic change detector (marks form as dirty)
    on<FormFieldChanged>((event, emit) {
      emit(state.copyWith());
    });

  }

  @override
  Future<void> close() {
    // Clean up focus node when bloc is disposed
    state.dropdownFocusNode.dispose();
    return super.close();
  }

  // ── Safe value parsers (handle Odoo quirks: false, null, lists, etc.) ──────

  /// Safely extracts nullable ID from Odoo many2one field
  int? safeId(dynamic v) {
    if (v == null || v == false) return null;
    if (v is int) return v;
    if (v is List && v.isNotEmpty && v.first is int) return v.first;
    return null;
  }

  /// Safely extracts string value (handles null/false/'N/A')
  String safeString(dynamic v) {
    if (v == null || v == false) return '';
    if (v is String && v.toLowerCase() == 'n/a') return '';
    return v.toString();
  }

  /// Safely converts value to boolean (handles Odoo false/0/'false')
  bool safeBool(dynamic v, {bool defaultValue = false}) {
    if (v == null || v == false) return defaultValue;
    if (v is bool) return v;
    if (v is int) return v == 1;
    if (v is String) return v.toLowerCase() == 'true';
    return defaultValue;
  }

  // ── Loading & Initialization ──────────────────────────────────────────────

  /// Loads core employee data and initializes controllers
  Future<void> _onLoadEmployee(
    LoadEmployee event,
    Emitter<EmployeeFormState> emit,
  ) async {
    // Preserve dropdown lists to avoid reloading on every refresh
    final preservedJobList = state.jobList;
    final preservedDepartmentList = state.departmentList;
    final preservedManagerCoachList = state.managerCoachList;
    final preservedUserList = state.userList;
    final preservedResumeTypeList = state.resumeTypeList;
    final preservedSkillTypeList = state.skillTypeList;
    final preservedHasPermission = state.hasEditPermission;

    emit(state.copyWith(
      isLoading: true,

      clearMessage: true,

      name: '',
      jobIdIsNull: true,
      departmentIdIsNull: true,
      managerIdIsNull: true,
      coachIdIsNull: true,
      relatedUserIdIsNull: true,
      employeeType: '',
      workEmail: '',
      workPhone: '',
      mobilePhone: '',
      pin: '',
      badge: '',
      profileImageBase64: null,
      employeeDetails: null,

      jobList: preservedJobList,
      departmentList: preservedDepartmentList,
      managerCoachList: preservedManagerCoachList,
      userList: preservedUserList,
      resumeTypeList: preservedResumeTypeList,
      skillTypeList: preservedSkillTypeList,
      hasEditPermission: preservedHasPermission,
    ));

    try {
      await _service.initializeClient();
      final hasPermission = await _service.canManageSkills();
      final details =  await _service.loadEmployeeDetails(event.employeeId);

      if (details == null) {
        emit(
          state.copyWith(isLoading: false, errorMessage: "Employee not found"),
        );
        return;
      }

      // Sync controllers with loaded data
      state.nameController.text = safeString(details['name']);
      state.emailController.text = safeString(details['work_email']);
      state.workPhoneController.text = safeString(details['work_phone']);
      state.mobilePhoneController.text = safeString(details['mobile_phone']);
      state.pinController.text = safeString(details['pin']);
      state.badgeController.text = safeString(details['barcode']);

      emit(
        state.copyWith(
          isLoading: false,

          hasEditPermission: hasPermission,
          employeeDetails: details,

          jobList: preservedJobList,
          departmentList: preservedDepartmentList,
          managerCoachList: preservedManagerCoachList,
          userList: preservedUserList,
          resumeTypeList: preservedResumeTypeList,
          skillTypeList: preservedSkillTypeList,

          name: safeString(details['name']),
          jobId: safeId(details['job_id']),
          departmentId: safeId(details['department_id']),
          managerId: safeId(details['parent_id']),
          coachId: safeId(details['coach_id']),
          relatedUserId: safeId(details['user_id']),

          workEmail: safeString(details['work_email']),
          workPhone: safeString(details['work_phone']),
          mobilePhone: safeString(details['mobile_phone']),

          employeeType: safeString(details['employee_type']),
          pin: safeString(details['pin']),
          badge: safeString(details['barcode']),

          profileImageBase64: details['image_1920'] == false
              ? null
              : details['image_1920'],
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isLoading: false,

          errorMessage: "Something went wrong, Please try again later.",
          jobList: preservedJobList,
          departmentList: preservedDepartmentList,
          managerCoachList: preservedManagerCoachList,
          userList: preservedUserList,
          resumeTypeList: preservedResumeTypeList,
          skillTypeList: preservedSkillTypeList,
          hasEditPermission: preservedHasPermission,
        ),
      );
    }
  }

  /// Loads dropdown lists (jobs, departments, users, resume types, skill types)
  Future<void> _onLoadEmployeeDetails(
      LoadEmployeeDetails event,
      Emitter<EmployeeFormState> emit,
      ) async {
    emit(state.copyWith(isLoading: true, clearMessage: true));

    try {
      await _service.initializeClient();
      final hasPermission = await _service.canManageSkills();

      final results = await Future.wait([
        _service.loadJobs(),
        _service.loadDepartment(),
        _service.loadManagerOrCoach(),
        _service.loadUsers(),
        _service.fetchResumeType(),
        _service.fetchSkillType(),
      ]);

      final jobList        = results[0] as List<Map<String, dynamic>>;
      final departmentList = results[1] as List<Map<String, dynamic>>;
      final managerList    = results[2] as List<Map<String, dynamic>>;
      final userList       = results[3] as List<Map<String, dynamic>>;
      final resumeTypeList = results[4] as List<Map<String, dynamic>>;
      final skillTypeList  = results[5] as List<Map<String, dynamic>>;

      emit(
        state.copyWith(
          hasEditPermission: hasPermission,
          jobList: jobList,
          departmentList: departmentList,
          managerCoachList: managerList,
          userList: userList,
          resumeTypeList: resumeTypeList,
          skillTypeList: skillTypeList,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: "Something went wrong, Please try again later.",
        ),
      );
    }
  }

  // ── Edit Mode Control ─────────────────────────────────────────────────────

  void _onToggleEditMode(
    ToggleEditMode event,
    Emitter<EmployeeFormState> emit,
  ) {
    emit(state.copyWith(isEditing: true));
  }

  void _onCancelEdit(CancelEdit event, Emitter<EmployeeFormState> emit) {
    emit(state.copyWith(isEditing: false));
  }

  // ── Simple field update handlers ──────────────────────────────────────────

  void _onUpdateName(UpdateName event, Emitter<EmployeeFormState> emit) =>
      emit(state.copyWith(name: event.name));

  void _onUpdateJob(UpdateJob event, Emitter<EmployeeFormState> emit) =>
      emit(state.copyWith(jobId: event.jobId));

  void _onUpdateDepartment(
    UpdateDepartment event,
    Emitter<EmployeeFormState> emit,
  ) => emit(state.copyWith(departmentId: event.departmentId));

  void _onUpdateManager(UpdateManager event, Emitter<EmployeeFormState> emit) =>
      emit(state.copyWith(managerId: event.managerId));

  void _onUpdateCoach(UpdateCoach event, Emitter<EmployeeFormState> emit) =>
      emit(state.copyWith(coachId: event.coachId));

  void _onUpdateWorkEmail(
    UpdateWorkEmail event,
    Emitter<EmployeeFormState> emit,
  ) => emit(state.copyWith(workEmail: event.email));

  void _onUpdateWorkPhone(
    UpdateWorkPhone event,
    Emitter<EmployeeFormState> emit,
  ) => emit(state.copyWith(workPhone: event.phone));

  void _onUpdateMobilePhone(
    UpdateMobilePhone event,
    Emitter<EmployeeFormState> emit,
  ) => emit(state.copyWith(mobilePhone: event.mobile));

  void _onUpdateEmployeeType(
    UpdateEmployeeType event,
    Emitter<EmployeeFormState> emit,
  ) => emit(state.copyWith(employeeType: event.type));

  void _onUpdateRelatedUser(
    UpdateRelatedUser event,
    Emitter<EmployeeFormState> emit,
  ) => emit(state.copyWith(relatedUserId: event.userId));

  void _onUpdatePin(UpdatePin event, Emitter<EmployeeFormState> emit) =>
      emit(state.copyWith(pin: event.pin));

  void _onUpdateBadge(UpdateBadge event, Emitter<EmployeeFormState> emit) =>
      emit(state.copyWith(badge: event.badge));

  void _onUpdateProfileImage(
    UpdateProfileImage event,
    Emitter<EmployeeFormState> emit,
  ) => emit(state.copyWith(profileImageBase64: event.base64Image));

  /// Extracts major Odoo version from server_version string (used for field compatibility)
  int parseMajorVersion(String serverVersion) {
    final match = RegExp(r'\d+').firstMatch(serverVersion);
    if (match != null) {
      return int.tryParse(match.group(0)!) ?? 0;
    }
    return 0;
  }

  // ── Save / Generate Badge ─────────────────────────────────────────────────

  /// Saves updated employee fields to Odoo
  Future<void> _onSaveEmployee(
    SaveEmployee event,
    Emitter<EmployeeFormState> emit,
  ) async {
    emit(state.copyWith(isSaving: true, clearMessage: true));

    try {
      await _service.initializeClient();

      final data = {
        'name': state.nameController.text,
        'job_id': state.jobId,
        'department_id': state.departmentId,
        'work_email': state.emailController.text,
        'work_phone': state.workPhoneController.text,
        'mobile_phone': state.mobilePhoneController.text,
        'parent_id': state.managerId,
        'coach_id': state.coachId,
        'employee_type': state.employeeType,
        'user_id': state.relatedUserId,
        'image_1920': state.profileImageBase64,
        if (state.pinController.text != 'N/A') 'pin': state.pinController.text,
        'barcode': state.badgeController.text,
      };

      final response = await _service.updateHrEmployee(
        state.employeeDetails!['id'],
        data,
      );

      if (response['success'] == true) {
        final updated = await _service.loadEmployeeDetails(
          state.employeeDetails!['id'],
        );
        emit(
          state.copyWith(
            isSaving: false,
            isEditing: false,
            employeeDetails: updated,
            profileImageBase64: updated?['image_1920'],
            successMessage: "Employee details updated successfully",
          ),
        );

      } else {
        emit(
          state.copyWith(
            isSaving: false,
            isEditing: false,
            warningMessage: response['error'] ?? "Update failed",
          ),
        );
      }
    } catch (e) {
      emit(
        state.copyWith(
          isSaving: false,
          errorMessage: "Failed to update, Please try again later.",
        ),
      );
    }
  }

  /// Generates a new badge number for the employee
  Future<void> _onGenerateBadge(
    GenerateBadge event,
    Emitter<EmployeeFormState> emit,
  ) async {
    emit(state.copyWith(isSaving: true, clearMessage: true));

    try {
      await _service.initializeClient();
      final error = await _service.generateBadge(state.employeeDetails!['id']);
      if (error == null) {
        final updated = await _service.loadEmployeeDetails(
          state.employeeDetails!['id'],
        );
        state.badgeController.text = safeString(updated['barcode']);
        emit(
          state.copyWith(
            isSaving: false,
            employeeDetails: updated,
            successMessage: "Badge generated successfully",
          ),
        );
      } else {
        emit(state.copyWith(errorMessage: error));
      }
    } catch (e) {
      emit(
        state.copyWith(
          isSaving: false,
          errorMessage: "Failed to generate badge",
        ),
      );
    }
  }

  // ── Resume Lines CRUD ─────────────────────────────────────────────────────

  Future<void> _onAddResumeLine(
    AddResumeLine event,
    Emitter<EmployeeFormState> emit,
  ) async {
    emit(state.copyWith(clearMessage: true));

    try {
      await _service.initializeClient();
      final error = await _service.addResumeLine(event.data);
      if (error == null) {
        final updated = await _service.loadEmployeeDetails(
          state.employeeDetails!['id'],
        );
        emit(
          state.copyWith(
            employeeDetails: updated,
            successMessage: "Resume line added successfully",
          ),
        );
      } else {
        emit(state.copyWith(errorMessage: error));
      }
    } catch (e) {
      emit(
        state.copyWith(
          errorMessage: "Failed to add resume line, Please try again later.",
        ),
      );
    }
  }

  Future<void> _onUpdateResumeLine(
    UpdateResumeLine event,
    Emitter<EmployeeFormState> emit,
  ) async {
    emit(state.copyWith(clearMessage: true));

    try {
      await _service.initializeClient();
      final error = await _service.updateResumeLine(event.lineId, event.data);
      if (error == null) {
        final updated = await _service.loadEmployeeDetails(
          state.employeeDetails!['id'],
        );

        emit(state.copyWith(employeeDetails: updated));

        emit(
          state.copyWith(successMessage: "Resume line updated successfully"),
        );
      } else {
        emit(state.copyWith(errorMessage: error));
      }
    } catch (e) {
      emit(
        state.copyWith(
          errorMessage: "Failed to update resume line, Please try again later",
        ),
      );
    }
  }

  Future<void> _onDeleteResumeLine(
    DeleteResumeLine event,
    Emitter<EmployeeFormState> emit,
  ) async {
    emit(state.copyWith(clearMessage: true));

    try {
      await _service.initializeClient();
      final error = await _service.deleteResumeLine(event.lineId);
      if (error == null) {
        final updated = await _service.loadEmployeeDetails(
          state.employeeDetails!['id'],
        );
        emit(state.copyWith(employeeDetails: updated));
        emit(
          state.copyWith(successMessage: "Resume line deleted successfully"),
        );
      } else {
        emit(state.copyWith(errorMessage: error));
      }
    } catch (e) {
      emit(
        state.copyWith(
          errorMessage: "Failed to delete resume line, Please try again later.",
        ),
      );
    }
  }

  // ── Skills CRUD ────────────────────────────────────────────────────────────

  Future<void> _onAddSkill(
    AddSkill event,
    Emitter<EmployeeFormState> emit,
  ) async {
    emit(state.copyWith(clearMessage: true));

    try {
      await _service.initializeClient();
      final error = await _service.addEmployeeSkill(event.data);
      if (error == null) {
        final updated = await _service.loadEmployeeDetails(
          state.employeeDetails!['id'],
        );
        emit(state.copyWith(employeeDetails: updated));
        emit(state.copyWith(successMessage: "Skill added successfully"));
      } else {
        emit(state.copyWith(errorMessage: error));
      }
    } catch (e) {
      emit(
        state.copyWith(
          errorMessage: "Failed to add skill, Please try again later.",
        ),
      );
    }
  }

  Future<void> _onUpdateSkill(
    UpdateSkill event,
    Emitter<EmployeeFormState> emit,
  ) async {
    emit(state.copyWith(clearMessage: true));

    try {
      await _service.initializeClient();
      final error = await _service.updateEmployeeSkill(
        event.skillId,
        event.data,
      );
      if (error == null) {
        final updated = await _service.loadEmployeeDetails(
          state.employeeDetails!['id'],
        );
        emit(state.copyWith(employeeDetails: updated));
        emit(state.copyWith(successMessage: "Skill updated successfully"));
      } else {
        emit(state.copyWith(errorMessage: error));
      }
    } catch (e) {
      emit(
        state.copyWith(
          errorMessage: "Failed to update skill, Please try again later.",
        ),
      );
    }
  }

  Future<void> _onDeleteSkill(
    DeleteSkill event,
    Emitter<EmployeeFormState> emit,
  ) async {
    emit(state.copyWith(clearMessage: true));

    try {
      await _service.initializeClient();
      final error = await _service.deleteEmployeeSkill(event.skillId);
      if (error == null) {
        final updated = await _service.loadEmployeeDetails(
          state.employeeDetails!['id'],
        );
        emit(state.copyWith(employeeDetails: updated));
        emit(state.copyWith(successMessage: "Skill deleted successfully"));
      } else {
        emit(state.copyWith(errorMessage: error));
      }
    } catch (e) {
      emit(
        state.copyWith(
          errorMessage: "Failed to delete skill, Please try again later.",
        ),
      );
    }
  }
}
