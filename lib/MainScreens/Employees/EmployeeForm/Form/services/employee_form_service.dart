import 'package:odoo_rpc/odoo_rpc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../../CommonWidgets/core/company/session/company_session_manager.dart';

/// Service layer for all backend operations related to **viewing and editing a single employee** in Odoo.
///
/// Responsibilities:
/// - Session initialization
/// - Loading dropdown data (users, departments, jobs, resume types, skill types)
/// - Permission check (`canManageSkills` → hr.group_hr_user/manager or admin)
/// - Loading full employee details + categorized resume lines & skills
/// - CRUD operations for resume lines (`hr.resume.line`) and employee skills (`hr.employee.skill`)
/// - Updating main employee record (`hr.employee` write)
/// - Generating random badge/barcode
/// - Extracting readable error messages from Odoo exceptions
class EmployeeFormService {
  /// Ensures an active Odoo session exists before making RPC calls.
  ///
  /// Throws exception if no session is available.
  Future<void> initializeClient() async {
    final session = await CompanySessionManager.getCurrentSession();
    if (session == null) throw Exception("No active session");
  }

  /// Loads all active users (`res.users`) for the "Related User" dropdown.
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
  /// (e.g. `['active', '=', true]`) in production.
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

  /// Extracts major version number from Odoo `server_version` string.
  ///
  /// Used to handle API differences (e.g. `has_group` signature change in v18+).
  int parseMajorVersion(String serverVersion) {
    final match = RegExp(r'\d+').firstMatch(serverVersion);
    if (match != null) {
      return int.tryParse(match.group(0)!) ?? 0;
    }
    return 0;
  }

  /// Checks if current user has HR rights (user/manager) or is system admin.
  ///
  /// Uses `res.users.has_group` RPC — version-aware (args differ in Odoo 18+).
  Future<bool> canManageSkills() async {
    final prefs = await SharedPreferences.getInstance();
    final String version = prefs.getString('serverVersion') ?? '0';
    final int userId = prefs.getInt('userId') ?? 0;
    final int majorVersion = parseMajorVersion(version);

    Future<bool> hasGroup(String groupExtId) async {
      if (majorVersion >= 18) {
        return await CompanySessionManager.callKwWithCompany({
          'model': 'res.users',
          'method': 'has_group',
          'args': [userId, groupExtId],
          'kwargs': {},
        }) == true;
      } else {
        return await CompanySessionManager.callKwWithCompany({
          'model': 'res.users',
          'method': 'has_group',
          'args': [groupExtId],
          'kwargs': {},
        }) == true;
      }
    }

    final isHrUser = await hasGroup('hr.group_hr_user');
    final isHrManager = await hasGroup('hr.group_hr_manager');
    final isAdmin = await hasGroup('base.group_system');

    return isHrUser || isHrManager || isAdmin;
  }

