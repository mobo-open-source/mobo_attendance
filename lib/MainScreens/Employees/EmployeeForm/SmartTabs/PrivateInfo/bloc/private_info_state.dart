import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Immutable state class for [PrivateInfoBloc].
///
/// Holds:
/// - Loading / editing / saving flags
/// - UI feedback flags (`showError`, `showWarning`, `showSuccess`) + messages
/// - Loaded employee private data (`employeeDetails`)
/// - Supporting dropdown lists (countries, states, banks, languages)
/// - Work permit file preview bytes (base64 decoded)
/// - Selected IDs/keys for dropdowns (many2one and selection fields)
/// - Text controllers for all editable fields (address, contact, IDs, dates, etc.)
/// - Shared focus node for dropdowns (keyboard navigation)
///
/// Uses `copyWith` pattern with special `isXxx` flags to explicitly clear
/// nullable selection fields (e.g. `isPrivateCountry: true` → `selectedPrivateCountryId = null`).
///
/// Equality override compares only meaningful fields (helps bloc avoid unnecessary rebuilds).
class PrivateInfoState {
  final bool isLoading;
  final bool isEditing;
  final bool isSaving;
  final bool showError;
  final bool showWarning;
  final bool showSuccess;

  final Map<String, dynamic>? employeeDetails;
  final List<Map<String, dynamic>> countries;
  final List<Map<String, dynamic>> states;
  final List<Map<String, dynamic>> banks;
  final List<Map<String, dynamic>> languages;
  final Uint8List? workPermitBytes;
  final String? errorMessage;
  final String? warningMessage;
  final String? successMessage;

  /// Shared focus node for all dropdowns (helps with keyboard navigation)
  final FocusNode dropdownFocusNode;

  // ── Selected values for dropdowns / selections ────────────────────────────

  final int? selectedPrivateCountryId;
  final int? selectedPrivateStateId;
  final int? selectedPrivateBankId;
  final String? selectedPrivateLangId;
  final int? selectedCountryId;
  final int? selectedBirthCountryId;
  final String? selectedGender;
  final String? selectedMarital;
  final String? selectedCertificate;

  // ── Text controllers (synced with UI inputs) ──────────────────────────────

  final TextEditingController privateStreetController;
  final TextEditingController privateStreet2Controller;
  final TextEditingController privateCityController;
  final TextEditingController privateEmailController;
  final TextEditingController privatePhoneController;
  final TextEditingController kmHomeWorkController;
  final TextEditingController privateCarPlateController;
  final TextEditingController identificationIdController;
  final TextEditingController ssnIdController;
  final TextEditingController passportIdController;
  final TextEditingController birthdayController;
  final TextEditingController placeOfBirthController;
  final TextEditingController spouseNameController;
  final TextEditingController spouseBirthdayController;
  final TextEditingController childrenController;
  final TextEditingController studyFieldController;
  final TextEditingController studySchoolController;
  final TextEditingController visaNoController;
  final TextEditingController permitNoController;
  final TextEditingController visaExpireController;
  final TextEditingController workPermitExpireController;

  PrivateInfoState({
    this.isLoading = false,
    this.isEditing = false,
    this.isSaving = false,
    this.showError = false,
    this.showSuccess = false,
    this.showWarning = false,
    this.employeeDetails,
    this.countries = const [],
    this.states = const [],
    this.banks = const [],
    this.languages = const [],
    this.workPermitBytes,
    this.warningMessage,
    this.errorMessage,
    this.successMessage,
    this.selectedPrivateCountryId,
    this.selectedPrivateStateId,
    this.selectedPrivateBankId,
    this.selectedPrivateLangId,
    this.selectedCountryId,
    this.selectedBirthCountryId,
    this.selectedGender,
    this.selectedMarital,
    this.selectedCertificate,
    required this.dropdownFocusNode,

    TextEditingController? privateStreetController,
    TextEditingController? privateStreet2Controller,
    TextEditingController? privateCityController,
    TextEditingController? privateEmailController,
    TextEditingController? privatePhoneController,
    TextEditingController? kmHomeWorkController,
    TextEditingController? privateCarPlateController,
    TextEditingController? identificationIdController,
    TextEditingController? ssnIdController,
    TextEditingController? passportIdController,
    TextEditingController? birthdayController,
    TextEditingController? placeOfBirthController,
    TextEditingController? spouseNameController,
    TextEditingController? spouseBirthdayController,
    TextEditingController? childrenController,
    TextEditingController? studyFieldController,
    TextEditingController? studySchoolController,
    TextEditingController? visaNoController,
    TextEditingController? permitNoController,
    TextEditingController? visaExpireController,
    TextEditingController? workPermitExpireController,
  }) : privateStreetController =
           privateStreetController ?? TextEditingController(),
       privateStreet2Controller =
           privateStreet2Controller ?? TextEditingController(),
       privateCityController = privateCityController ?? TextEditingController(),
       privateEmailController =
           privateEmailController ?? TextEditingController(),
       privatePhoneController =
           privatePhoneController ?? TextEditingController(),
       kmHomeWorkController =
           kmHomeWorkController ?? TextEditingController(text: '0'),
       privateCarPlateController =
           privateCarPlateController ?? TextEditingController(),
       identificationIdController =
           identificationIdController ?? TextEditingController(),
       ssnIdController = ssnIdController ?? TextEditingController(),
       passportIdController = passportIdController ?? TextEditingController(),
       birthdayController = birthdayController ?? TextEditingController(),
       placeOfBirthController =
           placeOfBirthController ?? TextEditingController(),
       spouseNameController = spouseNameController ?? TextEditingController(),
       spouseBirthdayController =
           spouseBirthdayController ?? TextEditingController(),
       childrenController =
           childrenController ?? TextEditingController(text: '0'),
       studyFieldController = studyFieldController ?? TextEditingController(),
       studySchoolController = studySchoolController ?? TextEditingController(),
       visaNoController = visaNoController ?? TextEditingController(),
       permitNoController = permitNoController ?? TextEditingController(),
       visaExpireController = visaExpireController ?? TextEditingController(),
       workPermitExpireController =
           workPermitExpireController ?? TextEditingController();

