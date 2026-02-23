import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/private_info_service.dart';
import 'private_info_event.dart';
import 'private_info_state.dart';

/// Manages the state and business logic for viewing and editing an employee's **private/personal information**.
///
/// Features:
/// - Loading private employee data + supporting dropdowns (countries, states, languages, banks)
/// - View vs Edit mode toggling
/// - Real-time form field updates (address, contact, IDs, DOB, gender, marital, education, work permit)
/// - Work permit file upload/delete (base64 storage in `has_work_permit`)
/// - Version-aware field mapping (gender/sex, bank_account_id/primary_bank_account_id)
/// - Permission-aware loading (assumed via service)
/// - Success/error/warning messaging + snackbar triggering
/// - Unsaved changes tracking (via controllers vs original data)
class PrivateInfoBloc extends Bloc<PrivateInfoEvent, PrivateInfoState> {
  late PrivateInfoService _service;

  PrivateInfoBloc({PrivateInfoService? service})
      : _service = service ?? PrivateInfoService(),
        super(PrivateInfoState(isLoading: true, dropdownFocusNode: FocusNode())) {
    on<LoadPrivateInfo>(_onLoadPrivateInfo);
    on<LoadPrivateInfoDetails>(_onLoadPrivateInfoDetails);
    on<ToggleEditMode>(_onToggleEditMode);
    on<CancelEdit>(_onCancelEdit);
    on<UpdateField>(_onUpdateField);
    on<SavePrivateInfo>(_onSavePrivateInfo);
    on<UploadWorkPermit>(_onUploadWorkPermit);
    on<DeleteWorkPermit>(_onDeleteWorkPermit);
  }

  @override
  Future<void> close() {
    // Clean up shared focus node when bloc is disposed
    state.dropdownFocusNode.dispose();
    return super.close();
  }

  // ── Safe value parsers (handle Odoo quirks: false, null, lists, etc.) ──────

  /// Safely extracts string value (handles null/false)
  String safeString(dynamic v) {
    if (v == null || v == false) return '';
    return v.toString();
  }