  /// Loads job positions (`hr.job`) — only if user has HR permission.
  Future<List<Map<String, dynamic>>> loadJobs() async {
    try {
      final hasAccess = await canManageSkills();

      if (!hasAccess) {
        return [];
      }

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

  /// Loads resume line types (`hr.resume.line.type`).
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

  /// Loads skill types (`hr.skill.type`) — includes related IDs if permitted.
  Future<List<Map<String, dynamic>>> fetchSkillType() async {
    try {
      final canAccessRelations = await canManageSkills();

      final List<String> fields = ['id', 'name'];

      if (canAccessRelations) {
        fields.addAll(['skill_ids', 'skill_level_ids']);
      }

      final skillType = await CompanySessionManager.callKwWithCompany({
        'model': 'hr.skill.type',
        'method': 'search_read',
        'args': [[]],
        'kwargs': {'fields': fields},
      });

      if (skillType != null && skillType.isNotEmpty) {
        return List<Map<String, dynamic>>.from(skillType);
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  /// Fetches skills (`hr.skill`) filtered by IDs (usually from skill type).
  Future<List<Map<String, dynamic>>> fetchSkill(List<dynamic> ids) async {
    try {
      await initializeClient();
      final skill = await CompanySessionManager.callKwWithCompany({
        'model': 'hr.skill',
        'method': 'search_read',
        'args': [
          [
            ['id', 'in', ids],
          ],
        ],
        'kwargs': {
          'fields': ['id', 'name'],
        },
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
      final skillLevel = await CompanySessionManager.callKwWithCompany({
        'model': 'hr.skill.level',
        'method': 'search_read',
        'args': [
          [
            ['id', 'in', ids],
          ],
        ],
        'kwargs': {
          'fields': ['id', 'name'],
        },
      });

      if (skillLevel != null && skillLevel.isNotEmpty) {
        return List<Map<String, dynamic>>.from(skillLevel);
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  /// Creates a new resume line record (`hr.resume.line`).
  ///
  /// Returns `null` on success, error message string on failure.
  Future<String?> addResumeLine(data) async {
    try {
      await CompanySessionManager.callKwWithCompany({
        'model': 'hr.resume.line',
        'method': 'create',
        'args': [data],
        'kwargs': {},
      });

      return null;
    } on OdooException catch (e) {
      if (extractOdooError(e) == null) {
        return "Something went wrong, Please try again later";
      } else {
        return extractOdooError(e);
      }
    } catch (e) {
      return "Unexpected error occurred while adding resume line, Please try again late";
    }
  }

  /// Updates an existing resume line record.
  Future<String?> updateResumeLine(int id, data) async {
    try {
      await CompanySessionManager.callKwWithCompany({
        'model': 'hr.resume.line',
        'method': 'write',
        'args': [
          [id],
          data,
        ],
        'kwargs': {},
      });

      return null;
    } on OdooException catch (e) {
      if (extractOdooError(e) == null) {
        return "Something went wrong, Please try again later";
      } else {
        return extractOdooError(e);
      }
    } catch (e) {
      return "Unexpected error occurred while updating resume line, Please try again later.";
    }
  }

  /// Creates a new employee skill record (`hr.employee.skill`).
  Future<String?> addEmployeeSkill(data) async {
    try {
      await CompanySessionManager.callKwWithCompany({
        'model': 'hr.employee.skill',
        'method': 'create',
        'args': [data],
        'kwargs': {},
      });

      return null;
    } on OdooException catch (e) {
      if (extractOdooError(e) == null) {
        return "Something went wrong, Please try again later";
      } else {
        return extractOdooError(e);
      }
    } catch (e) {
      return "Unexpected error occurred while adding skill, Please try again later.";
    }
  }

  /// Updates an existing employee skill record.
  Future<String?> updateEmployeeSkill(int id, data) async {
    try {
      await CompanySessionManager.callKwWithCompany({
        'model': 'hr.employee.skill',
        'method': 'write',
        'args': [
          [id],
          data,
        ],
        'kwargs': {},
      });

      return null;
    } on OdooException catch (e) {
      if (extractOdooError(e) == null) {
        return "Something went wrong, Please try again later";
      } else {
        return extractOdooError(e);
      }
    } catch (e) {
      return "Unexpected error occurred while updating skill, Please try again later";
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

  /// Updates main employee record fields (`hr.employee` write).
  ///
  /// Returns map with `success` and `error` (null on success).
  Future<Map<String, dynamic>> updateHrEmployee(
    int id,
    Map<String, dynamic> data,
  ) async {
    try {
      final result = await CompanySessionManager.callKwWithCompany({
        'model': 'hr.employee',
        'method': 'write',
        'args': [
          [id],
          data,
        ],
        'kwargs': {},
      });
      return {'success': result == true, 'error': null};
    } on OdooException catch (e) {
      final msg = extractOdooError(e);
      return {'success': false, 'error': msg ?? 'Something went wrong, Please try again later'};
    } catch (e) {
      return {
        'success': false,
        'error':
            "Unexpected error occurred while updating employee, Please try again later",
      };
    }
  }

  /// Deletes a resume line record.
  Future<String?> deleteResumeLine(int id) async {
    try {
      await CompanySessionManager.callKwWithCompany({
        'model': 'hr.resume.line',
        'method': 'unlink',
        'args': [
          [id],
        ],
        'kwargs': {},
      });

      return null;
    } on OdooException catch (e) {
      if (extractOdooError(e) == null) {
        return "Something went wrong, Please try again later";
      } else {
        return extractOdooError(e);
      }
    } catch (e) {
      return "Unexpected error occurred while deleting resume line, Please try again later.";
    }
  }

  /// Deletes an employee skill record.
  Future<String?> deleteEmployeeSkill(int id) async {
    try {
      await CompanySessionManager.callKwWithCompany({
        'model': 'hr.employee.skill',
        'method': 'unlink',
        'args': [
          [id],
        ],
        'kwargs': {},
      });

      return null;
    } on OdooException catch (e) {
      if (extractOdooError(e) == null) {
        return "Something went wrong, Please try again later";
      } else {
        return extractOdooError(e);
      }
    } catch (e) {
      return "Unexpected error occurred while deleting skill, Please try again later.";
    }
  }

  /// Generates a random barcode/badge for the employee.
  Future<String?> generateBadge(int id) async {
    try {
      await CompanySessionManager.callKwWithCompany({
        'model': 'hr.employee',
        'method': 'generate_random_barcode',
        'args': [
          [id],
        ],
        'kwargs': {},
      });

      return null;
    } on OdooException catch (e) {
      if (extractOdooError(e) == null) {
        return "Something went wrong, Please try again later";
      } else {
        return extractOdooError(e);
      }
    } catch (e) {
      return "Unexpected error occurred while generating badge, Please try again later.";
    }
  }

  /// Loads full employee record with categorized resume lines and skills.
  ///
  /// Permission-aware: includes extra fields (`image_1920`, `employee_type`, etc.) only if allowed.
  Future<dynamic> loadEmployeeDetails(int id) async {
    try {
      final canSeeExtraFields = await canManageSkills();

      final safeFields = [
        'id',
        'name',
        'work_email',
        'work_phone',
        'mobile_phone',
        'parent_id',
        'department_id',
        'coach_id',
        'user_id',
        'job_id',
        'create_date',
        'resume_line_ids',
        'employee_skill_ids',
      ];
      if (canSeeExtraFields) {
        safeFields.addAll(['image_1920', 'employee_type', 'barcode', 'pin']);
      }

      final employeeDetails = await CompanySessionManager.callKwWithCompany({
        'model': 'hr.employee',
        'method': 'search_read',
        'args': [
          [
            ['id', '=', id],
          ],
        ],
        'kwargs': {'fields': safeFields},
      });
      if (employeeDetails == null || employeeDetails.isEmpty) {
        return null;
      }
      final employee = employeeDetails[0];

      final categorized = await loadResumeLine(employee['resume_line_ids']);
      final skills = await loadSkills(employee['employee_skill_ids']);

      employee["resume_categories"] = categorized;
      employee["skill_categories"] = skills;

      categorized.forEach((key, value) {});

      return employee;
    } catch (e) {
      return null;
    }
  }

  /// Categorizes resume lines by type (`hr.resume.line.type`).
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

  /// Categorizes employee skills by skill type.
  ///
  /// Returns map: skill type name → list of skill objects with progress
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

  /// Loads employee tags/categories and attaches tag names to each employee.
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