  /// Creates a new state instance with updated values.
  ///
  /// Special `isXxx` flags allow explicitly clearing nullable selection fields
  /// (e.g. `isPrivateCountry: true` → `selectedPrivateCountryId = null`).
  PrivateInfoState copyWith({
    bool? isLoading,
    bool? isEditing,
    bool? isSaving,
    bool? showError,
    bool? showSuccess,
    bool? showWarning,
    Map<String, dynamic>? employeeDetails,
    List<Map<String, dynamic>>? countries,
    List<Map<String, dynamic>>? states,
    List<Map<String, dynamic>>? banks,
    List<Map<String, dynamic>>? languages,
    Uint8List? workPermitBytes,
    String? warningMessage,
    String? errorMessage,
    String? successMessage,
    int? selectedPrivateCountryId,
    bool isPrivateCountry = false,
    int? selectedPrivateStateId,
    bool isPrivateState = false,
    int? selectedPrivateBankId,
    bool isPrivateBank = false,
    String? selectedPrivateLangId,
    bool isPrivateLang = false,
    int? selectedCountryId,
    bool isCountry = false,
    int? selectedBirthCountryId,
    bool isBirthCountry = false,
    String? selectedGender,
    bool isGender = false,
    String? selectedMarital,
    bool isMarital = false,
    String? selectedCertificate,
    bool isCertificate = false,
    FocusNode? dropdownFocusNode,
  }) {
    return PrivateInfoState(
      isLoading: isLoading ?? this.isLoading,
      isEditing: isEditing ?? this.isEditing,
      isSaving: isSaving ?? this.isSaving,
      showError: showError ?? this.showError,
      showSuccess: showSuccess ?? this.showSuccess,
      showWarning: showWarning ?? this.showWarning,
      employeeDetails: employeeDetails ?? this.employeeDetails,
      countries: countries ?? this.countries,
      states: states ?? this.states,
      banks: banks ?? this.banks,
      languages: languages ?? this.languages,
      workPermitBytes: workPermitBytes,
      warningMessage: warningMessage ?? this.warningMessage,
      errorMessage: errorMessage ?? this.errorMessage,
      successMessage: successMessage,
      selectedPrivateCountryId: isPrivateCountry
          ? null
          : selectedPrivateCountryId ?? this.selectedPrivateCountryId,
      selectedPrivateStateId: isPrivateState
          ? null
          : selectedPrivateStateId ?? this.selectedPrivateStateId,
      selectedPrivateBankId: isPrivateBank
          ? null
          : selectedPrivateBankId ?? this.selectedPrivateBankId,
      selectedPrivateLangId: isPrivateLang
          ? null
          : selectedPrivateLangId ?? this.selectedPrivateLangId,
      selectedCountryId: isCountry
          ? null
          : selectedCountryId ?? this.selectedCountryId,
      selectedBirthCountryId: isBirthCountry
          ? null
          : selectedBirthCountryId ?? this.selectedBirthCountryId,
      selectedGender: isGender ? null : selectedGender ?? this.selectedGender,
      selectedMarital: isMarital
          ? null
          : selectedMarital ?? this.selectedMarital,
      selectedCertificate: isCertificate
          ? null
          : selectedCertificate ?? this.selectedCertificate,

      privateStreetController: privateStreetController,
      privateStreet2Controller: privateStreet2Controller,
      privateCityController: privateCityController,
      privateEmailController: privateEmailController,
      privatePhoneController: privatePhoneController,
      kmHomeWorkController: kmHomeWorkController,
      privateCarPlateController: privateCarPlateController,
      identificationIdController: identificationIdController,
      ssnIdController: ssnIdController,
      passportIdController: passportIdController,
      birthdayController: birthdayController,
      placeOfBirthController: placeOfBirthController,
      spouseNameController: spouseNameController,
      spouseBirthdayController: spouseBirthdayController,
      childrenController: childrenController,
      studyFieldController: studyFieldController,
      studySchoolController: studySchoolController,
      visaNoController: visaNoController,
      permitNoController: permitNoController,
      visaExpireController: visaExpireController,
      workPermitExpireController: workPermitExpireController,
      dropdownFocusNode: dropdownFocusNode ?? this.dropdownFocusNode,
    );
  }

  @override
  bool operator ==(Object other) => identical(this, other);

  /// Hash code based on meaningful fields (required when overriding ==)
  @override
  int get hashCode => Object.hashAll([
    isLoading,
    isEditing,
    employeeDetails,
    workPermitBytes,
    warningMessage,
    errorMessage,
    selectedPrivateCountryId,
    selectedPrivateStateId,
    selectedPrivateBankId,
    selectedPrivateLangId,
    selectedCountryId,
    selectedBirthCountryId,
    selectedGender,
    selectedMarital,
    selectedCertificate,
  ]);
}