  /// Safely extracts nullable integer (handles null/false/lists)
  int? safeInt(dynamic v) {
    if (v == null || v == false) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  /// Safely converts value to list (fallback to empty list)
  List safeList(dynamic v) {
    if (v == null || v == false) return [];
    if (v is List) return v;
    return [];
  }

  /// Extracts major version from Odoo `server_version` string
  int parseMajorVersion(String serverVersion) {
    final match = RegExp(r'\d+').firstMatch(serverVersion);
    if (match != null) {
      return int.tryParse(match.group(0)!) ?? 0;
    }
    return 0;
  }

  // ── Loading ────────────────────────────────────────────────────────────────

  /// Loads core private employee data and initializes controllers
  Future<void> _onLoadPrivateInfo(
    LoadPrivateInfo event,
    Emitter<PrivateInfoState> emit,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final String version = prefs.getString('serverVersion') ?? '0';
    final int majorVersion = parseMajorVersion(version);

    // Preserve dropdown lists across reloads
    final preservedCountries = state.countries;
    final preservedStates = state.states;
    final preservedLanguages = state.languages;

    if (event.showLoading) {
      emit(
        state.copyWith(
          isLoading: true,
          errorMessage: null,
          warningMessage: null,

          isGender: true,
          isMarital: true,
          isCertificate: true,
          isPrivateCountry: true,
          isPrivateState: true,
          isPrivateBank: true,
          isPrivateLang: true,
          isCountry: true,
          isBirthCountry: true,

          countries: preservedCountries,
          states: preservedStates,
          languages: preservedLanguages,
        ),
      );
    }
    try {
      final details = await _service.loadEmployeeDetails(event.employeeId);

      if (details == null) {
        emit(state.copyWith(
          isLoading: false,
          errorMessage: "Employee not found",
          countries: preservedCountries,
          states: preservedStates,
          languages: preservedLanguages,
        ));
        return;
      }

      List<Map<String, dynamic>> banks = [];
      int? workContactId = details['work_contact_id']?[0];
      if (workContactId != null) {
        banks = await _service.loadBankAccount(workContactId);
      }

      Uint8List? permitBytes;
      final permitRaw = details['has_work_permit'];
      if (permitRaw is String && permitRaw.isNotEmpty) {
        permitBytes = base64Decode(permitRaw);
      }

      state.birthdayController.text = safeString(details['birthday']);
      state.privateStreetController.text = safeString(
        details['private_street'],
      );
      state.privateStreet2Controller.text = safeString(
        details['private_street2'],
      );
      state.privateCityController.text = safeString(details['private_city']);
      state.privateEmailController.text = safeString(details['private_email']);
      state.privatePhoneController.text = safeString(details['private_phone']);
      state.kmHomeWorkController.text = safeString(details['km_home_work']);
      state.privateCarPlateController.text = safeString(
        details['private_car_plate'],
      );
      state.identificationIdController.text = safeString(
        details['identification_id'],
      );
      state.ssnIdController.text = safeString(details['ssnid']);
      state.passportIdController.text = safeString(details['passport_id']);
      state.placeOfBirthController.text = safeString(details['place_of_birth']);
      state.spouseNameController.text = safeString(
        details['spouse_complete_name'],
      );
      state.spouseBirthdayController.text = safeString(
        details['spouse_birthdate'],
      );
      state.childrenController.text = safeString(details['children']);
      state.studyFieldController.text = safeString(details['study_field']);
      state.studySchoolController.text = safeString(details['study_school']);
      state.visaNoController.text = safeString(details['visa_no']);
      state.permitNoController.text = safeString(details['permit_no']);
      state.visaExpireController.text = safeString(details['visa_expire']);
      state.workPermitExpireController.text = safeString(
        details['work_permit_expiration_date'],
      );

      final privateCountry = safeList(details['private_country_id']);
      final countryId = safeList(details['country_id']);
      final birthCountry = safeList(details['country_of_birth']);

      String? gender;
      final bankId;
      if (majorVersion < 18) {
        gender = details['gender'] is String ? details['gender'] : null;
        bankId = safeList(details['bank_account_id']);
      } else {
        gender = details['sex'] is String ? details['sex'] : null;
        bankId = safeList(details['primary_bank_account_id']);
      }

      emit(
        state.copyWith(
          isLoading: false,
          countries: preservedCountries,
          languages: preservedLanguages,
          states: preservedStates,

          employeeDetails: details,
          banks: banks,
          workPermitBytes: permitBytes,
          selectedPrivateCountryId: privateCountry.isNotEmpty
              ? privateCountry[0]
              : null,
          selectedPrivateBankId: bankId.isNotEmpty ? bankId[0] : null,
          selectedCountryId: countryId.isNotEmpty ? countryId[0] : null,
          selectedBirthCountryId: birthCountry.isNotEmpty
              ? birthCountry[0]
              : null,
          selectedGender: gender,
          selectedMarital: details['marital'] is String
              ? details['marital']
              : null,
          selectedCertificate: details['certificate'] is String
              ? details['certificate']
              : null,
          selectedPrivateLangId: details['lang'] is String
              ? details['lang']
              : null,
        ),
      );

    } catch (e) {
      emit(
        state.copyWith(
          isLoading: false,
          showError: true,
        ),
      );
    }
  }

  /// Loads supporting dropdown lists (countries/states, languages)
  Future<void> _onLoadPrivateInfoDetails(
    LoadPrivateInfoDetails event,
    Emitter<PrivateInfoState> emit,
  ) async {
    try {
      await _service.initializeClient();

      final countries = await _service.loadCountryState();
      final languages = await _service.fetchLanguage();

      emit(
        state.copyWith(
          countries: countries,
          states: await _service.loadState(0),
          languages: languages,
        ),
      );

    } catch (e) {
      emit(
        state.copyWith(
          isLoading: false,
          showError: true,
          errorMessage: "Something went wrong, Please try again later",
        ),
      );
    }
  }

  // ── Edit Mode Control ─────────────────────────────────────────────────────

  void _onToggleEditMode(ToggleEditMode event, Emitter<PrivateInfoState> emit) {
    emit(state.copyWith(isEditing: !state.isEditing));
  }

  void _onCancelEdit(CancelEdit event, Emitter<PrivateInfoState> emit) {
    emit(state.copyWith(isEditing: false));
  }

  // ── Field Updates ─────────────────────────────────────────────────────────

  void _onUpdateField(UpdateField event, Emitter<PrivateInfoState> emit) {
    switch (event.field) {
      case 'privateCountry':
        emit(state.copyWith(selectedPrivateCountryId: event.value));
        break;
      case 'privateState':
        emit(state.copyWith(selectedPrivateStateId: event.value));
        break;
      case 'privateBank':
        emit(state.copyWith(selectedPrivateBankId: event.value));
        break;
      case 'privateLang':
        emit(state.copyWith(selectedPrivateLangId: event.value));
        break;
      case 'country':
        emit(state.copyWith(selectedCountryId: event.value));
        break;
      case 'birthCountry':
        emit(state.copyWith(selectedBirthCountryId: event.value));
        break;
      case 'gender':
        emit(state.copyWith(selectedGender: event.value));
        break;
      case 'marital':
        emit(state.copyWith(selectedMarital: event.value));
        break;
      case 'certificate':
        emit(state.copyWith(selectedCertificate: event.value));
        break;
      case 'private_phone':
        emit(state.copyWith(selectedCertificate: event.value));
        break;
    }
  }

  /// Converts text input to null if it's 'N/A' (used for optional string fields)
  String? safeText(String text) {
    if (text.trim() == 'N/A') return null;
    return text;
  }

  /// Converts date input to null if it's 'N/A' (used for optional date fields)
  String? safeDate(String text) {
    if (text.trim() == 'N/A') return null;
    return text;
  }

  // ── Save ───────────────────────────────────────────────────────────────────

  /// Saves updated private fields to Odoo
  Future<void> _onSavePrivateInfo(
    SavePrivateInfo event,
    Emitter<PrivateInfoState> emit,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final String version = prefs.getString('serverVersion') ?? '0';
    final int majorVersion = parseMajorVersion(version);

    emit(state.copyWith(isSaving: true));
    try {
      await _service.initializeClient();

      final data = {
        'private_street': safeText(state.privateStreetController.text),
        'private_street2': safeText(state.privateStreet2Controller.text),
        'private_city': safeText(state.privateCityController.text),
        'private_state_id': state.selectedPrivateStateId,
        'private_country_id': state.selectedPrivateCountryId,
        'private_email': safeText(state.privateEmailController.text),
        'private_phone': safeText(state.privatePhoneController.text),
        'lang': state.selectedPrivateLangId,
        'km_home_work': state.kmHomeWorkController.text,
        'private_car_plate': safeText(state.privateCarPlateController.text),
        'country_id': state.selectedCountryId,
        'identification_id': safeText(state.identificationIdController.text),
        'ssnid': safeText(state.ssnIdController.text),
        'passport_id': safeText(state.passportIdController.text),
        'birthday': safeDate(state.birthdayController.text),
        'place_of_birth': safeText(state.placeOfBirthController.text),
        'country_of_birth': state.selectedBirthCountryId,
        'marital': state.selectedMarital,
        'spouse_complete_name': safeText(state.spouseNameController.text),
        'spouse_birthdate': safeDate(state.spouseBirthdayController.text),
        'children': state.childrenController.text,
        'certificate': state.selectedCertificate,
        'study_field': safeText(state.studyFieldController.text),
        'study_school': safeText(state.studySchoolController.text),
        'visa_no': safeText(state.visaNoController.text),
        'permit_no': safeText(state.permitNoController.text),
        'visa_expire': safeDate(state.visaExpireController.text),
        'work_permit_expiration_date':
        safeDate(state.workPermitExpireController.text),
      };

      // Version-aware field names
      if (majorVersion >= 18) {
        data['primary_bank_account_id'] = state.selectedPrivateBankId;
        data['sex'] = state.selectedGender;
      } else {
        data['bank_account_id'] = state.selectedPrivateBankId;
        data['gender'] = state.selectedGender;
      }

      final result = await _service.updateEmployeeDetails(event.employeeId, data);
      if (result['success'] == true) {
        add(LoadPrivateInfo(event.employeeId, showLoading: false));
        emit(
          state.copyWith(
            isEditing: false,
            isSaving: false,
            showSuccess: true,
            successMessage: "Private info updated successfully!",
          ),
        );
      } else if (result['warning'] == true) {
        emit(
          state.copyWith(
            showWarning: true,
            warningMessage:
                result['warningMessage'] ??
                "Warning: Could not update all fields",
            isEditing: false,
            isSaving: false,
          ),
        );
      } else {
        emit(
          state.copyWith(
            showError: true,
            errorMessage:
                result['errorMessage'] ??
                "Failed to update private info, Please try again later",
            isEditing: false,
            isSaving: false,
          ),
        );
      }
    } catch (e) {
      emit(
        state.copyWith(
          showError: true,
          errorMessage: "Failed to update private info, Please try again later",
          isEditing: false,
          isSaving: false,
        ),
      );
    } finally {
      emit(state.copyWith(isSaving: false));
    }
  }

  // ── Work Permit File Handling ─────────────────────────────────────────────

  /// Uploads new work permit document (base64)
  Future<void> _onUploadWorkPermit(
    UploadWorkPermit event,
    Emitter<PrivateInfoState> emit,
  ) async {
    try {
      emit(state.copyWith(isSaving: true));
      await _service.initializeClient();
      final result = await _service.writePermit(event.employeeId, {
        'has_work_permit': event.base64String,
      });
      if (result['success'] == true) {
        emit(
          state.copyWith(
            workPermitBytes: event.fileBytes,
            showSuccess: true,
            isSaving: false,
            successMessage: "Work permit updated successfully!",
          ),
        );
        // Refresh data
        add(LoadPrivateInfo(event.employeeId, showLoading: false));
      } else if (result['warning'] == true) {
        emit(
          state.copyWith(
            showWarning: true,
            isSaving: false,
            warningMessage:
            result['warningMessage'] ??
                "Warning: Could not update work permit",
          ),
        );
      } else {
        emit(
          state.copyWith(showError: true, errorMessage: result['errorMessage'],
            isSaving: false,),
        );
      }
    } catch (e) {
      emit(
        state.copyWith(
          showError: true,
          errorMessage: "Failed to upload work permit, Please try again later",
        ),
      );
    } finally {
      emit(state.copyWith(isSaving: false));
    }
  }

  /// Deletes existing work permit document
  Future<void> _onDeleteWorkPermit(
    DeleteWorkPermit event,
    Emitter<PrivateInfoState> emit,
  ) async {
    try {
      await _service.initializeClient();
      final result = await _service.writePermit(event.employeeId, {
        'has_work_permit': null,
      });
      if (result['success'] == true) {
        emit(
          state.copyWith(
            workPermitBytes: null,
            isEditing: false,
            showSuccess: true,
            successMessage: "Work permit deleted successfully!",
          ),
        );
        // Refresh data
        add(LoadPrivateInfo(event.employeeId));
      } else if (result['warning'] == true) {
        emit(
          state.copyWith(
            showWarning: true,
            warningMessage:
            result['warningMessage'] ??
                "Warning: Could not delete work permit",
          ),
        );
      } else {
        emit(
          state.copyWith(showError: true, errorMessage: result['errorMessage']),
        );
      }
    } catch (e) {
      emit(
        state.copyWith(
          showError: true,
          errorMessage: "Failed to delete work permit, Please try again later",
        ),
      );
    }
  }
}
