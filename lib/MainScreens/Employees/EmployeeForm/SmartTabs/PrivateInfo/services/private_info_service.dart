import 'package:odoo_rpc/odoo_rpc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../../../CommonWidgets/core/company/session/company_session_manager.dart';

/// Service layer for all backend operations related to **private/personal employee information** in Odoo.
///
/// Responsibilities:
/// - Session initialization
/// - Loading supporting data (countries/states, languages, bank accounts)
/// - Loading private employee fields (address, contact, IDs, DOB, marital, education, work permit)
/// - Updating private employee fields (`hr.employee` write)
/// - Writing work permit binary (`has_work_permit` field)
/// - Extracting readable error messages from Odoo exceptions
/// - Version-aware field selection (Odoo 18+ uses `sex` instead of `gender`, `primary_bank_account_id` instead of `bank_account_id`)
class PrivateInfoService {
  /// Ensures an active Odoo session exists before making RPC calls.
  ///
  /// Throws exception if no session is available.
  Future<void> initializeClient() async {
    final session = await CompanySessionManager.getCurrentSession();
    if (session == null) throw Exception("No active session");
  }

  /// Loads active languages (`res.lang`) for the language preference dropdown.
  ///
  /// Returns list of maps with `code`, `name`, `iso_code`, `direction`.
  Future<List<Map<String, dynamic>>> fetchLanguage() async {
    try {
      final languageDetails = await CompanySessionManager.callKwWithCompany({
        'model': 'res.lang',
        'method': 'search_read',
        'args': [
          [
            ['active', '=', true],
          ],
        ],
        'kwargs': {
          'fields': ['code', 'name', 'iso_code', 'direction'],
          'order': 'name',
        },
      });
      if (languageDetails != null && languageDetails.isNotEmpty) {
        return List<Map<String, dynamic>>.from(languageDetails);
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  /// Loads all countries (`res.country`) for nationality / birth country / address dropdowns.
  Future<List<Map<String, dynamic>>> loadCountryState() async {
    try {
      final countryResponse = await CompanySessionManager.callKwWithCompany({
        'model': 'res.country',
        'method': 'search_read',
        'args': [[]],
        'kwargs': {},
      });

      if (countryResponse != null && countryResponse.isNotEmpty) {
        return List<Map<String, dynamic>>.from(countryResponse);
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  /// Loads states/provinces (`res.country.state`) — filtered by country if provided.
  ///
  /// If `countryId == 0`, returns all states (unfiltered).
  Future<List<Map<String, dynamic>>> loadState(int countryId) async {
    try {
      dynamic stateResponse;

      if (countryId > 0) {
        stateResponse = await CompanySessionManager.callKwWithCompany({
          'model': 'res.country.state',
          'method': 'search_read',
          'args': [
            [
              ['country_id', '=', countryId],
            ],
          ],
          'kwargs': {},
        });
      } else {
        stateResponse = await CompanySessionManager.callKwWithCompany({
          'model': 'res.country.state',
          'method': 'search_read',
          'args': [[]],
          'kwargs': {},
        });
      }

      if (stateResponse != null && stateResponse.isNotEmpty) {
        return List<Map<String, dynamic>>.from(stateResponse);
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  /// Loads bank accounts (`res.partner.bank`) linked to the employee's work contact.
  Future<List<Map<String, dynamic>>> loadBankAccount(int workContactId) async {
    try {
      final bank = await CompanySessionManager.callKwWithCompany({
        'model': 'res.partner.bank',
        'method': 'search_read',
        'args': [
          [
            ['partner_id', '=', workContactId],
          ],
        ],
        'kwargs': {
          'fields':['id','display_name']
        },
      });

      if (bank != null && bank.isNotEmpty) {
        return List<Map<String, dynamic>>.from(bank);
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  /// Updates private employee fields in `hr.employee`.
  ///
  /// Returns map with `success`, `warning`, `warningMessage`, or `errorMessage`.
  Future<dynamic> updateEmployeeDetails(int id, data) async {
    try {
      await CompanySessionManager.callKwWithCompany({
        'model': 'hr.employee',
        'method': 'write',
        'args': [
          [id],
          data,
        ],
        'kwargs': {},
      });

      return {"success": true, "error": null, "warning": false};
    } on OdooException catch (e) {
      final errorMsg = extractOdooError(e);
      return {
        "success": false,
        "warning": true,
        "warningMessage":
            errorMsg ?? "Failed to update private info, Please try again later",
      };
    } catch (e) {
      return {
        "success": false,
        "warning": false,
        "errorMessage": "Failed to update private info, Please try again later",
      };
    }
  }

  /// Extracts human-readable error message from Odoo exceptions.
  ///
  /// Supports `ValidationError`, `AccessError`, `UserError`.
  String? extractOdooError(OdooException e) {
    final text = e.toString();

    final validationMatch = RegExp(
      r'ValidationError:\s*([\s\S]*?)(?=, message:|, arguments:|, context:|\}$)',
    ).firstMatch(text);

    if (validationMatch != null) {
      return validationMatch.group(1)!.trim();
    }

    final accessMatch = RegExp(
      r'name:\s*odoo\.exceptions\.AccessError,\s*message:\s*([\s\S]*?)(?=, arguments:|, context:|\}$)',
      caseSensitive: false,
    ).firstMatch(text);

    if (accessMatch != null) {
      return accessMatch.group(1)!.trim();
    }

    final userMatch = RegExp(
      r'name:\s*odoo\.exceptions\.UserError,\s*message:\s*([\s\S]*?)(?=, arguments:|, context:|\}$)',
      caseSensitive: false,
    ).firstMatch(text);

    if (userMatch != null) {
      return userMatch.group(1)!.trim();
    }

    return null;
  }

  /// Extracts major version number from Odoo `server_version` string.
  ///
  /// Used to handle API differences (e.g. field names in v18+).
  int parseMajorVersion(String serverVersion) {
    final match = RegExp(r'\d+').firstMatch(serverVersion);
    if (match != null) {
      return int.tryParse(match.group(0)!) ?? 0;
    }
    return 0;
  }

  /// Loads private employee fields from `hr.employee` — version-aware field selection.
  ///
  /// Odoo 18+ uses `sex` instead of `gender`, `primary_bank_account_id` instead of `bank_account_id`.
  Future<dynamic> loadEmployeeDetails(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final String version = prefs.getString('serverVersion') ?? '0';
    final int majorVersion = parseMajorVersion(version);
    List<String> fields;
    if (majorVersion >= 18) {
      fields = [
        'id',
        'name',
        'work_contact_id',
        'primary_bank_account_id',
        'has_work_permit',
        'birthday',
        'private_street',
        'private_street2',
        'private_city',
        'private_email',
        'private_phone',
        'km_home_work',
        'private_car_plate',
        'identification_id',
        'ssnid',
        'passport_id',
        'place_of_birth',
        'spouse_complete_name',
        'spouse_birthdate',
        'children',
        'study_field',
        'study_school',
        'visa_no',
        'permit_no',
        'visa_expire',
        'work_permit_expiration_date',
        'private_country_id',
        'country_id',
        'country_of_birth',
        'sex',
        'marital',
        'certificate',
        'lang',
      ];
    } else {
      fields = [
        'id',
        'name',
        'work_contact_id',
        'has_work_permit',
        'birthday',
        'private_street',
        'private_street2',
        'private_city',
        'private_email',
        'private_phone',
        'km_home_work',
        'private_car_plate',
        'identification_id',
        'ssnid',
        'passport_id',
        'place_of_birth',
        'spouse_complete_name',
        'spouse_birthdate',
        'children',
        'study_field',
        'study_school',
        'visa_no',
        'permit_no',
        'visa_expire',
        'work_permit_expiration_date',
        'private_country_id',
        'bank_account_id',
        'country_id',
        'country_of_birth',
        'gender',
        'marital',
        'certificate',
        'lang',
      ];
    }

    try {
      final employeeDetails = await CompanySessionManager.callKwWithCompany({
        'model': 'hr.employee',
        'method': 'search_read',
        'args': [
          [
            ['id', '=', id],
          ],
        ],
        'kwargs': {'fields': fields},
      });
      if (employeeDetails == null || employeeDetails.isEmpty) {
        return null;
      }
      final employee = employeeDetails[0];
      return employee;
    } catch (e) {
      return null;
    }
  }

  /// Writes work permit binary data (`has_work_permit`) or clears it.
  ///
  /// Used for both upload (base64 string) and delete (null value).
  Future<dynamic> writePermit(int id, data) async {
    try {
      await CompanySessionManager.callKwWithCompany({
        'model': 'hr.employee',
        'method': 'write',
        'args': [
          [id],
          data,
        ],
        'kwargs': {},
      });

      return {"success": true, "error": null, "warning": false};
    } on OdooException catch (e) {
      final errorMsg = extractOdooError(e);
      return {
        "success": false,
        "warning": true,
        "warningMessage":
            errorMsg ?? "Failed to delete work permit, Please try again later",
      };
    } catch (e) {
      return {
        "warning": false,
        "success": false,
        "errorMessage": "Failed to delete work permit, Please try again later",
      };
    }
  }
}
