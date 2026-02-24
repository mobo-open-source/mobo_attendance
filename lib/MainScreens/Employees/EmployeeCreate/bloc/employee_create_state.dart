import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

/// Immutable state class for the employee creation/editing form.
///
/// Manages a very large form with personal info, work details, private address,
/// identification, family, visa info, resume lines/skills, attachments, etc.
///
/// All fields are optional or have sensible defaults to allow partial editing.
class EmployeeCreateState extends Equatable {
  final int? employeeId;
  final bool isLoading;
  final bool isSaving;

  // ── Basic employee information ─────────────────────────────────────────────
  final String name;
  final String workEmail;
  final String workPhone;
  final String mobilePhone;
  final String pin;
  final String badge;
  final String? imageBase64;

  // ── Organizational links ───────────────────────────────────────────────────
  final int? departmentId;
  final int? jobId;
  final int? managerId;
  final int? coachId;
  final int? userId;
  final String employeeType;

  // ── Private address & contact ──────────────────────────────────────────────
  final String privateStreet;
  final String privateStreet2;
  final String privateCity;
  final int? privateStateId;
  final int? privateCountryId;
  final String privateEmail;
  final String privatePhone;
  final int? privateBankId;
  final String? privateLang;
  final String kmHomeWork;
  final String privateCarPlate;

  // ── Identification & personal details ──────────────────────────────────────
  final int? countryId;
  final String identificationId;
  final String ssnId;
  final String passportId;
  final String birthday;
  final String? gender;
  final String placeOfBirth;
  final int? countryOfBirthId;
  final String? maritalStatus;
  final String spouseName;
  final String spouseBirthday;
  final String children;

  // ── Education & certificates ───────────────────────────────────────────────
  final String? certificate;
  final String fieldOfStudy;
  final String studySchool;

  // ── Visa & work permit ─────────────────────────────────────────────────────
  final String visaNo;
  final String permitNo;
  final String visaExpire;
  final String workPermitExpire;

  // ── Other relations ────────────────────────────────────────────────────────
  final int? addressId;
  final int? workLocationId;
  final int? expenseManagerId;
  final int? workingHoursId;
  final String? timezone;

  // ── Dropdown / selection lists (loaded from Odoo) ──────────────────────────
  final List<Map<String, dynamic>> users;
  final List<Map<String, dynamic>> employees;
  final List<Map<String, dynamic>> departments;
  final List<Map<String, dynamic>> jobs;
  final List<Map<String, dynamic>> addresses;
  final List<Map<String, dynamic>> locations;
  final List<Map<String, dynamic>> expenses;
  final List<Map<String, dynamic>> workingHours;
  final List<Map<String, dynamic>> timezones;
  final List<Map<String, dynamic>> countries;
  final List<Map<String, dynamic>> states;
  final List<Map<String, dynamic>> languages;
  final List<Map<String, dynamic>> banks;
  final List<Map<String, dynamic>> resumeTypes;
  final List<Map<String, dynamic>> skillTypes;

  // ── Resume / skills data ───────────────────────────────────────────────────
  final List<Map<String, dynamic>> resumeLines;
  final List<Map<String, dynamic>> selectedSkills;

  // ── Feedback & UI state ────────────────────────────────────────────────────
  final String? errorMessage;
  final bool success;

  /// Additional address details (e.g. from selection or lookup)
  final Map<String, dynamic> addressDetails;

  /// Focus node for dropdown fields (helps with keyboard navigation)
  final FocusNode dropdownFocusNode;

