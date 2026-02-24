import 'package:odoo_rpc/odoo_rpc.dart';

import '../../../../CommonWidgets/core/company/session/company_session_manager.dart';

/// Service layer responsible for all backend operations related to **creating and editing employees** in Odoo.
///
/// Handles:
/// - Loading dropdown data (users, departments, jobs, countries, states, timezones, languages, banks, etc.)
/// - Fetching resume line types and skill types
/// - Loading and categorizing resume lines & employee skills
/// - Creating employee record + related resume lines & skills
/// - Error extraction from Odoo ValidationError
class EmployeeCreateService {
  /// Ensures an active Odoo session exists before making any RPC calls.
  ///
  /// Throws exception if no session is available.
  Future<void> initializeClient() async {
    final session = await CompanySessionManager.getCurrentSession();
    if (session == null) throw Exception("No active session");
  }

  /// Loads all active Odoo users (`res.users`) for the "Related User" dropdown.
  ///
  /// Returns list of `{id, name}` maps or empty list on error.
  Future<List<Map<String, dynamic>>> loadUsers() async {
    try {
      final users = await CompanySessionManager.callKwWithCompany({
        'model': 'res.users',
        'method': 'search_read',
        'args': [[]],
        'kwargs': {
          'fields': ['id', 'name'],
        },
      });

      if (users != null && users.isNotEmpty) {
        return List<Map<String, dynamic>>.from(users);
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  /// Loads employees that can be selected as manager or coach.
  ///
  /// Currently fetches all employees — consider adding domain filter
  /// (e.g. active employees only) in production.
  Future<List<Map<String, dynamic>>> loadManagerOrCoach() async {
    try {
      final employee = await CompanySessionManager.callKwWithCompany({
        'model': 'hr.employee',
        'method': 'search_read',
        'args': [[]],
        'kwargs': {
          'fields': ['id', 'name'],
        },
      });

      if (employee != null && employee.isNotEmpty) {
        return List<Map<String, dynamic>>.from(employee);
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  /// Loads all departments (`hr.department`) for the department dropdown.
  Future<List<Map<String, dynamic>>> loadDepartment() async {
    try {
      final department = await CompanySessionManager.callKwWithCompany({
        'model': 'hr.department',
        'method': 'search_read',
        'args': [[]],
        'kwargs': {
          'fields': ['id', 'name'],
        },
      });

      if (department != null && department.isNotEmpty) {
        return List<Map<String, dynamic>>.from(department);
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  /// Loads all job positions (`hr.job`) for the job dropdown.
  Future<List<Map<String, dynamic>>> loadJobs() async {
    try {
      final jobs = await CompanySessionManager.callKwWithCompany({
        'model': 'hr.job',
        'method': 'search_read',
        'args': [[]],
        'kwargs': {
          'fields': ['id', 'name'],
        },
      });

      if (jobs != null && jobs.isNotEmpty) {
        return List<Map<String, dynamic>>.from(jobs);
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  /// Loads resume line types (`hr.resume.line.type`) used in resume section.
  Future<List<Map<String, dynamic>>> fetchResumeType() async {
    try {
      final lineType = await CompanySessionManager.callKwWithCompany({
        'model': 'hr.resume.line.type',
        'method': 'search_read',
        'args': [[]],
        'kwargs': {
          'fields': ['id', 'name'],
        },
      });

      if (lineType != null && lineType.isNotEmpty) {
        return List<Map<String, dynamic>>.from(lineType);
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  /// Loads skill types (`hr.skill.type`) for the skill selection dropdown.
  Future<List<Map<String, dynamic>>> fetchSkillType() async {
    try {
      final skillType = await CompanySessionManager.callKwWithCompany({
        'model': 'hr.skill.type',
        'method': 'search_read',
        'args': [[]],
        'kwargs': {},
      });

      if (skillType != null && skillType.isNotEmpty) {
        return List<Map<String, dynamic>>.from(skillType);
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  /// Fetches skills (`hr.skill`) filtered by IDs (usually from selected skill type).
  ///
  /// If `ids` is empty, returns all skills.
  Future<List<Map<String, dynamic>>> fetchSkill(List<dynamic> ids) async {
    try {
      final domain = ids.isEmpty
          ? []
          : [
              ['id', 'in', ids],
            ];

      final skill = await CompanySessionManager.callKwWithCompany({
        'model': 'hr.skill',
        'method': 'search_read',
        'args': [domain],
        'kwargs': {},
      });

      if (skill != null && skill.isNotEmpty) {
        return List<Map<String, dynamic>>.from(skill);
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  /// Fetches skill levels (`hr.skill.level`) filtered by IDs.
  Future<List<Map<String, dynamic>>> fetchSkillLevel(List<dynamic> ids) async {
    try {
      final domain = ids.isEmpty
          ? []
          : [
              ['id', 'in', ids],
            ];
      final skillLevel = await CompanySessionManager.callKwWithCompany({
        'model': 'hr.skill.level',
        'method': 'search_read',
        'args': [domain],
        'kwargs': {},
      });

      if (skillLevel != null && skillLevel.isNotEmpty) {
        return List<Map<String, dynamic>>.from(skillLevel);
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  /// Loads all partners (`res.partner`) that can be used as work/private addresses.
  ///
  /// Currently fetches all — consider adding domain (e.g. company addresses only).
  Future<List<Map<String, dynamic>>> loadAddress() async {
    try {
      final result = await CompanySessionManager.callKwWithCompany({
        'model': 'res.partner',
        'method': 'search_read',
        'args': [[]],
        'kwargs': {
          'fields': ['name'],
        },
      });

      if (result != null && result.isNotEmpty) {
        return List<Map<String, dynamic>>.from(result);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Loads full address details for a given partner ID.
  ///
  /// Used to display street, city, zip, state, country after selection.
  Future<Map<String, dynamic>> loadFullAddress(int id) async {
    try {
      final result = await CompanySessionManager.callKwWithCompany({
        'model': 'res.partner',
        'method': 'search_read',
        'args': [
          [
            ['id', '=', id],
          ],
        ],
        'kwargs': {
          'fields': [
            'name',
            'street',
            'street2',
            'city',
            'zip',
            'state_id',
            'country_id',
          ],
        },
      });

      if (result != null && result.isNotEmpty) {
        return Map<String, dynamic>.from(result[0]);
      }
      return {};
    } catch (e) {
      return {};
    }
  }

  /// Loads work locations (`hr.work.location`).
  Future<List<Map<String, dynamic>>> loadLocation() async {
    try {
      final location = await CompanySessionManager.callKwWithCompany({
        'model': 'hr.work.location',
        'method': 'search_read',
        'args': [[]],
        'kwargs': {
          'fields': ['id', 'name'],
        },
      });

      if (location != null && location.isNotEmpty) {
        return List<Map<String, dynamic>>.from(location);
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  /// Loads expense managers (currently uses all users — consider domain filter).
  Future<List<Map<String, dynamic>>> loadExpense() async {
    try {
      final expense = await CompanySessionManager.callKwWithCompany({
        'model': 'res.users',
        'method': 'search_read',
        'args': [[]],
        'kwargs': {
          'fields': ['id', 'name'],
        },
      });

      if (expense != null && expense.isNotEmpty) {
        return List<Map<String, dynamic>>.from(expense);
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  /// Loads working schedules/calendars (`resource.calendar`).
  Future<List<Map<String, dynamic>>> loadWorkingHours() async {
    try {
      final workingHour = await CompanySessionManager.callKwWithCompany({
        'model': 'resource.calendar',
        'method': 'search_read',
        'args': [[]],
        'kwargs': {
          'fields': ['id', 'name'],
        },
      });

      if (workingHour != null && workingHour.isNotEmpty) {
        return List<Map<String, dynamic>>.from(workingHour);
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  List<Map<String, dynamic>> _availableTimezones = [];

  /// Loads available timezones using `fields_get` on `res.users.tz` selection field.
  ///
  /// Falls back to a hardcoded list if RPC fails or selection is empty.
  Future<List<Map<String, dynamic>>> fetchTimezones() async {
    try {
      final result = await CompanySessionManager.callKwWithCompany({
        'model': 'res.users',
        'method': 'fields_get',
        'args': [
          ['tz'],
        ],
        'kwargs': {
          'attributes': ['selection', 'string'],
        },
      });

      final tzField = (result != null)
          ? result['tz'] as Map<String, dynamic>?
          : null;
      final selection = tzField != null
          ? tzField['selection'] as List<dynamic>?
          : null;

      List<Map<String, dynamic>> timezones = [];

      if (selection != null && selection.isNotEmpty) {
        timezones = selection.map<Map<String, dynamic>>((item) {
          if (item is List && item.length >= 2) {
            return {'code': item[0].toString(), 'name': item[1].toString()};
          }
          return {'code': item.toString(), 'name': item.toString()};
        }).toList();
      }

      if (timezones.isEmpty) {
        timezones = [
          {'code': 'UTC', 'name': 'UTC'},
          {'code': 'Europe/Brussels', 'name': 'Europe/Brussels'},
          {'code': 'Asia/Kolkata', 'name': 'Asia/Kolkata'},
          {'code': 'America/New_York', 'name': 'America/New_York'},
        ];
      }

      _availableTimezones = timezones;

      return timezones;
    } catch (e) {
      _availableTimezones = [
        {'code': 'UTC', 'name': 'UTC'},
        {'code': 'America/New_York', 'name': 'Eastern Time (US & Canada)'},
        {'code': 'America/Chicago', 'name': 'Central Time (US & Canada)'},
        {'code': 'America/Denver', 'name': 'Mountain Time (US & Canada)'},
        {'code': 'America/Los_Angeles', 'name': 'Pacific Time (US & Canada)'},
        {'code': 'Europe/London', 'name': 'London'},
        {'code': 'Europe/Paris', 'name': 'Paris'},
        {'code': 'Europe/Berlin', 'name': 'Berlin'},
        {'code': 'Asia/Tokyo', 'name': 'Tokyo'},
        {'code': 'Asia/Shanghai', 'name': 'Shanghai'},
        {'code': 'Asia/Kolkata', 'name': 'Mumbai, Kolkata, New Delhi'},
        {'code': 'Asia/Dubai', 'name': 'Dubai'},
        {'code': 'Australia/Sydney', 'name': 'Sydney'},
      ];
      return _availableTimezones;
    } finally {}
  }

  /// Loads active languages (`res.lang`) for the language dropdown.
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

  /// Loads all countries (`res.country`) for country dropdowns.
  Future<List<Map<String, dynamic>>> loadCountryState() async {
    try {
      final countryResponse = await CompanySessionManager.callKwWithCompany({
        'model': 'res.country',
        'method': 'search_read',
        'args': [[]],
        'kwargs': {
          'fields': ['id', 'name'],
        },
      });

      if (countryResponse != null && countryResponse.isNotEmpty) {
        return List<Map<String, dynamic>>.from(countryResponse);
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  /// Loads states/provinces (`res.country.state`) — filtered by country if `countryId` > 0.
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
          'kwargs': {
            'fields': ['id', 'name'],
          },
        });
      } else {
        stateResponse = await CompanySessionManager.callKwWithCompany({
          'model': 'res.country.state',
          'method': 'search_read',
          'args': [[]],
          'kwargs': {
            'fields': ['id', 'name'],
          },
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

  /// Loads partner bank accounts (`res.partner.bank`) for private bank dropdown.
  Future<List<Map<String, dynamic>>> loadBankAccount() async {
    try {
      final bank = await CompanySessionManager.callKwWithCompany({
        'model': 'res.partner.bank',
        'method': 'search_read',
        'args': [[]],
        'kwargs': {
          'fields': ['id', 'display_name'],
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

  /// Creates a new resume line record (`hr.resume.line`).
  ///
  /// Returns `true` on success, `false` on failure.
  Future<bool> addResumeLine(data) async {
    try {
      await CompanySessionManager.callKwWithCompany({
        'model': 'hr.resume.line',
        'method': 'create',
        'args': [data],
        'kwargs': {},
      });

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Creates a new employee skill record (`hr.employee.skill`).
  ///
  /// Returns `true` on success, `false` on failure.
  Future<bool> addEmployeeSkill(data) async {
    try {
      await CompanySessionManager.callKwWithCompany({
        'model': 'hr.employee.skill',
        'method': 'create',
        'args': [data],
        'kwargs': {},
      });

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Main method to create a new employee record (`hr.employee`).
  ///
  /// Steps:
  /// 1. Creates main employee record
  /// 2. Creates resume lines (if any)
  /// 3. Creates employee skills (if any)
  ///
  /// Returns map with `success`, `employee_id`, and `error` (if failed).
  Future<dynamic> createEmployeeDetails(data, resumeLine, skillLine) async {
    try {
      final employeeId = await CompanySessionManager.callKwWithCompany({
        'model': 'hr.employee',
        'method': 'create',
        'args': [data],
        'kwargs': {},
      });

      if (employeeId is int && employeeId > 0) {
        if (resumeLine['resume_line_ids'] != null &&
            resumeLine['resume_line_ids'].isNotEmpty) {
          for (var line in resumeLine['resume_line_ids']) {
            line['employee_id'] = employeeId;
            await addResumeLine(line);
          }
        }

        if (skillLine['employee_skills'] != null &&
            skillLine['employee_skills'].isNotEmpty) {
          for (var skill in skillLine['employee_skills']) {
            skill['employee_id'] = employeeId;
            await addEmployeeSkill(skill);
          }
        }

        return {"success": true, "employee_id": employeeId, "error": null};
      }
    } on OdooException catch (e) {
      final errorMsg = extractOdooValidationError(e);
      return {
        "success": false,
        "employee_id": null,
        "error":
            errorMsg ?? "Failed to create employee, Please try again later",
      };
    } catch (e) {
      return {
        "success": false,
        "employee_id": null,
        "error": "Failed to create employee, Please try again later",
      };
    }
  }

  /// Extracts human-readable message from Odoo `ValidationError`.
  String? extractOdooValidationError(OdooException e) {
    final text = e.toString();

    final match = RegExp(
      r'ValidationError:\s*([\s\S]*?)(?=, message:|, arguments:|, context:|\}$)',
    ).firstMatch(text);

    if (match != null) {
      return match.group(1)!.trim();
    }
    return null;
  }

  /// Loads and categorizes resume lines (`hr.resume.line`) by type.
  ///
  /// Returns map: category name → {id, name, items: [...]}
  Future<Map<String, Map<String, dynamic>>> loadResumeLine(line_ids) async {
    try {
      final resumeData = await CompanySessionManager.callKwWithCompany({
        'model': 'hr.resume.line',
        'method': 'search_read',
        'args': [
          [
            ['id', 'in', line_ids],
          ],
        ],
        'kwargs': {},
      });

      if (resumeData == null) return {};

      Map<String, Map<String, dynamic>> categorizedLines = {};

      for (var item in resumeData) {
        var type = item["line_type_id"];

        int categoryId = 0;
        String categoryName = "Others";

        if (type != null &&
            type is List &&
            type.length > 1 &&
            type[1] != null &&
            type[1].toString().trim().isNotEmpty) {
          categoryId = type[0];
          categoryName = type[1];
        }

        if (type == null || type == false || !(type is List)) {
          categoryId = 0;
          categoryName = "Others";
        }

        categorizedLines.putIfAbsent(
          categoryName,
          () => {"id": categoryId, "name": categoryName, "items": []},
        );

        categorizedLines[categoryName]!["items"].add(item);
      }

      return categorizedLines;
    } catch (e) {
      return {};
    }
  }

  /// Loads and categorizes employee skills (`hr.employee.skill`) by skill type.
  ///
  /// Returns map: skill type name → list of skill objects
  Future<Map<String, List<Map<String, dynamic>>>> loadSkills(skill_ids) async {
    try {
      final skillsData = await CompanySessionManager.callKwWithCompany({
        'model': 'hr.employee.skill',
        'method': 'search_read',
        'args': [
          [
            ['id', 'in', skill_ids],
          ],
        ],
        'kwargs': {},
      });

      if (skillsData == null) return {};
      Map<String, List<Map<String, dynamic>>> categorizedSkills = {};

      for (var item in skillsData) {
        String skillType = (item['skill_type_id'] is List)
            ? item['skill_type_id'][1]
            : "Others";

        String skillName = (item['skill_id'] is List)
            ? item['skill_id'][1]
            : "Unknown Skill";
        int skillId = (item['skill_id'] is List) ? item['skill_id'][0] : 0;

        String level = (item['skill_level_id'] is List)
            ? item['skill_level_id'][1]
            : "Unknown";

        int progress = item['level_progress'] ?? 0;
        if (!categorizedSkills.containsKey(skillType)) {
          categorizedSkills[skillType] = [];
        }

        categorizedSkills[skillType]!.add({
          'id': item['id'],
          "name": skillName,
          "level": level,
          "skillId": skillId,
          "type": skillType,
          "progress": progress,
        });
      }
      return categorizedSkills;
    } catch (e) {
      return {};
    }
  }

  /// Loads employee tags/categories (`hr.employee.category`) and attaches tag names
  /// to each employee in the provided list.
  ///
  /// Mutates the input list by adding `"tag_names"` field.
  Future<void> loadTags(List<Map<String, dynamic>> employees) async {
    try {
      final List<int> tagIds = employees
          .expand((emp) => (emp["category_ids"] ?? []) as List)
          .cast<int>()
          .toSet()
          .toList();

      if (tagIds.isEmpty) {
        return;
      }

      final tagData = await CompanySessionManager.callKwWithCompany({
        'model': 'hr.employee.category',
        'method': 'search_read',
        'args': [
          [
            ['id', 'in', tagIds],
          ],
        ],
        'kwargs': {
          'fields': ['id', 'name'],
        },
      });

      if (tagData == null) return;

      final Map<int, String> tagMap = {
        for (var t in tagData) t['id']: t['name'],
      };

      for (var emp in employees) {
        final ids = (emp["category_ids"] ?? []) as List;

        emp["tag_names"] = ids.map((id) => tagMap[id] ?? "Unknown").toList();
      }
    } catch (e) {}
  }
}
