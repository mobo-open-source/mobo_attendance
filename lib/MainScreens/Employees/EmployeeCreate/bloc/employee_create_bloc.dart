import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../Rating/review_service.dart';
import '../services/employee_create_service.dart';
import 'employee_create_event.dart';
import 'employee_create_state.dart';

/// Manages the state and business logic for creating or editing an employee record.
///
/// This bloc handles a large, multi-section form with:
/// - Basic info (name, emails, phones, job, department, manager/coach)
/// - Profile photo (gallery pick → base64)
/// - Private address & contact details
/// - Identification, personal info (birthday, gender, marital, family)
/// - Education & certificates
/// - Visa & work permit
/// - Resume lines (experience/education/certificates)
/// - Skills selection
/// - HR settings (employee type, PIN, badge, timezone, working hours)
///
/// Loads dropdown data from Odoo on init, supports version-aware submission,
/// tracks events via ReviewService, and navigates to detail form on success.
class EmployeeCreateBloc
    extends Bloc<EmployeeCreateEvent, EmployeeCreateState> {
  late EmployeeCreateService _service;

  EmployeeCreateBloc({EmployeeCreateService? service})
      : _service = service ?? EmployeeCreateService(),
        super(EmployeeCreateState(dropdownFocusNode: FocusNode())) {
    on<InitializeCreateEmployee>(_onInitialize);
    on<UpdateName>(_onUpdateName);
    on<UpdateWorkEmail>(_onUpdateWorkEmail);
    on<UpdateWorkPhone>(_onUpdateWorkPhone);
    on<UpdateMobilePhone>(_onUpdateMobilePhone);
    on<UpdatePin>(_onUpdatePin);
    on<UpdateBadge>(_onUpdateBadge);
    on<PickImage>(_onPickImage);
    on<UpdateDepartment>(_onUpdateDepartment);
    on<UpdateJob>(_onUpdateJob);
    on<UpdateManager>(_onUpdateManager);
    on<UpdateCoach>(_onUpdateCoach);
    on<UpdateUser>(_onUpdateUser);
    on<UpdateEmployeeType>(_onUpdateEmployeeType);
    on<UpdatePrivateStreet>(_onUpdatePrivateStreet);
    on<UpdatePrivateStreet2>(_onUpdatePrivateStreet2);
    on<UpdatePrivateCity>(_onUpdatePrivateCity);
    on<UpdatePrivateState>(_onUpdatePrivateState);
    on<UpdatePrivateCountry>(_onUpdatePrivateCountry);
    on<UpdatePrivateEmail>(_onUpdatePrivateEmail);
    on<UpdatePrivatePhone>(_onUpdatePrivatePhone);
    on<UpdatePrivateBank>(_onUpdatePrivateBank);
    on<UpdatePrivateLang>(_onUpdatePrivateLang);
    on<UpdateKmHomeWork>(_onUpdateKmHomeWork);
    on<UpdatePrivateCarPlate>(_onUpdatePrivateCarPlate);
    on<UpdateCountry>(_onUpdateCountry);
    on<UpdateIdentificationId>(_onUpdateIdentificationId);
    on<UpdateSsnId>(_onUpdateSsnId);
    on<UpdatePassportId>(_onUpdatePassportId);
    on<UpdateBirthday>(_onUpdateBirthday);
    on<UpdateGender>(_onUpdateGender);
    on<UpdatePlaceOfBirth>(_onUpdatePlaceOfBirth);
    on<UpdateCountryOfBirth>(_onUpdateCountryOfBirth);
    on<UpdateMaritalStatus>(_onUpdateMaritalStatus);
    on<UpdateSpouseName>(_onUpdateSpouseName);
    on<UpdateSpouseBirthday>(_onUpdateSpouseBirthday);
    on<UpdateChildren>(_onUpdateChildren);
    on<UpdateCertificate>(_onUpdateCertificate);
    on<UpdateFieldOfStudy>(_onUpdateFieldOfStudy);
    on<UpdateStudySchool>(_onUpdateStudySchool);
    on<UpdateVisaNo>(_onUpdateVisaNo);
    on<UpdatePermitNo>(_onUpdatePermitNo);
    on<UpdateVisaExpire>(_onUpdateVisaExpire);
    on<UpdateWorkPermitExpire>(_onUpdateWorkPermitExpire);
    on<UpdateAddress>(_onUpdateAddress);
    on<UpdateWorkLocation>(_onUpdateWorkLocation);
    on<UpdateExpenseManager>(_onUpdateExpenseManager);
    on<UpdateWorkingHours>(_onUpdateWorkingHours);
    on<UpdateTimezone>(_onUpdateTimezone);
    on<AddResumeLine>(_onAddResumeLine);
    on<RemoveResumeLine>(_onRemoveResumeLine);
    on<AddSkill>(_onAddSkill);
    on<RemoveSkill>(_onRemoveSkill);
    on<CreateEmployee>(_onCreateEmployee);
    on<ResetForm>(_onResetForm);
  }

  @override
  Future<void> close() {
    // Clean up focus node when bloc is closed
    state.dropdownFocusNode.dispose();
    return super.close();
  }

  /// Initializes the form by loading all required dropdown data from Odoo.
  Future<void> _onInitialize(
    InitializeCreateEmployee event,
    Emitter<EmployeeCreateState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));

    try {
      await _service.initializeClient();

      final users = await _service.loadUsers();
      final employees = await _service.loadManagerOrCoach();

      final departments = await _service.loadDepartment();

      final jobs = await _service.loadJobs();

      final addresses = await _service.loadAddress();
      final locations = await _service.loadLocation();
      final expenses = await _service.loadExpense();
      final workingHours = await _service.loadWorkingHours();
      final timezones = await _service.fetchTimezones();
      final countries = await _service.loadCountryState();
      final states = await _service.loadState(0);
      final languages = await _service.fetchLanguage();
      final banks = await _service.loadBankAccount();
      final resumeTypes = await _service.fetchResumeType();
      final skillTypes = await _service.fetchSkillType();

      emit(
        state.copyWith(
          isLoading: false,
          users: users,
          employees: employees,
          departments: departments,
          jobs: jobs,
          addresses: addresses,
          locations: locations,
          expenses: expenses,
          workingHours: workingHours,
          timezones: timezones,
          countries: countries,
          states: states,
          languages: languages,
          banks: banks,
          resumeTypes: resumeTypes,
          skillTypes: skillTypes,
          addressDetails: {},
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: "Failed to load data: $e",
        ),
      );
    }
  }

  /// Resets the form to initial empty/default state while preserving loaded dropdown lists.
  void _onResetForm(
      ResetForm event,
      Emitter<EmployeeCreateState> emit,
      ) {
    emit(
      EmployeeCreateState(
        dropdownFocusNode: FocusNode(),
        isLoading: false,
        isSaving: false,
        success: false,
        errorMessage: null,
        employeeId: null,
        name: '',
        workEmail: '',
        workPhone: '',
        mobilePhone: '',
        imageBase64: null,
        departmentId: null,
        jobId: null,
        managerId: null,
        coachId: null,
        userId: null,
        employeeType: 'employee',
        pin: '',
        badge: '',
        privateStreet: '',
        privateStreet2: '',
        privateCity: '',
        privateStateId: null,
        privateCountryId: null,
        privateEmail: '',
        privatePhone: '',
        privateBankId: null,
        privateLang: null,
        kmHomeWork: '',
        privateCarPlate: '',
        countryId: null,
        identificationId: '',
        ssnId: '',
        passportId: '',
        birthday: '',
        gender: null,
        placeOfBirth: '',
        countryOfBirthId: null,
        maritalStatus: 'single',
        spouseName: '',
        spouseBirthday: '',
        children: '',
        certificate: null,
        fieldOfStudy: '',
        studySchool: '',
        visaNo: '',
        permitNo: '',
        visaExpire: '',
        workPermitExpire: '',
        addressId: null,
        workLocationId: null,
        expenseManagerId: null,
        workingHoursId: null,
        timezone: null,
        resumeLines: [],
        selectedSkills: [],
        users: state.users,
        employees: state.employees,
        departments: state.departments,
        jobs: state.jobs,
        addresses: state.addresses,
        locations: state.locations,
        expenses: state.expenses,
        workingHours: state.workingHours,
        timezones: state.timezones,
        countries: state.countries,
        states: state.states,
        languages: state.languages,
        banks: state.banks,
        resumeTypes: state.resumeTypes,
        skillTypes: state.skillTypes,
        addressDetails: {},
      ),
    );
  }

  // ── Simple field update handlers ───────────────────────────────────────────

  void _onUpdateName(UpdateName event, Emitter<EmployeeCreateState> emit) {
    emit(state.copyWith(name: event.name));
  }

  void _onUpdateWorkEmail(
    UpdateWorkEmail event,
    Emitter<EmployeeCreateState> emit,
  ) {
    emit(state.copyWith(workEmail: event.email));
  }

  void _onUpdateWorkPhone(
    UpdateWorkPhone event,
    Emitter<EmployeeCreateState> emit,
  ) {
    emit(state.copyWith(workPhone: event.phone));
  }

  void _onUpdateMobilePhone(
    UpdateMobilePhone event,
    Emitter<EmployeeCreateState> emit,
  ) {
    emit(state.copyWith(mobilePhone: event.mobile));
  }

  void _onUpdatePin(UpdatePin event, Emitter<EmployeeCreateState> emit) {
    emit(state.copyWith(pin: event.pin));
  }

  void _onUpdateBadge(UpdateBadge event, Emitter<EmployeeCreateState> emit) {
    emit(state.copyWith(badge: event.badge));
  }

  /// Picks image from gallery and converts to base64 string for preview & upload
  Future<void> _onPickImage(
    PickImage event,
    Emitter<EmployeeCreateState> emit,
  ) async {
    final picker = ImagePicker();
    final xFile = await picker.pickImage(source: ImageSource.gallery);
    if (xFile != null) {
      final bytes = await xFile.readAsBytes();
      final base64 = base64Encode(bytes);
      emit(state.copyWith(imageBase64: base64));
    }
  }

  // ── Organizational field updates ───────────────────────────────────────────

  void _onUpdateDepartment(
    UpdateDepartment event,
    Emitter<EmployeeCreateState> emit,
  ) {
    emit(state.copyWith(departmentId: event.id));
  }

  void _onUpdateJob(UpdateJob event, Emitter<EmployeeCreateState> emit) {
    emit(state.copyWith(jobId: event.id));
  }

  void _onUpdateManager(
    UpdateManager event,
    Emitter<EmployeeCreateState> emit,
  ) {
    emit(state.copyWith(managerId: event.id));
  }

  void _onUpdateCoach(UpdateCoach event, Emitter<EmployeeCreateState> emit) {
    emit(state.copyWith(coachId: event.id));
  }

  void _onUpdateUser(UpdateUser event, Emitter<EmployeeCreateState> emit) {
    emit(state.copyWith(userId: event.id));
  }

  void _onUpdateEmployeeType(
    UpdateEmployeeType event,
    Emitter<EmployeeCreateState> emit,
  ) {
    emit(state.copyWith(employeeType: event.type));
  }

  // ── Private address & contact updates ──────────────────────────────────────

  void _onUpdatePrivateStreet(
    UpdatePrivateStreet event,
    Emitter<EmployeeCreateState> emit,
  ) {
    emit(state.copyWith(privateStreet: event.street));
  }

  void _onUpdatePrivateStreet2(
    UpdatePrivateStreet2 event,
    Emitter<EmployeeCreateState> emit,
  ) {
    emit(state.copyWith(privateStreet2: event.street2));
  }

  void _onUpdatePrivateCity(
    UpdatePrivateCity event,
    Emitter<EmployeeCreateState> emit,
  ) {
    emit(state.copyWith(privateCity: event.city));
  }

  void _onUpdatePrivateState(
    UpdatePrivateState event,
    Emitter<EmployeeCreateState> emit,
  ) {
    emit(state.copyWith(privateStateId: event.id));
  }

  /// Updates private country and reloads states for that country
  void _onUpdatePrivateCountry(
    UpdatePrivateCountry event,
    Emitter<EmployeeCreateState> emit,
  ) async {
    emit(state.copyWith(privateCountryId: event.id));
    if (event.id != null) {
      final newStates = await _service.loadState(event.id!);
      emit(state.copyWith(states: newStates));
    }
  }

  void _onUpdatePrivateEmail(
    UpdatePrivateEmail event,
    Emitter<EmployeeCreateState> emit,
  ) {
    emit(state.copyWith(privateEmail: event.email));
  }

  void _onUpdatePrivatePhone(
    UpdatePrivatePhone event,
    Emitter<EmployeeCreateState> emit,
  ) {
    emit(state.copyWith(privatePhone: event.phone));
  }

  void _onUpdatePrivateBank(
    UpdatePrivateBank event,
    Emitter<EmployeeCreateState> emit,
  ) {
    emit(state.copyWith(privateBankId: event.id));
  }

  void _onUpdatePrivateLang(
    UpdatePrivateLang event,
    Emitter<EmployeeCreateState> emit,
  ) {
    emit(state.copyWith(privateLang: event.langCode));
  }

  void _onUpdateKmHomeWork(
    UpdateKmHomeWork event,
    Emitter<EmployeeCreateState> emit,
  ) {
    emit(state.copyWith(kmHomeWork: event.km));
  }

  void _onUpdatePrivateCarPlate(
    UpdatePrivateCarPlate event,
    Emitter<EmployeeCreateState> emit,
  ) {
    emit(state.copyWith(privateCarPlate: event.plate));
  }

  // ── Identification & personal updates ──────────────────────────────────────

  void _onUpdateCountry(
    UpdateCountry event,
    Emitter<EmployeeCreateState> emit,
  ) {
    emit(state.copyWith(countryId: event.id));
  }

  void _onUpdateIdentificationId(
    UpdateIdentificationId event,
    Emitter<EmployeeCreateState> emit,
  ) {
    emit(state.copyWith(identificationId: event.idNo));
  }

  void _onUpdateSsnId(UpdateSsnId event, Emitter<EmployeeCreateState> emit) {
    emit(state.copyWith(ssnId: event.ssn));
  }

  void _onUpdatePassportId(
    UpdatePassportId event,
    Emitter<EmployeeCreateState> emit,
  ) {
    emit(state.copyWith(passportId: event.passport));
  }

  void _onUpdateBirthday(
    UpdateBirthday event,
    Emitter<EmployeeCreateState> emit,
  ) {
    emit(state.copyWith(birthday: event.date));
  }

  void _onUpdateGender(UpdateGender event, Emitter<EmployeeCreateState> emit) {
    emit(state.copyWith(gender: event.gender));
  }

  void _onUpdatePlaceOfBirth(
    UpdatePlaceOfBirth event,
    Emitter<EmployeeCreateState> emit,
  ) {
    emit(state.copyWith(placeOfBirth: event.place));
  }

  void _onUpdateCountryOfBirth(
    UpdateCountryOfBirth event,
    Emitter<EmployeeCreateState> emit,
  ) {
    emit(state.copyWith(countryOfBirthId: event.id));
  }

  void _onUpdateMaritalStatus(
    UpdateMaritalStatus event,
    Emitter<EmployeeCreateState> emit,
  ) {
    emit(state.copyWith(maritalStatus: event.status));
  }

  void _onUpdateSpouseName(
    UpdateSpouseName event,
    Emitter<EmployeeCreateState> emit,
  ) {
    emit(state.copyWith(spouseName: event.name));
  }

  void _onUpdateSpouseBirthday(
    UpdateSpouseBirthday event,
    Emitter<EmployeeCreateState> emit,
  ) {
    emit(state.copyWith(spouseBirthday: event.date));
  }

  void _onUpdateChildren(
    UpdateChildren event,
    Emitter<EmployeeCreateState> emit,
  ) {
    emit(state.copyWith(children: event.count));
  }

  void _onUpdateCertificate(
    UpdateCertificate event,
    Emitter<EmployeeCreateState> emit,
  ) {
    emit(state.copyWith(certificate: event.level));
  }

  void _onUpdateFieldOfStudy(
    UpdateFieldOfStudy event,
    Emitter<EmployeeCreateState> emit,
  ) {
    emit(state.copyWith(fieldOfStudy: event.field));
  }

  void _onUpdateStudySchool(
    UpdateStudySchool event,
    Emitter<EmployeeCreateState> emit,
  ) {
    emit(state.copyWith(studySchool: event.school));
  }

  // ── Visa & permit updates ──────────────────────────────────────────────────

  void _onUpdateVisaNo(UpdateVisaNo event, Emitter<EmployeeCreateState> emit) {
    emit(state.copyWith(visaNo: event.visa));
  }

  void _onUpdatePermitNo(
    UpdatePermitNo event,
    Emitter<EmployeeCreateState> emit,
  ) {
    emit(state.copyWith(permitNo: event.permit));
  }

  void _onUpdateVisaExpire(
    UpdateVisaExpire event,
    Emitter<EmployeeCreateState> emit,
  ) {
    emit(state.copyWith(visaExpire: event.date));
  }

  void _onUpdateWorkPermitExpire(
    UpdateWorkPermitExpire event,
    Emitter<EmployeeCreateState> emit,
  ) {
    emit(state.copyWith(workPermitExpire: event.date));
  }

  // ── Work location & settings updates ───────────────────────────────────────

  Future<void> _onUpdateAddress(
    UpdateAddress event,
    Emitter<EmployeeCreateState> emit,
  ) async {
    emit(state.copyWith(addressId: event.id));

    if (event.id != null) {
      try {
        final fullAddress = await _service.loadFullAddress(event.id!);
        emit(state.copyWith(addressDetails: fullAddress));
      } catch (e) {
        emit(state.copyWith(addressDetails: {}));
      }
    } else {
      emit(state.copyWith(addressDetails: {}));
    }
  }

  void _onUpdateWorkLocation(
    UpdateWorkLocation event,
    Emitter<EmployeeCreateState> emit,
  ) {
    emit(state.copyWith(workLocationId: event.id));
  }

  void _onUpdateExpenseManager(
    UpdateExpenseManager event,
    Emitter<EmployeeCreateState> emit,
  ) {
    emit(state.copyWith(expenseManagerId: event.id));
  }

  void _onUpdateWorkingHours(
    UpdateWorkingHours event,
    Emitter<EmployeeCreateState> emit,
  ) {
    emit(state.copyWith(workingHoursId: event.id));
  }

  void _onUpdateTimezone(
    UpdateTimezone event,
    Emitter<EmployeeCreateState> emit,
  ) {
    emit(state.copyWith(timezone: event.tz));
  }

  // ── Resume & skills management ─────────────────────────────────────────────

  void _onAddResumeLine(
    AddResumeLine event,
    Emitter<EmployeeCreateState> emit,
  ) {
    final newLines = List<Map<String, dynamic>>.from(state.resumeLines)
      ..add(event.line);
    emit(state.copyWith(resumeLines: newLines));
  }

  void _onRemoveResumeLine(
    RemoveResumeLine event,
    Emitter<EmployeeCreateState> emit,
  ) {
    final newLines = List<Map<String, dynamic>>.from(state.resumeLines)
      ..removeAt(event.index);
    emit(state.copyWith(resumeLines: newLines));
  }

  void _onAddSkill(AddSkill event, Emitter<EmployeeCreateState> emit) {
    final newSkills = List<Map<String, dynamic>>.from(state.selectedSkills)
      ..add(event.skill);
    emit(state.copyWith(selectedSkills: newSkills));
  }

  void _onRemoveSkill(RemoveSkill event, Emitter<EmployeeCreateState> emit) {
    final newSkills = List<Map<String, dynamic>>.from(state.selectedSkills)
      ..removeAt(event.index);
    emit(state.copyWith(selectedSkills: newSkills));
  }

  /// Extracts major Odoo version from server_version string
  int parseMajorVersion(String serverVersion) {
    final match = RegExp(r'\d+').firstMatch(serverVersion);
    if (match != null) {
      return int.tryParse(match.group(0)!) ?? 0;
    }
    return 0;
  }

  /// Creates or updates the employee record in Odoo.
  ///
  /// Prepares a large payload with all form data.
  /// Handles version differences (Odoo 19+ field name changes).
  /// Includes resume lines and employee skills as commands.
  /// Tracks success/failure via ReviewService.
  Future<void> _onCreateEmployee(
    CreateEmployee event,
    Emitter<EmployeeCreateState> emit,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final String version = prefs.getString('serverVersion') ?? '0';
    final int majorVersion = parseMajorVersion(version);

    if (state.name.trim().isEmpty) {
      emit(state.copyWith(errorMessage: "Name is required"));
      return;
    }

    emit(state.copyWith(isSaving: true, errorMessage: null));

    try {
      final data = {
        "name": state.name.trim(),
        "work_email": state.workEmail.trim().isEmpty
            ? false
            : state.workEmail.trim(),
        "work_phone": state.workPhone.trim().isEmpty
            ? false
            : state.workPhone.trim(),
        "mobile_phone": state.mobilePhone.trim().isEmpty
            ? false
            : state.mobilePhone.trim(),
        "department_id": state.departmentId ?? false,
        "job_id": state.jobId ?? false,
        "parent_id": state.managerId ?? false,
        "coach_id": state.coachId ?? false,
        "user_id": state.userId ?? false,
        "employee_type": state.employeeType,
        "pin": state.pin.trim().isEmpty ? false : state.pin.trim(),
        "barcode": state.badge.trim().isEmpty ? false : state.badge.trim(),
        "image_1920": state.imageBase64 ?? false,
        'private_street': state.privateStreet.trim().isEmpty
            ? false
            : state.privateStreet.trim(),
        'private_street2': state.privateStreet2.trim().isEmpty
            ? false
            : state.privateStreet2.trim(),
        'private_city': state.privateCity.trim().isEmpty
            ? false
            : state.privateCity.trim(),
        'private_state_id': state.privateStateId ?? false,
        'private_country_id': state.privateCountryId ?? false,
        'private_email': state.privateEmail.trim().isEmpty
            ? false
            : state.privateEmail.trim(),
        'private_phone': state.privatePhone.trim().isEmpty
            ? false
            : state.privatePhone.trim(),
        'lang': state.privateLang ?? false,
        'km_home_work': state.kmHomeWork,
        'private_car_plate': state.privateCarPlate.trim().isEmpty
            ? false
            : state.privateCarPlate.trim(),
        'country_id': state.countryId ?? false,
        'identification_id': state.identificationId.trim().isEmpty
            ? false
            : state.identificationId.trim(),
        'ssnid': state.ssnId.trim().isEmpty ? false : state.ssnId.trim(),
        'passport_id': state.passportId.trim().isEmpty
            ? false
            : state.passportId.trim(),
        'birthday': state.birthday.trim().isEmpty
            ? false
            : state.birthday.trim(),
        'place_of_birth': state.placeOfBirth.trim().isEmpty
            ? false
            : state.placeOfBirth.trim(),
        'country_of_birth': state.countryOfBirthId ?? false,
        'marital': state.maritalStatus ?? false,
        'spouse_complete_name': state.spouseName.trim().isEmpty
            ? false
            : state.spouseName.trim(),
        'spouse_birthdate': state.spouseBirthday.trim().isEmpty
            ? false
            : state.spouseBirthday.trim(),
        'children': state.children.trim().isEmpty
            ? false
            : state.children.trim(),
        'certificate': state.certificate ?? false,
        'study_field': state.fieldOfStudy.trim().isEmpty
            ? false
            : state.fieldOfStudy.trim(),
        'study_school': state.studySchool.trim().isEmpty
            ? false
            : state.studySchool.trim(),
        'visa_no': state.visaNo.trim().isEmpty ? false : state.visaNo.trim(),
        'permit_no': state.permitNo.trim().isEmpty
            ? false
            : state.permitNo.trim(),
        'visa_expire': state.visaExpire.trim().isEmpty
            ? false
            : state.visaExpire.trim(),
        'work_permit_expiration_date': state.workPermitExpire.trim().isEmpty
            ? false
            : state.workPermitExpire.trim(),
        'address_id': state.addressId ?? false,
        'work_location_id': state.workLocationId ?? false,
        'resource_calendar_id': state.workingHoursId ?? false,
        'tz': state.timezone ?? false,
      };

      // Version-specific field name adjustments
      if (majorVersion >= 19) {
        data['primary_bank_account_id'] = state.privateBankId ?? false;
        data['sex'] = state.gender ?? false;
      } else {
        data['bank_account_id'] = state.privateBankId ?? false;
        data['gender'] = state.gender ?? false;
      }

      // Resume lines as command (create new lines)
      final resumeLine = {
        "resume_line_ids": state.resumeLines
            .map(
              (line) => ({
                "name": line["name"],
                "line_type_id": line["line_type_id"],
                "date_start": line["date_start"],
                "date_end": line["date_end"],
                "description": line["description"],
              }),
            )
            .toList(),
      };

      // Employee skills as command
      final skillLine = {
        "employee_skills": state.selectedSkills
            .map(
              (s) => ({
                "skill_id": s["skill_id"],
                "skill_level_id": s["skill_level_id"],
                "skill_type_id": s["skill_type_id"],
              }),
            )
            .toList(),
      };

      final response = await _service.createEmployeeDetails(
        data,
        resumeLine,
        skillLine,
      );

      if (response['success'] == true) {
        emit(
          state.copyWith(
            success: true,
            isSaving: false,
            employeeId: response['employee_id'],
          ),
        );
        ReviewService().trackSignificantEvent();

      } else {
        String errorMsg = "Failed to create employee";

        final error = response['error'];

        if (error is String) {
          errorMsg = error;
        } else if (error is Map && error['message'] is String) {
          errorMsg = error['message'];
        }

        emit(state.copyWith(errorMessage: errorMsg, isSaving: false));
      }
    } catch (e) {
      emit(state.copyWith(errorMessage: "Something went wrong, please try again later", isSaving: false));
    }
  }
}