  const EmployeeCreateState({
    this.employeeId,
    this.isLoading = true,
    this.isSaving = false,
    this.name = '',
    this.workEmail = '',
    this.workPhone = '',
    this.mobilePhone = '',
    this.pin = '',
    this.badge = '',
    this.imageBase64,
    this.departmentId,
    this.jobId,
    this.managerId,
    this.coachId,
    this.userId,
    this.employeeType = 'employee',
    this.privateStreet = '',
    this.privateStreet2 = '',
    this.privateCity = '',
    this.privateStateId,
    this.privateCountryId,
    this.privateEmail = '',
    this.privatePhone = '',
    this.privateBankId,
    this.privateLang,
    this.kmHomeWork = '0',
    this.privateCarPlate = '',
    this.countryId,
    this.identificationId = '',
    this.ssnId = '',
    this.passportId = '',
    this.birthday = '',
    this.gender,
    this.placeOfBirth = '',
    this.countryOfBirthId,
    this.maritalStatus = 'single',
    this.spouseName = '',
    this.spouseBirthday = '',
    this.children = '',
    this.certificate,
    this.fieldOfStudy = '',
    this.studySchool = '',
    this.visaNo = '',
    this.permitNo = '',
    this.visaExpire = '',
    this.workPermitExpire = '',
    this.addressId,
    this.workLocationId,
    this.expenseManagerId,
    this.workingHoursId,
    this.timezone,
    this.users = const [],
    this.employees = const [],
    this.departments = const [],
    this.jobs = const [],
    this.addresses = const [],
    this.locations = const [],
    this.expenses = const [],
    this.workingHours = const [],
    this.timezones = const [],
    this.countries = const [],
    this.states = const [],
    this.languages = const [],
    this.banks = const [],
    this.resumeTypes = const [],
    this.skillTypes = const [],
    this.resumeLines = const [],
    this.selectedSkills = const [],
    this.errorMessage,
    this.success = false,
    this.addressDetails = const {},
    required this.dropdownFocusNode,
  });

  /// Creates a new state by copying the current one and overriding only
  /// the provided fields.
  EmployeeCreateState copyWith({
    int? employeeId,
    bool? isLoading,
    bool? isSaving,
    String? name,
    String? workEmail,
    String? workPhone,
    String? mobilePhone,
    String? pin,
    String? badge,
    String? imageBase64,
    int? departmentId,
    int? jobId,
    int? managerId,
    int? coachId,
    int? userId,
    String? employeeType,
    String? privateStreet,
    String? privateStreet2,
    String? privateCity,
    int? privateStateId,
    int? privateCountryId,
    String? privateEmail,
    String? privatePhone,
    int? privateBankId,
    String? privateLang,
    String? kmHomeWork,
    String? privateCarPlate,
    int? countryId,
    String? identificationId,
    String? ssnId,
    String? passportId,
    String? birthday,
    String? gender,
    String? placeOfBirth,
    int? countryOfBirthId,
    String? maritalStatus,
    String? spouseName,
    String? spouseBirthday,
    String? children,
    String? certificate,
    String? fieldOfStudy,
    String? studySchool,
    String? visaNo,
    String? permitNo,
    String? visaExpire,
    String? workPermitExpire,
    int? addressId,
    int? workLocationId,
    int? expenseManagerId,
    int? workingHoursId,
    String? timezone,
    List<Map<String, dynamic>>? users,
    List<Map<String, dynamic>>? employees,
    List<Map<String, dynamic>>? departments,
    List<Map<String, dynamic>>? jobs,
    List<Map<String, dynamic>>? addresses,
    List<Map<String, dynamic>>? locations,
    List<Map<String, dynamic>>? expenses,
    List<Map<String, dynamic>>? workingHours,
    List<Map<String, dynamic>>? timezones,
    List<Map<String, dynamic>>? countries,
    List<Map<String, dynamic>>? states,
    List<Map<String, dynamic>>? languages,
    List<Map<String, dynamic>>? banks,
    List<Map<String, dynamic>>? resumeTypes,
    List<Map<String, dynamic>>? skillTypes,
    List<Map<String, dynamic>>? resumeLines,
    List<Map<String, dynamic>>? selectedSkills,
    String? errorMessage,
    bool? success,
    Map<String, dynamic>? addressDetails,
    FocusNode? dropdownFocusNode,
  }) {
    return EmployeeCreateState(
      employeeId: employeeId ?? this.employeeId,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      name: name ?? this.name,
      workEmail: workEmail ?? this.workEmail,
      workPhone: workPhone ?? this.workPhone,
      mobilePhone: mobilePhone ?? this.mobilePhone,
      pin: pin ?? this.pin,
      badge: badge ?? this.badge,
      imageBase64: imageBase64 ?? this.imageBase64,
      departmentId: departmentId ?? this.departmentId,
      jobId: jobId ?? this.jobId,
      managerId: managerId ?? this.managerId,
      coachId: coachId ?? this.coachId,
      userId: userId ?? this.userId,
      employeeType: employeeType ?? this.employeeType,
      privateStreet: privateStreet ?? this.privateStreet,
      privateStreet2: privateStreet2 ?? this.privateStreet2,
      privateCity: privateCity ?? this.privateCity,
      privateStateId: privateStateId ?? this.privateStateId,
      privateCountryId: privateCountryId ?? this.privateCountryId,
      privateEmail: privateEmail ?? this.privateEmail,
      privatePhone: privatePhone ?? this.privatePhone,
      privateBankId: privateBankId ?? this.privateBankId,
      privateLang: privateLang ?? this.privateLang,
      kmHomeWork: kmHomeWork ?? this.kmHomeWork,
      privateCarPlate: privateCarPlate ?? this.privateCarPlate,
      countryId: countryId ?? this.countryId,
      identificationId: identificationId ?? this.identificationId,
      ssnId: ssnId ?? this.ssnId,
      passportId: passportId ?? this.passportId,
      birthday: birthday ?? this.birthday,
      gender: gender ?? this.gender,
      placeOfBirth: placeOfBirth ?? this.placeOfBirth,
      countryOfBirthId: countryOfBirthId ?? this.countryOfBirthId,
      maritalStatus: maritalStatus ?? this.maritalStatus ?? 'single',
      spouseName: spouseName ?? this.spouseName,
      spouseBirthday: spouseBirthday ?? this.spouseBirthday,
      children: children ?? this.children,
      certificate: certificate ?? this.certificate,
      fieldOfStudy: fieldOfStudy ?? this.fieldOfStudy,
      studySchool: studySchool ?? this.studySchool,
      visaNo: visaNo ?? this.visaNo,
      permitNo: permitNo ?? this.permitNo,
      visaExpire: visaExpire ?? this.visaExpire,
      workPermitExpire: workPermitExpire ?? this.workPermitExpire,
      addressId: addressId ?? this.addressId,
      workLocationId: workLocationId ?? this.workLocationId,
      expenseManagerId: expenseManagerId ?? this.expenseManagerId,
      workingHoursId: workingHoursId ?? this.workingHoursId,
      timezone: timezone ?? this.timezone,
      users: users ?? this.users,
      employees: employees ?? this.employees,
      departments: departments ?? this.departments,
      jobs: jobs ?? this.jobs,
      addresses: addresses ?? this.addresses,
      locations: locations ?? this.locations,
      expenses: expenses ?? this.expenses,
      workingHours: workingHours ?? this.workingHours,
      timezones: timezones ?? this.timezones,
      countries: countries ?? this.countries,
      states: states ?? this.states,
      languages: languages ?? this.languages,
      banks: banks ?? this.banks,
      resumeTypes: resumeTypes ?? this.resumeTypes,
      skillTypes: skillTypes ?? this.skillTypes,
      resumeLines: resumeLines ?? this.resumeLines,
      selectedSkills: selectedSkills ?? this.selectedSkills,
      errorMessage: errorMessage,
      success: success ?? this.success,
      addressDetails: addressDetails ?? this.addressDetails,
      dropdownFocusNode: dropdownFocusNode ?? this.dropdownFocusNode,
    );
  }

  @override
  List<Object?> get props => [
    employeeId,
    isLoading,
    isSaving,
    name,
    workEmail,
    workPhone,
    mobilePhone,
    pin,
    badge,
    imageBase64,
    departmentId,
    jobId,
    managerId,
    coachId,
    userId,
    employeeType,
    privateStreet,
    privateStreet2,
    privateCity,
    privateStateId,
    privateCountryId,
    privateEmail,
    privatePhone,
    privateBankId,
    privateLang,
    kmHomeWork,
    privateCarPlate,
    countryId,
    identificationId,
    ssnId,
    passportId,
    birthday,
    gender,
    placeOfBirth,
    countryOfBirthId,
    maritalStatus,
    spouseName,
    spouseBirthday,
    children,
    certificate,
    fieldOfStudy,
    studySchool,
    visaNo,
    permitNo,
    visaExpire,
    workPermitExpire,
    addressId,
    workLocationId,
    expenseManagerId,
    workingHoursId,
    timezone,
    users,
    employees,
    departments,
    jobs,
    addresses,
    locations,
    expenses,
    workingHours,
    timezones,
    countries,
    states,
    languages,
    banks,
    resumeTypes,
    skillTypes,
    resumeLines,
    selectedSkills,
    errorMessage,
    success,
    addressDetails,
    dropdownFocusNode
  ];
}
