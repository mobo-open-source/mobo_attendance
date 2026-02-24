import 'dart:convert';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import '../../../../../CommonWidgets/globals.dart';
import '../../../../../CommonWidgets/shared/widgets/snackbar.dart';
import '../../../../CommonWidgets/core/language/translate_widget.dart';
import '../../../../CommonWidgets/core/providers/language_provider.dart';
import '../../EmployeeForm/Form/pages/employee_form_page.dart';
import '../../EmployeeForm/Form/widgets/shimmer_employee_details.dart';
import '../bloc/employee_create_bloc.dart';
import '../bloc/employee_create_event.dart';
import '../bloc/employee_create_state.dart';
import '../services/employee_create_service.dart';
import '../widgets/employee_create_info.dart';

/// Entry point widget for creating or editing an employee record.
///
/// Delegates rendering to the stateful [CreateEmployeeView].
class EmployeeCreatePage extends StatelessWidget {
  const EmployeeCreatePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const CreateEmployeeView();
  }
}

/// Stateful UI for the employee creation/editing form.
///
/// Features a multi-section, scrollable form with:
/// - Profile photo picker
/// - Basic info (name, job, department, emails, phones, manager/coach)
/// - Resume lines (experience/education/certificates)
/// - Skills selection
/// - Work information (address, location, working hours, timezone)
/// - Private information (address, contact, bank, language, distance)
/// - Personal details (ID, birthday, gender, marital status, family)
/// - Education & certificates
/// - Visa & work permit details
/// - HR settings (employee type, PIN, badge)
///
/// Uses `EmployeeCreateInfo` reusable widget for most fields.
/// Shows shimmer during loading, success/error snackbars, and dialogs for resume/skills.
class CreateEmployeeView extends StatefulWidget {
  const CreateEmployeeView({super.key});

  @override
  State<CreateEmployeeView> createState() => _CreateEmployeeViewState();
}

class _CreateEmployeeViewState extends State<CreateEmployeeView> {
  final TextEditingController _spouseDobController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _visaExpiryController = TextEditingController();
  final TextEditingController _workPermitExpiryController =
      TextEditingController();
  EmployeeCreateBloc? _bloc;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bloc = context.read<EmployeeCreateBloc>();
  }

  @override
  void dispose() {
    // Reset form state when leaving the page
    _bloc?.add( ResetForm());
    _spouseDobController.dispose();
    _dobController.dispose();
    _visaExpiryController.dispose();
    _workPermitExpiryController.dispose();
    super.dispose();
  }

  /// Static lists for dropdowns (employee type, gender, marital status, certificate level)
  static const List<Map<String, String>> employeeTypes = [
    {"key": "employee", "label": "Employee"},
    {"key": "student", "label": "Student"},
    {"key": "trainee", "label": "Trainee"},
    {"key": "contractor", "label": "Contractor"},
    {"key": "freelance", "label": "Freelancer"},
  ];
  static const List<Map<String, String>> genderTypes = [
    {"key": "male", "label": "Male"},
    {"key": "female", "label": "Female"},
    {"key": "other", "label": "Other"},
  ];
  static const List<Map<String, String>> marital = [
    {"key": "single", "label": "Single"},
    {"key": "married", "label": "Married"},
    {"key": "cohabitant", "label": "Legal Cohabitant"},
    {"key": "widower", "label": "Widower"},
    {"key": "divorced", "label": "Divorced"},
  ];
  static const List<Map<String, String>> certificate = [
    {"key": "graduate", "label": "Graduate"},
    {"key": "bachelor", "label": "Bachelor"},
    {"key": "master", "label": "Master"},
    {"key": "doctor", "label": "Doctor"},
    {"key": "other", "label": "Other"},
  ];

  /// Triggers image picker and dispatches PickImage event
  void _pickImage(BuildContext context) {
    context.read<EmployeeCreateBloc>().add(PickImage());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final translationService = context.read<LanguageProvider>();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        leading: IconButton(
          icon: Icon(
            HugeIcons.strokeRoundedArrowLeft01,
            color: isDark ? Colors.white : Colors.black,
            size: 28,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: tr(
          "Create Employee",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
      ),
      body: BlocConsumer<EmployeeCreateBloc, EmployeeCreateState>(
        listener: (context, state) {
          if (state.success) {
            CustomSnackbar.showSuccess(
              context,
              "Employee created successfully",
            );
            _bloc?.add( ResetForm());
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => EmployeeFormPage(
                  employeeId: state.employeeId!,
                  employeeName: state.name,
                ),
              ),
            );
          }
          if (state.errorMessage != null) {
            CustomSnackbar.showError(context, state.errorMessage!);
          }
        },
        builder: (context, state) {
          if (state.isLoading) {
            return ShimmerEmployeeDetails(isDark: isDark);
          }

          return Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Profile Photo + Basic Info Card ────────────────────────────────
                    Container(
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[850] : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: isDark
                                ? Colors.black.withOpacity(0.18)
                                : Colors.black.withOpacity(0.06),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Profile photo picker
                            Center(
                              child: GestureDetector(
                                onTap: () => _pickImage(context),
                                child: Stack(
                                  children: [
                                    ClipOval(
                                      child:
                                          state.imageBase64 != null &&
                                              state.imageBase64!.isNotEmpty
                                          ? Image.memory(
                                              base64Decode(state.imageBase64!),
                                              width: 100,
                                              height: 100,
                                              fit: BoxFit.cover,
                                            )
                                          : Container(
                                              width: 100,
                                              height: 100,
                                              decoration: BoxDecoration(
                                                color: isDark
                                                    ? Colors.grey[800]
                                                    : Colors.grey[100],
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                              ),
                                              child: Icon(
                                                Icons.person,
                                                size: 60,
                                                color: isDark
                                                    ? Colors.white
                                                    : AppStyle.primaryColor,
                                              ),
                                            ),
                                    ),
                                    Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? Colors.white
                                              : AppStyle.primaryColor,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          HugeIcons.strokeRoundedImageAdd02,
                                          size: 20,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            tr(
                              'Employee',
                              style: TextStyle(
                                fontWeight: FontWeight.w400,
                                color: isDark
                                    ? Colors.white70
                                    : const Color(0xff7F7F7F),
                              ),
                            ),
                            const SizedBox(height: 8),
                            EmployeeCreateInfo(
                              label: "Name",
                              value: state.name,
                              onTextChanged: (val) => context
                                  .read<EmployeeCreateBloc>()
                                  .add(UpdateName(val ?? '')),
                            ),
                            const SizedBox(height: 12),
                            tr(
                              'Job',
                              style: TextStyle(
                                fontWeight: FontWeight.w400,
                                color: isDark
                                    ? Colors.white70
                                    : const Color(0xff7F7F7F),
                              ),
                            ),
                            const SizedBox(height: 8),
                            EmployeeCreateInfo(
                              label: "Job",
                              value: "Select Job",
                              prefixIcon: HugeIcons.strokeRoundedNewJob,
                              dropdownItems: state.jobs,
                              selectedId: state.jobId,
                              onDropdownChanged: (v) {
                                context.read<EmployeeCreateBloc>().add(
                                  UpdateJob(v?['id']),
                                );
                              },
                            ),

                            const SizedBox(height: 12),
                            tr(
                              'Department',
                              style: TextStyle(
                                fontWeight: FontWeight.w400,
                                color: isDark
                                    ? Colors.white70
                                    : const Color(0xff7F7F7F),
                              ),
                            ),
                            const SizedBox(height: 8),
                            EmployeeCreateInfo(
                              label: "Department",
                              value: "Select Department",
                              prefixIcon: HugeIcons.strokeRoundedDepartement,
                              dropdownItems: state.departments,
                              selectedId: state.departmentId,
                              onDropdownChanged: (v) {
                                FocusScope.of(
                                  context,
                                ).requestFocus(state.dropdownFocusNode);
                                context.read<EmployeeCreateBloc>().add(
                                  UpdateDepartment(v?['id']),
                                );
                              },
                            ),
                            const SizedBox(height: 12),
                            tr(
                              'Email',
                              style: TextStyle(
                                fontWeight: FontWeight.w400,
                                color: isDark
                                    ? Colors.white70
                                    : const Color(0xff7F7F7F),
                              ),
                            ),
                            const SizedBox(height: 8),
                            EmployeeCreateInfo(
                              label: "Email",
                              prefixIcon: HugeIcons.strokeRoundedMail02,
                              value: state.workEmail,
                              onTextChanged: (val) => context
                                  .read<EmployeeCreateBloc>()
                                  .add(UpdateWorkEmail(val ?? '')),
                            ),
                            const SizedBox(height: 12),
                            tr(
                              'Work Phone',
                              style: TextStyle(
                                fontWeight: FontWeight.w400,
                                color: isDark
                                    ? Colors.white70
                                    : const Color(0xff7F7F7F),
                              ),
                            ),
                            const SizedBox(height: 8),
                            EmployeeCreateInfo(
                              label: "Phone Number",
                              value: state.workPhone,
                              prefixIcon: HugeIcons.strokeRoundedCall,
                              onTextChanged: (val) => context
                                  .read<EmployeeCreateBloc>()
                                  .add(UpdateWorkPhone(val ?? '')),
                            ),

                            const SizedBox(height: 12),
                            tr(
                              'Mobile Phone',
                              style: TextStyle(
                                fontWeight: FontWeight.w400,
                                color: isDark
                                    ? Colors.white70
                                    : const Color(0xff7F7F7F),
                              ),
                            ),
                            const SizedBox(height: 8),
                            EmployeeCreateInfo(
                              label: "Mobile Number",
                              value: state.mobilePhone,
                              prefixIcon: HugeIcons.strokeRoundedSmartPhone01,
                              onTextChanged: (val) => context
                                  .read<EmployeeCreateBloc>()
                                  .add(UpdateMobilePhone(val ?? '')),
                            ),
                            const SizedBox(height: 12),
                            tr(
                              'Manager',
                              style: TextStyle(
                                fontWeight: FontWeight.w400,
                                color: isDark
                                    ? Colors.white70
                                    : const Color(0xff7F7F7F),
                              ),
                            ),
                            const SizedBox(height: 8),
                            EmployeeCreateInfo(
                              label: "Manager",
                              value: "Select Manager",
                              prefixIcon: HugeIcons.strokeRoundedUser,
                              dropdownItems: state.employees,
                              selectedId: state.managerId,
                              onDropdownChanged: (v) {
                                FocusScope.of(
                                  context,
                                ).requestFocus(state.dropdownFocusNode);
                                context.read<EmployeeCreateBloc>().add(
                                  UpdateManager(v?['id']),
                                );
                              },
                            ),
                            const SizedBox(height: 12),
                            tr(
                              'Coach',
                              style: TextStyle(
                                fontWeight: FontWeight.w400,
                                color: isDark
                                    ? Colors.white70
                                    : const Color(0xff7F7F7F),
                              ),
                            ),
                            const SizedBox(height: 8),
                            EmployeeCreateInfo(
                              label: "Coach",
                              value: "Select Coach",
                              prefixIcon: HugeIcons.strokeRoundedUser,
                              dropdownItems: state.employees,
                              selectedId: state.coachId,
                              onDropdownChanged: (v) {
                                FocusScope.of(
                                  context,
                                ).requestFocus(state.dropdownFocusNode);
                                context.read<EmployeeCreateBloc>().add(
                                  UpdateCoach(v?['id']),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ── Resume Card ───────────────────────────────────────────────────────
                    Container(
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[850] : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: isDark
                                ? Colors.black.withOpacity(0.18)
                                : Colors.black.withOpacity(0.06),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(16),
                                topRight: Radius.circular(16),
                              ),
                            ),
                            child: tr(
                              'Resume',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.grey[900],
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                          Divider(
                            height: 1,
                            color: isDark ? Colors.grey[700] : Colors.grey[200],
                          ),
                          Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: double.infinity,
                                  height: 56,
                                  child: ElevatedButton(
                                    onPressed: () => _showResumeDialog(context),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isDark
                                          ? Colors.grey[700]
                                          : Colors.grey[200],
                                      foregroundColor: isDark
                                          ? Colors.white
                                          : Colors.grey[800],
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          HugeIcons.strokeRoundedFileAdd,
                                          size: 20,
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black,
                                        ),
                                        const SizedBox(width: 8),
                                        tr(
                                          'Add Resume',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                if (state.resumeLines.isNotEmpty) ...[
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        "${translationService.getCached('Resume Lines')} (${state.resumeLines.length})",
                                        style: TextStyle(
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black87,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  ListView.separated(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    itemCount: state.resumeLines.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: 12),
                                    itemBuilder: (context, index) {
                                      final line = state.resumeLines[index];
                                      return Card(
                                        elevation: 2,
                                        color: isDark
                                            ? Colors.grey[850]
                                            : Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(12),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      line['line_type_name'] ??
                                                          'Experience',
                                                      style: TextStyle(
                                                        color: AppStyle
                                                            .primaryColor,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      line['name'],
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: isDark
                                                            ? Colors.white
                                                            : Colors.black,
                                                        fontSize: 15,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      line['display_date'],
                                                      style: TextStyle(
                                                        color: isDark
                                                            ? Colors.white70
                                                            : Colors.black87,
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                    if (line['description']
                                                        .toString()
                                                        .isNotEmpty) ...[
                                                      const SizedBox(height: 6),
                                                      Text(
                                                        line['description'],
                                                        style: TextStyle(
                                                          color: isDark
                                                              ? Colors.white60
                                                              : Colors.black87,
                                                          fontSize: 13,
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                              IconButton(
                                                icon: Icon(
                                                  HugeIcons
                                                      .strokeRoundedDelete03,
                                                  size: 18,
                                                  color: isDark
                                                      ? Colors.white
                                                      : Colors.black,
                                                ),
                                                onPressed: () => context
                                                    .read<EmployeeCreateBloc>()
                                                    .add(
                                                      RemoveResumeLine(index),
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ] else
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(32),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.grey[800]
                                          : Colors.grey[100],
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isDark
                                            ? Colors.grey[700]!
                                            : Colors.grey[200]!,
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        Icon(
                                          HugeIcons.strokeRoundedNote,
                                          size: 48,
                                          color: isDark
                                              ? Colors.grey[600]
                                              : Colors.grey[400],
                                        ),
                                        const SizedBox(height: 16),
                                        tr(
                                          'No resume added yet',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                            color: isDark
                                                ? Colors.grey[400]
                                                : Colors.grey[600],
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        tr(
                                          'Tap "Add Resume" to get started',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: isDark
                                                ? Colors.grey[500]
                                                : Colors.grey[500],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── Skills Card ─────────────────────────────────────────────────────────
                    Container(
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[850] : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: isDark
                                ? Colors.black.withOpacity(0.18)
                                : Colors.black.withOpacity(0.06),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(16),
                                topRight: Radius.circular(16),
                              ),
                            ),
                            child: tr(
                              'Skills',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.grey[900],
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                          Divider(
                            height: 1,
                            color: isDark ? Colors.grey[700] : Colors.grey[200],
                          ),
                          Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: double.infinity,
                                  height: 56,
                                  child: ElevatedButton(
                                    onPressed: () => _showSkillDialog(context),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isDark
                                          ? Colors.grey[700]
                                          : Colors.grey[200],
                                      foregroundColor: isDark
                                          ? Colors.white
                                          : Colors.grey[800],
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          HugeIcons.strokeRoundedFileAdd,
                                          size: 20,
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black,
                                        ),
                                        const SizedBox(width: 8),
                                        tr(
                                          'Add Skill',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                if (state.selectedSkills.isNotEmpty) ...[
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        "${translationService.getCached('Selected Skills')} (${state.selectedSkills.length})",
                                        style: TextStyle(
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black87,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: state.selectedSkills.map((skill) {
                                      return Chip(
                                        label: Text(
                                          "${skill['skill_name']} - ${skill['skill_level_name']}",
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        deleteIcon: Icon(
                                          Icons.close,
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black87,
                                          size: 18,
                                        ),
                                        onDeleted: () {
                                          final index = state.selectedSkills
                                              .indexOf(skill);
                                          context
                                              .read<EmployeeCreateBloc>()
                                              .add(RemoveSkill(index));
                                        },
                                      );
                                    }).toList(),
                                  ),
                                ] else
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(32),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.grey[800]
                                          : Colors.grey[100],
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isDark
                                            ? Colors.grey[700]!
                                            : Colors.grey[200]!,
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        Icon(
                                          HugeIcons.strokeRoundedNote,
                                          size: 48,
                                          color: isDark
                                              ? Colors.grey[600]
                                              : Colors.grey[400],
                                        ),
                                        const SizedBox(height: 16),
                                        tr(
                                          'No skill added yet',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                            color: isDark
                                                ? Colors.grey[400]
                                                : Colors.grey[600],
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        tr(
                                          'Tap "Add Skill" to get started',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: isDark
                                                ? Colors.grey[500]
                                                : Colors.grey[500],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── Work Information Card ──────────────────────────────────────────────
                    Container(
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[850] : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: isDark
                                ? Colors.black.withOpacity(0.18)
                                : Colors.black.withOpacity(0.06),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(16),
                                topRight: Radius.circular(16),
                              ),
                            ),
                            child: tr(
                              'Work Information',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.grey[900],
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                          Divider(
                            height: 1,
                            color: isDark ? Colors.grey[700] : Colors.grey[200],
                          ),
                          Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                tr(
                                  "Work Address",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w400,
                                    color: isDark
                                        ? Colors.white70
                                        : const Color(0xff7F7F7F),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                EmployeeCreateInfo(
                                  label: "Work Address",
                                  value: "Select Work Address",
                                  prefixIcon:
                                      HugeIcons.strokeRoundedLocationUser02,
                                  dropdownItems: state.addresses,
                                  selectedId: state.addressId,
                                  onDropdownChanged: (v) {
                                    FocusScope.of(
                                      context,
                                    ).requestFocus(state.dropdownFocusNode);
                                    context.read<EmployeeCreateBloc>().add(
                                      UpdateAddress(v?['id']),
                                    );
                                  },
                                ),

                                if (state.addressDetails.isNotEmpty) ...[
                                  if (state.addressDetails['street'] != null &&
                                      state.addressDetails['street'] != false)
                                    Text(
                                      state.addressDetails['street'],
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: isDark
                                            ? Colors.white70
                                            : Colors.black87,
                                      ),
                                    ),
                                  if (state.addressDetails['street2'] != null &&
                                      state.addressDetails['street2'] != false)
                                    Text(
                                      state.addressDetails['street2'],
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: isDark
                                            ? Colors.white70
                                            : Colors.black87,
                                      ),
                                    ),
                                  if ((state.addressDetails['city'] != null &&
                                          state.addressDetails['city'] !=
                                              false) ||
                                      (state.addressDetails['zip'] != null &&
                                          state.addressDetails['zip'] != false))
                                    Text(
                                      "${state.addressDetails['city']} ${state.addressDetails['zip']}"
                                          .trim(),
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: isDark
                                            ? Colors.white70
                                            : Colors.black87,
                                      ),
                                    ),
                                  if (state.addressDetails['country_id'] !=
                                          null &&
                                      state.addressDetails['country_id'] !=
                                          false)
                                    Text(
                                      state.addressDetails['country_id'][1],
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: isDark
                                            ? Colors.white70
                                            : Colors.black87,
                                      ),
                                    ),
                                ],

                                const SizedBox(height: 12),
                                tr(
                                  "Work Location",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w400,
                                    color: isDark
                                        ? Colors.white70
                                        : const Color(0xff7F7F7F),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                EmployeeCreateInfo(
                                  label: "Work Location",
                                  value: "Select Work Location",
                                  prefixIcon: HugeIcons.strokeRoundedLocation10,
                                  dropdownItems: state.locations,
                                  selectedId: state.workLocationId,
                                  onDropdownChanged: (v) {
                                    FocusScope.of(
                                      context,
                                    ).requestFocus(state.dropdownFocusNode);
                                    context.read<EmployeeCreateBloc>().add(
                                      UpdateWorkLocation(v?['id']),
                                    );
                                  },
                                ),
                                const SizedBox(height: 12),
                                tr(
                                  "Working Hours",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w400,
                                    color: isDark
                                        ? Colors.white70
                                        : const Color(0xff7F7F7F),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                EmployeeCreateInfo(
                                  label: "Working Hours",
                                  value: "Select Working Hours",
                                  prefixIcon: HugeIcons.strokeRoundedTime02,
                                  dropdownItems: state.workingHours,
                                  selectedId: state.workingHoursId,
                                  onDropdownChanged: (v) {
                                    FocusScope.of(
                                      context,
                                    ).requestFocus(state.dropdownFocusNode);
                                    context.read<EmployeeCreateBloc>().add(
                                      UpdateWorkingHours(v?['id']),
                                    );
                                  },
                                ),
                                const SizedBox(height: 12),
                                tr(
                                  "Timezone",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w400,
                                    color: isDark
                                        ? Colors.white70
                                        : const Color(0xff7F7F7F),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                EmployeeCreateInfo(
                                  label: "Timezone",
                                  value: "Select Timezone",
                                  prefixIcon: HugeIcons
                                      .strokeRoundedTimeManagementCircle,
                                  dropdownItems: state.timezones,
                                  selectedKey: state.timezone,
                                  onDropdownChanged: (v) {
                                    FocusScope.of(
                                      context,
                                    ).requestFocus(state.dropdownFocusNode);
                                    context.read<EmployeeCreateBloc>().add(
                                      UpdateTimezone(v?['code']),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── Private Information Card ───────────────────────────────────────────
                    Container(
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[850] : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: isDark
                                ? Colors.black.withOpacity(0.18)
                                : Colors.black.withOpacity(0.06),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(16),
                                topRight: Radius.circular(16),
                              ),
                            ),
                            child: tr(
                              'Private Information',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.grey[900],
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                          Divider(
                            height: 1,
                            color: isDark ? Colors.grey[700] : Colors.grey[200],
                          ),

                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(height: 10),
                                tr(
                                  "Private Details",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : Colors.black,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      tr(
                                        "Street",
                                        style: TextStyle(
                                          fontWeight: FontWeight.w400,
                                          color: isDark
                                              ? Colors.white70
                                              : const Color(0xff7F7F7F),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      EmployeeCreateInfo(
                                        label: "Street",
                                        value: state.privateStreet,
                                        prefixIcon:
                                            HugeIcons.strokeRoundedRoad01,
                                        onTextChanged: (val) => context
                                            .read<EmployeeCreateBloc>()
                                            .add(
                                              UpdatePrivateStreet(val ?? ''),
                                            ),
                                      ),
                                      const SizedBox(height: 12),
                                      tr(
                                        "Street 2",
                                        style: TextStyle(
                                          fontWeight: FontWeight.w400,
                                          color: isDark
                                              ? Colors.white70
                                              : const Color(0xff7F7F7F),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      EmployeeCreateInfo(
                                        label: "Street 2",
                                        value: state.privateStreet2,
                                        prefixIcon:
                                            HugeIcons.strokeRoundedRoad01,
                                        onTextChanged: (val) => context
                                            .read<EmployeeCreateBloc>()
                                            .add(
                                              UpdatePrivateStreet2(val ?? ''),
                                            ),
                                      ),
                                      const SizedBox(height: 12),
                                      tr(
                                        "City",
                                        style: TextStyle(
                                          fontWeight: FontWeight.w400,
                                          color: isDark
                                              ? Colors.white70
                                              : const Color(0xff7F7F7F),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      EmployeeCreateInfo(
                                        label: "City",
                                        value: state.privateCity,
                                        prefixIcon:
                                            HugeIcons.strokeRoundedCity01,
                                        onTextChanged: (val) => context
                                            .read<EmployeeCreateBloc>()
                                            .add(UpdatePrivateCity(val ?? '')),
                                      ),
                                      const SizedBox(height: 12),
                                      tr(
                                        "State",
                                        style: TextStyle(
                                          fontWeight: FontWeight.w400,
                                          color: isDark
                                              ? Colors.white70
                                              : const Color(0xff7F7F7F),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      EmployeeCreateInfo(
                                        label: "State",
                                        value: "Select State",
                                        prefixIcon:
                                            HugeIcons.strokeRoundedNavigator01,
                                        dropdownItems: state.states,
                                        selectedId: state.privateStateId,
                                        onDropdownChanged: (v) {
                                          FocusScope.of(context).requestFocus(
                                            state.dropdownFocusNode,
                                          );
                                          context
                                              .read<EmployeeCreateBloc>()
                                              .add(
                                                UpdatePrivateState(v?['id']),
                                              );
                                        },
                                      ),
                                      const SizedBox(height: 12),
                                      tr(
                                        "Country",
                                        style: TextStyle(
                                          fontWeight: FontWeight.w400,
                                          color: isDark
                                              ? Colors.white70
                                              : const Color(0xff7F7F7F),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      EmployeeCreateInfo(
                                        label: "Country",
                                        value: "Select Country",
                                        prefixIcon:
                                            HugeIcons.strokeRoundedEarth,
                                        dropdownItems: state.countries,
                                        selectedId: state.privateCountryId,
                                        onDropdownChanged: (v) {
                                          FocusScope.of(context).requestFocus(
                                            state.dropdownFocusNode,
                                          );
                                          context
                                              .read<EmployeeCreateBloc>()
                                              .add(
                                                UpdatePrivateCountry(v?['id']),
                                              );
                                        },
                                      ),

                                      const SizedBox(height: 12),
                                      tr(
                                        "Private Email",
                                        style: TextStyle(
                                          fontWeight: FontWeight.w400,
                                          color: isDark
                                              ? Colors.white70
                                              : const Color(0xff7F7F7F),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      EmployeeCreateInfo(
                                        label: "Private Email",
                                        value: state.privateEmail,
                                        prefixIcon:
                                            HugeIcons.strokeRoundedMail02,
                                        onTextChanged: (val) => context
                                            .read<EmployeeCreateBloc>()
                                            .add(UpdatePrivateEmail(val ?? '')),
                                      ),
                                      const SizedBox(height: 12),
                                      tr(
                                        "Phone",
                                        style: TextStyle(
                                          fontWeight: FontWeight.w400,
                                          color: isDark
                                              ? Colors.white70
                                              : const Color(0xff7F7F7F),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      EmployeeCreateInfo(
                                        label: "Private Phone",
                                        value: state.privatePhone,
                                        prefixIcon: HugeIcons.strokeRoundedCall,
                                        onTextChanged: (val) => context
                                            .read<EmployeeCreateBloc>()
                                            .add(UpdatePrivatePhone(val ?? '')),
                                      ),
                                      const SizedBox(height: 12),
                                      tr(
                                        "Bank Account Number",
                                        style: TextStyle(
                                          fontWeight: FontWeight.w400,
                                          color: isDark
                                              ? Colors.white70
                                              : const Color(0xff7F7F7F),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      EmployeeCreateInfo(
                                        label: "Bank Account",
                                        value: "Select Bank Account",
                                        prefixIcon: HugeIcons.strokeRoundedBank,
                                        dropdownItems: state.banks,
                                        selectedId: state.privateBankId,
                                        onDropdownChanged: (v) {
                                          FocusScope.of(context).requestFocus(
                                            state.dropdownFocusNode,
                                          );
                                          context
                                              .read<EmployeeCreateBloc>()
                                              .add(UpdatePrivateBank(v?['id']));
                                        },
                                      ),
                                      const SizedBox(height: 12),
                                      tr(
                                        "Language",
                                        style: TextStyle(
                                          fontWeight: FontWeight.w400,
                                          color: isDark
                                              ? Colors.white70
                                              : const Color(0xff7F7F7F),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      EmployeeCreateInfo(
                                        label: "Language",
                                        value: "Select Language",
                                        prefixIcon: HugeIcons
                                            .strokeRoundedLanguageSquare,
                                        dropdownItems: state.languages,
                                        selectedKey: state.privateLang,
                                        onDropdownChanged: (v) {
                                          FocusScope.of(context).requestFocus(
                                            state.dropdownFocusNode,
                                          );
                                          context
                                              .read<EmployeeCreateBloc>()
                                              .add(
                                                UpdatePrivateLang(v?['code']),
                                              );
                                        },
                                      ),
                                      const SizedBox(height: 12),
                                      tr(
                                        "Home-Work Distance",
                                        style: TextStyle(
                                          fontWeight: FontWeight.w400,
                                          color: isDark
                                              ? Colors.white70
                                              : const Color(0xff7F7F7F),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      EmployeeCreateInfo(
                                        label: "Km Home-Work",
                                        value: state.kmHomeWork,
                                        prefixIcon:
                                            HugeIcons.strokeRoundedRoute03,
                                        isNumberInput: true,
                                        isKmInclude: true,
                                        onTextChanged: (val) => context
                                            .read<EmployeeCreateBloc>()
                                            .add(UpdateKmHomeWork(val ?? '0')),
                                      ),
                                      const SizedBox(height: 12),
                                      tr(
                                        "Car Plate",
                                        style: TextStyle(
                                          fontWeight: FontWeight.w400,
                                          color: isDark
                                              ? Colors.white70
                                              : const Color(0xff7F7F7F),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      EmployeeCreateInfo(
                                        label: "Private Car Plate",
                                        value: state.privateCarPlate,
                                        prefixIcon:
                                            HugeIcons.strokeRoundedCar01,
                                        onTextChanged: (val) => context
                                            .read<EmployeeCreateBloc>()
                                            .add(
                                              UpdatePrivateCarPlate(val ?? ''),
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                tr(
                                  "Citizenship",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : Colors.black,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      tr(
                                        "Nationality (Country)",
                                        style: TextStyle(
                                          fontWeight: FontWeight.w400,
                                          color: isDark
                                              ? Colors.white70
                                              : const Color(0xff7F7F7F),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      EmployeeCreateInfo(
                                        label: "Nationality",
                                        value: "Select Country",
                                        prefixIcon:
                                            HugeIcons.strokeRoundedEarth,
                                        dropdownItems: state.countries,
                                        selectedId: state.countryId,
                                        onDropdownChanged: (v) {
                                          FocusScope.of(context).requestFocus(
                                            state.dropdownFocusNode,
                                          );
                                          context
                                              .read<EmployeeCreateBloc>()
                                              .add(UpdateCountry(v?['id']));
                                        },
                                      ),
                                      const SizedBox(height: 12),
                                      tr(
                                        "Identification",
                                        style: TextStyle(
                                          fontWeight: FontWeight.w400,
                                          color: isDark
                                              ? Colors.white70
                                              : const Color(0xff7F7F7F),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      EmployeeCreateInfo(
                                        label: "Identification No",
                                        value: state.identificationId,
                                        prefixIcon:
                                            HugeIcons.strokeRoundedIdentityCard,
                                        onTextChanged: (val) => context
                                            .read<EmployeeCreateBloc>()
                                            .add(
                                              UpdateIdentificationId(val ?? ''),
                                            ),
                                      ),
                                      const SizedBox(height: 12),
                                      tr(
                                        "SSN",
                                        style: TextStyle(
                                          fontWeight: FontWeight.w400,
                                          color: isDark
                                              ? Colors.white70
                                              : const Color(0xff7F7F7F),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      EmployeeCreateInfo(
                                        label: "SSN No",
                                        value: state.ssnId,
                                        prefixIcon:
                                            HugeIcons.strokeRoundedIdentityCard,
                                        onTextChanged: (val) => context
                                            .read<EmployeeCreateBloc>()
                                            .add(UpdateSsnId(val ?? '')),
                                      ),
                                      const SizedBox(height: 12),
                                      tr(
                                        "Passport",
                                        style: TextStyle(
                                          fontWeight: FontWeight.w400,
                                          color: isDark
                                              ? Colors.white70
                                              : const Color(0xff7F7F7F),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      EmployeeCreateInfo(
                                        label: "Passport No",
                                        value: state.passportId,
                                        prefixIcon:
                                            HugeIcons.strokeRoundedPassport,
                                        onTextChanged: (val) => context
                                            .read<EmployeeCreateBloc>()
                                            .add(UpdatePassportId(val ?? '')),
                                      ),
                                      const SizedBox(height: 12),
                                      tr(
                                        "Birth Day",
                                        style: TextStyle(
                                          fontWeight: FontWeight.w400,
                                          color: isDark
                                              ? Colors.white70
                                              : const Color(0xff7F7F7F),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      EmployeeCreateInfo(
                                        label: "Date of Birth",
                                        value: state.birthday,
                                        controller: _dobController,
                                        isDateInput: true,
                                        onTextChanged: (val) {
                                          FocusScope.of(context).requestFocus(
                                            state.dropdownFocusNode,
                                          );
                                          context
                                              .read<EmployeeCreateBloc>()
                                              .add(UpdateBirthday(val ?? ''));
                                        },
                                      ),
                                      const SizedBox(height: 12),
                                      tr(
                                        "Gender",
                                        style: TextStyle(
                                          fontWeight: FontWeight.w400,
                                          color: isDark
                                              ? Colors.white70
                                              : const Color(0xff7F7F7F),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      EmployeeCreateInfo(
                                        label: "Gender",
                                        value: state.gender ?? "Select Gender",
                                        prefixIcon: HugeIcons
                                            .strokeRoundedSquareArrowDown01,
                                        selectedKey: state.gender,

                                        selection: genderTypes.map((e) {
                                          return {
                                            "id": e["key"]?.toString() ?? '',
                                            "name":
                                                e["label"]?.toString() ?? '',
                                          };
                                        }).toList(),

                                        onSelectionChanged: (val) {
                                          FocusScope.of(context).requestFocus(
                                            state.dropdownFocusNode,
                                          );
                                          context
                                              .read<EmployeeCreateBloc>()
                                              .add(UpdateGender(val));
                                        },
                                      ),
                                      const SizedBox(height: 12),

                                      tr(
                                        "Birth Place",
                                        style: TextStyle(
                                          fontWeight: FontWeight.w400,
                                          color: isDark
                                              ? Colors.white70
                                              : const Color(0xff7F7F7F),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      EmployeeCreateInfo(
                                        label: "Place of Birth",
                                        value: state.placeOfBirth,
                                        prefixIcon:
                                            HugeIcons.strokeRoundedGlobe02,
                                        onTextChanged: (val) => context
                                            .read<EmployeeCreateBloc>()
                                            .add(UpdatePlaceOfBirth(val ?? '')),
                                      ),
                                      const SizedBox(height: 12),
                                      tr(
                                        "Country of Birth",
                                        style: TextStyle(
                                          fontWeight: FontWeight.w400,
                                          color: isDark
                                              ? Colors.white70
                                              : const Color(0xff7F7F7F),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      EmployeeCreateInfo(
                                        label: "Country of Birth",
                                        value: "Select Country",
                                        prefixIcon:
                                            HugeIcons.strokeRoundedEarth,
                                        dropdownItems: state.countries,
                                        selectedId: state.countryOfBirthId,
                                        onDropdownChanged: (v) {
                                          FocusScope.of(context).requestFocus(
                                            state.dropdownFocusNode,
                                          );
                                          context
                                              .read<EmployeeCreateBloc>()
                                              .add(
                                                UpdateCountryOfBirth(v?['id']),
                                              );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                tr(
                                  "Family Status",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : Colors.black,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      tr(
                                        "Marital Status",
                                        style: TextStyle(
                                          fontWeight: FontWeight.w400,
                                          color: isDark
                                              ? Colors.white70
                                              : const Color(0xff7F7F7F),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      EmployeeCreateInfo(
                                        label: "Marital Status",
                                        value:
                                            state.maritalStatus ??
                                            "Select Marital Status",

                                        selectedKey: state.maritalStatus,
                                        prefixIcon:
                                            HugeIcons.strokeRoundedStatus,

                                        selection: marital.map((e) {
                                          return {
                                            "id": e["key"]?.toString() ?? '',
                                            "name":
                                                e["label"]?.toString() ?? '',
                                          };
                                        }).toList(),

                                        onSelectionChanged: (val) {
                                          FocusScope.of(context).requestFocus(
                                            state.dropdownFocusNode,
                                          );
                                          context
                                              .read<EmployeeCreateBloc>()
                                              .add(UpdateMaritalStatus(val));
                                        },
                                      ),
                                      const SizedBox(height: 12),

                                      tr(
                                        "Spouse Name",
                                        style: TextStyle(
                                          fontWeight: FontWeight.w400,
                                          color: isDark
                                              ? Colors.white70
                                              : const Color(0xff7F7F7F),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      EmployeeCreateInfo(
                                        label: "Spouse Name",
                                        value: state.spouseName,
                                        prefixIcon: HugeIcons.strokeRoundedUser,
                                        onTextChanged: (val) => context
                                            .read<EmployeeCreateBloc>()
                                            .add(UpdateSpouseName(val ?? '')),
                                      ),
                                      const SizedBox(height: 12),
                                      tr(
                                        "Spouse Birth Day",
                                        style: TextStyle(
                                          fontWeight: FontWeight.w400,
                                          color: isDark
                                              ? Colors.white70
                                              : const Color(0xff7F7F7F),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      EmployeeCreateInfo(
                                        label: "Spouse Birthdate",
                                        value: state.spouseBirthday,
                                        controller: _spouseDobController,
                                        isDateInput: true,
                                        onTextChanged: (val) {
                                          FocusScope.of(context).requestFocus(
                                            state.dropdownFocusNode,
                                          );

                                          context
                                              .read<EmployeeCreateBloc>()
                                              .add(
                                                UpdateSpouseBirthday(val ?? ''),
                                              );
                                        },
                                      ),
                                      const SizedBox(height: 12),
                                      tr(
                                        "Children",
                                        style: TextStyle(
                                          fontWeight: FontWeight.w400,
                                          color: isDark
                                              ? Colors.white70
                                              : const Color(0xff7F7F7F),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      EmployeeCreateInfo(
                                        label: "Number of Children",
                                        value: state.children,
                                        isNumberInput: true,
                                        prefixIcon:
                                            HugeIcons.strokeRoundedChild,
                                        onTextChanged: (val) => context
                                            .read<EmployeeCreateBloc>()
                                            .add(UpdateChildren(val ?? '')),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                tr(
                                  "Education",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : Colors.black,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      tr(
                                        "Certificate Level",
                                        style: TextStyle(
                                          fontWeight: FontWeight.w400,
                                          color: isDark
                                              ? Colors.white70
                                              : const Color(0xff7F7F7F),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      EmployeeCreateInfo(
                                        label: "Certificate Level",
                                        value:
                                            state.certificate ??
                                            "Select Certificate Level",
                                        prefixIcon: HugeIcons
                                            .strokeRoundedCertificate01,

                                        selectedKey: state.certificate,

                                        selection: certificate.map((e) {
                                          return {
                                            "id": e["key"]?.toString() ?? '',
                                            "name":
                                                e["label"]?.toString() ?? '',
                                          };
                                        }).toList(),

                                        onSelectionChanged: (val) {
                                          FocusScope.of(context).requestFocus(
                                            state.dropdownFocusNode,
                                          );
                                          context
                                              .read<EmployeeCreateBloc>()
                                              .add(UpdateCertificate(val));
                                        },
                                      ),
                                      const SizedBox(height: 12),

                                      tr(
                                        "Study",
                                        style: TextStyle(
                                          fontWeight: FontWeight.w400,
                                          color: isDark
                                              ? Colors.white70
                                              : const Color(0xff7F7F7F),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      EmployeeCreateInfo(
                                        label: "Field of Study",
                                        value: state.fieldOfStudy,
                                        prefixIcon:
                                            HugeIcons.strokeRoundedCustomField,
                                        onTextChanged: (val) => context
                                            .read<EmployeeCreateBloc>()
                                            .add(UpdateFieldOfStudy(val ?? '')),
                                      ),
                                      const SizedBox(height: 12),
                                      tr(
                                        "School",
                                        style: TextStyle(
                                          fontWeight: FontWeight.w400,
                                          color: isDark
                                              ? Colors.white70
                                              : const Color(0xff7F7F7F),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      EmployeeCreateInfo(
                                        label: "School Name",
                                        value: state.studySchool,
                                        prefixIcon:
                                            HugeIcons.strokeRoundedSchool,
                                        onTextChanged: (val) => context
                                            .read<EmployeeCreateBloc>()
                                            .add(UpdateStudySchool(val ?? '')),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                tr(
                                  "Work Permit",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : Colors.black,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      tr(
                                        "Visa",
                                        style: TextStyle(
                                          fontWeight: FontWeight.w400,
                                          color: isDark
                                              ? Colors.white70
                                              : const Color(0xff7F7F7F),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      EmployeeCreateInfo(
                                        label: "Visa No",
                                        value: state.visaNo,
                                        prefixIcon:
                                            HugeIcons.strokeRoundedPassport01,
                                        onTextChanged: (val) => context
                                            .read<EmployeeCreateBloc>()
                                            .add(UpdateVisaNo(val ?? '')),
                                      ),
                                      const SizedBox(height: 12),
                                      tr(
                                        "Work Permit",
                                        style: TextStyle(
                                          fontWeight: FontWeight.w400,
                                          color: isDark
                                              ? Colors.white70
                                              : const Color(0xff7F7F7F),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      EmployeeCreateInfo(
                                        label: "Work Permit No",
                                        value: state.permitNo,
                                        prefixIcon:
                                            HugeIcons.strokeRoundedPassport01,
                                        controller: _workPermitExpiryController,
                                        onTextChanged: (val) => context
                                            .read<EmployeeCreateBloc>()
                                            .add(UpdatePermitNo(val ?? '')),
                                      ),
                                      const SizedBox(height: 12),
                                      tr(
                                        "Visa Expiry",
                                        style: TextStyle(
                                          fontWeight: FontWeight.w400,
                                          color: isDark
                                              ? Colors.white70
                                              : const Color(0xff7F7F7F),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      EmployeeCreateInfo(
                                        label: "Visa Expiration",
                                        controller: _visaExpiryController,
                                        value: state.visaExpire,
                                        isDateInput: true,
                                        onTextChanged: (val) {
                                          FocusScope.of(context).requestFocus(
                                            state.dropdownFocusNode,
                                          );

                                          context
                                              .read<EmployeeCreateBloc>()
                                              .add(UpdateVisaExpire(val ?? ''));
                                        },
                                      ),
                                      const SizedBox(height: 12),
                                      tr(
                                        "Work Permit Expiry",
                                        style: TextStyle(
                                          fontWeight: FontWeight.w400,
                                          color: isDark
                                              ? Colors.white70
                                              : const Color(0xff7F7F7F),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      EmployeeCreateInfo(
                                        label: "Work Permit Expiration",
                                        controller: _workPermitExpiryController,
                                        value: state.workPermitExpire,
                                        isDateInput: true,
                                        onTextChanged: (val) {
                                          FocusScope.of(context).requestFocus(
                                            state.dropdownFocusNode,
                                          );

                                          context
                                              .read<EmployeeCreateBloc>()
                                              .add(
                                                UpdateWorkPermitExpire(
                                                  val ?? '',
                                                ),
                                              );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── HR Settings ────────────────────────────────────────────────────────
                    Container(
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[850] : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: isDark
                                ? Colors.black.withOpacity(0.18)
                                : Colors.black.withOpacity(0.06),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(16),
                                topRight: Radius.circular(16),
                              ),
                            ),
                            child: tr(
                              "HR Settings",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.grey[900],
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                          Divider(
                            height: 1,
                            color: isDark ? Colors.grey[700] : Colors.grey[200],
                          ),
                          Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                tr(
                                  "Employee Type",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w400,
                                    color: isDark
                                        ? Colors.white70
                                        : const Color(0xff7F7F7F),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                EmployeeCreateInfo(
                                  label: "Employee Type",
                                  value: state.employeeType,
                                  prefixIcon:
                                      HugeIcons.strokeRoundedSquareArrowDown01,
                                  selectedKey: state.employeeType,
                                  selection: employeeTypes
                                      .map(
                                        (e) => {
                                          "id": e["key"]!,
                                          "name": e["label"]!,
                                        },
                                      )
                                      .toList(),
                                  onSelectionChanged: (v) {
                                    FocusScope.of(
                                      context,
                                    ).requestFocus(state.dropdownFocusNode);
                                    context.read<EmployeeCreateBloc>().add(
                                      UpdateEmployeeType(v ?? 'employee'),
                                    );
                                  },
                                ),
                                const SizedBox(height: 12),

                                tr(
                                  "Related User",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w400,
                                    color: isDark
                                        ? Colors.white70
                                        : const Color(0xff7F7F7F),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                EmployeeCreateInfo(
                                  label: "Related User",
                                  value: "Select Related User",
                                  prefixIcon: HugeIcons.strokeRoundedUser,
                                  dropdownItems: state.users,
                                  selectedId: state.userId,
                                  onDropdownChanged: (v) {
                                    FocusScope.of(
                                      context,
                                    ).requestFocus(state.dropdownFocusNode);
                                    context.read<EmployeeCreateBloc>().add(
                                      UpdateUser(v?['id']),
                                    );
                                  },
                                ),
                                const SizedBox(height: 12),

                                tr(
                                  "PIN",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w400,
                                    color: isDark
                                        ? Colors.white70
                                        : const Color(0xff7F7F7F),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                EmployeeCreateInfo(
                                  label: "PIN Code",
                                  value: state.pin,
                                  prefixIcon: HugeIcons.strokeRoundedSmsCode,
                                  onTextChanged: (val) => context
                                      .read<EmployeeCreateBloc>()
                                      .add(UpdatePin(val ?? '')),
                                ),
                                const SizedBox(height: 12),

                                tr(
                                  "Badge",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w400,
                                    color: isDark
                                        ? Colors.white70
                                        : const Color(0xff7F7F7F),
                                  ),
                                ),
                                const SizedBox(height: 8),

                                EmployeeCreateInfo(
                                  label: "Badge ID",
                                  value: state.badge,
                                  prefixIcon: HugeIcons.strokeRoundedBarCode01,
                                  onTextChanged: (val) => context
                                      .read<EmployeeCreateBloc>()
                                      .add(UpdateBadge(val ?? '')),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── Submit Button ──────────────────────────────────────────────────────
                    BlocBuilder<EmployeeCreateBloc, EmployeeCreateState>(
                      builder: (context, state) {
                        return SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: state.isSaving
                                ? null
                                : () => context.read<EmployeeCreateBloc>().add(
                                    CreateEmployee(),
                                  ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark
                                  ? Colors.white
                                  : AppStyle.primaryColor,
                              foregroundColor: isDark
                                  ? Colors.black
                                  : Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                              elevation: 0,
                              shadowColor: Colors.transparent,
                              disabledBackgroundColor: isDark
                                  ? Colors.grey[700]!
                                  : Colors.grey[400]!,
                            ),
                            icon: Icon(
                              HugeIcons.strokeRoundedNoteAdd,
                              color: isDark ? Colors.black : Colors.white,
                              size: 20,
                            ),
                            label: state.isSaving
                                ? LoadingAnimationWidget.threeArchedCircle(
                                    color: isDark ? Colors.black : Colors.white,
                                    size: 20,
                                  )
                                : tr(
                                    "Create Employee",
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.black
                                          : Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                  ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),

              // Full-screen loading overlay during save
              if (state.isSaving)
                Center(
                  child: LoadingAnimationWidget.fourRotatingDots(
                    color: AppStyle.primaryColor,
                    size: 60,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  /// Opens dialog to add a new resume line (experience/education/etc.)
  void _showResumeDialog(BuildContext context) {
    final bloc = context.read<EmployeeCreateBloc>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return BlocProvider.value(value: bloc, child: const ResumeLineDialog());
      },
    );
  }

  /// Opens dialog to add a new skill entry
  void _showSkillDialog(BuildContext context) {
    final bloc = context.read<EmployeeCreateBloc>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) =>
          BlocProvider.value(value: bloc, child: const SkillDialog()),
    );
  }
}

/// Dialog for adding/editing a resume line (experience, education, certification, etc.).
class ResumeLineDialog extends StatefulWidget {
  const ResumeLineDialog({super.key});

  @override
  State<ResumeLineDialog> createState() => _ResumeLineDialogState();
}

class _ResumeLineDialogState extends State<ResumeLineDialog> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  Map<String, dynamic>? _selectedType;
  int? _selectedTypeId;
  DateTimeRange? _selectedRange;
  String? _titleError;
  String? _durationError;

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return "${date.day}/${date.month}/${date.year}";
    } catch (e) {
      return dateStr;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bloc = context.read<EmployeeCreateBloc>();
    final state = context.watch<EmployeeCreateBloc>().state;
    final translationService = context.read<LanguageProvider>();

    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          tr(
            "Create a resume line",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
            color: isDark ? Colors.white70 : Colors.black54,
          ),
        ],
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.95,
        height:
            MediaQuery.of(context).size.height *
            (_titleError != null || _durationError != null ? 0.48 : 0.42),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  tr(
                    "Title",
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white60 : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 5),
                  TextField(
                    controller: _titleController,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : const Color(0xff000000),
                    ),
                    onChanged: (_) => setState(() => _titleError = null),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      hintText: "e.g. Odoo Inc.",
                      hintStyle: TextStyle(
                        fontWeight: FontWeight.w400,
                        color: isDark ? Colors.white54 : Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                      errorText: _titleError,
                      prefixIcon: Icon(
                        HugeIcons.strokeRoundedWork,
                        color: isDark ? Colors.grey[400] : Colors.grey[500],
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: isDark ? Colors.white24 : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: isDark ? Colors.white : AppStyle.primaryColor,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  tr(
                    "Type",
                    style: TextStyle(
                      fontWeight: FontWeight.w400,
                      color: isDark ? Colors.white70 : const Color(0xff7F7F7F),
                    ),
                  ),
                  const SizedBox(height: 5),
                  DropdownSearch<Map<String, dynamic>>(
                    dropdownBuilder: (context, selectedItem) {
                      if (selectedItem == null) {
                        return tr(
                          "Select Type",
                          style: TextStyle(
                            fontWeight: FontWeight.w400,
                            color: isDark ? Colors.white54 : Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        );
                      }

                      return Text(
                        selectedItem['name'],
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? Colors.white70
                              : const Color(0xff000000),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      );
                    },
                    popupProps: PopupProps.menu(
                      menuProps: MenuProps(
                        backgroundColor: isDark
                            ? Colors.grey[900]
                            : Colors.grey[50],
                        elevation: 12,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),

                    items: state.resumeTypes,
                    itemAsString: (item) => item['name'] ?? '',
                    selectedItem: _selectedType,
                    onChanged: (value) {
                      setState(() {
                        _selectedType = value;
                        _selectedTypeId = value?['id'];
                      });
                    },
                    dropdownDecoratorProps: DropDownDecoratorProps(
                      dropdownSearchDecoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        hintText: translationService.getCached('Select Type'),
                        hintStyle: TextStyle(
                          fontWeight: FontWeight.w400,
                          color: isDark ? Colors.white54 : Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                        prefixIcon: Icon(
                          HugeIcons.strokeRoundedTask01,
                          color: isDark
                              ? Colors.white70
                              : const Color(0xff7F7F7F),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: isDark ? Colors.white24 : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: isDark
                                ? Colors.white
                                : AppStyle.primaryColor,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  tr(
                    "Duration",
                    style: TextStyle(
                      fontWeight: FontWeight.w400,
                      color: isDark ? Colors.white70 : const Color(0xff7F7F7F),
                    ),
                  ),
                  const SizedBox(height: 5),
                  InkWell(
                    onTap: () async {
                      final range = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(1990),
                        lastDate: DateTime(2100),
                      );
                      if (range != null) {
                        setState(() {
                          _selectedRange = range;
                          _durationError = null;
                        });
                      }
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        hintText: translationService.getCached('Select Date →'),
                        hintStyle: TextStyle(
                          fontWeight: FontWeight.w400,
                          color: isDark ? Colors.white54 : Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                        errorText: _durationError,
                        prefixIcon: Icon(
                          Icons.calendar_month,
                          color: isDark ? Colors.grey[400] : Colors.grey[500],
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: isDark ? Colors.white24 : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: isDark
                                ? Colors.white
                                : AppStyle.primaryColor,
                            width: 2,
                          ),
                        ),
                      ),
                      child: Text(
                        _selectedRange == null
                            ? (translationService.getCached("Select Date →") ??
                                  "Select Date →")
                            : "${_selectedRange!.start.toIso8601String().split('T')[0]} → ${_selectedRange!.end.toIso8601String().split('T')[0]}",
                        style: _selectedRange == null
                            ? TextStyle(
                                fontWeight: FontWeight.w400,
                                color: isDark
                                    ? Colors.white54
                                    : Colors.grey[600],
                                fontStyle: FontStyle.italic,
                              )
                            : TextStyle(
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? Colors.white70
                                    : const Color(0xff000000),
                              ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  tr(
                    "Description",
                    style: TextStyle(
                      fontWeight: FontWeight.w400,
                      color: isDark ? Colors.white70 : const Color(0xff7F7F7F),
                    ),
                  ),
                  const SizedBox(height: 5),
                  TextField(
                    controller: _descriptionController,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : const Color(0xff000000),
                    ),
                    maxLines: 3,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      hintText: translationService.getCached(
                        "Enter description...",
                      ),
                      hintStyle: TextStyle(
                        fontWeight: FontWeight.w400,
                        color: isDark ? Colors.white54 : Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: isDark ? Colors.white24 : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: isDark ? Colors.white : AppStyle.primaryColor,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? Colors.white : Colors.black87,
                  backgroundColor: isDark ? Colors.grey[800] : Colors.white,
                  side: BorderSide(
                    color: isDark ? Colors.white : AppStyle.primaryColor,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: tr(
                  "CLOSE",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppStyle.primaryColor,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark
                      ? Colors.white
                      : AppStyle.primaryColor,
                  foregroundColor: isDark ? Colors.black : Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  setState(() {
                    _titleError = _titleController.text.trim().isEmpty
                        ? "${translationService.getCached('Title is required')}"
                        : null;
                    _durationError = _selectedRange == null
                        ? "${translationService.getCached('Duration is required')}'"
                        : null;
                  });

                  if (_titleError != null || _durationError != null) return;

                  final dateStart = _selectedRange!.start
                      .toIso8601String()
                      .split('T')[0];
                  final dateEnd = _selectedRange!.end.toIso8601String().split(
                    'T',
                  )[0];

                  final newResumeLine = {
                    "name": _titleController.text.trim(),
                    "line_type_id": _selectedTypeId,
                    "line_type_name": _selectedType?['name'] ?? 'Experience',
                    "date_start": dateStart,
                    "date_end": dateEnd,
                    "description": _descriptionController.text.trim(),
                    "display_date":
                        "${_formatDate(dateStart)} → ${_formatDate(dateEnd)}",
                  };

                  final isDuplicate = state.resumeLines.any(
                    (line) =>
                        line['name'] == newResumeLine['name'] &&
                        line['date_start'] == newResumeLine['date_start'] &&
                        line['date_end'] == newResumeLine['date_end'],
                  );

                  if (isDuplicate) {
                    CustomSnackbar.showInfo(
                      context,
                      "This resume entry already exists.",
                    );
                    return;
                  }

                  bloc.add(AddResumeLine(newResumeLine));

                  CustomSnackbar.showSuccess(context, "Resume line added!");
                  Navigator.pop(context);
                },
                child: tr(
                  'SAVE',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.black : Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Dialog for adding a new skill entry to the employee's resume.
class SkillDialog extends StatefulWidget {
  const SkillDialog({super.key});

  @override
  State<SkillDialog> createState() => _SkillDialogState();
}

class _SkillDialogState extends State<SkillDialog> {
  Map<String, dynamic>? _selectedSkillType;
  int? _selectedSkillTypeId;
  List<Map<String, dynamic>> _skills = [];
  Map<String, dynamic>? _selectedSkill;
  int? _selectedSkillId;
  List<Map<String, dynamic>> _skillLevels = [];
  Map<String, dynamic>? _selectedSkillLevel;
  int? _selectedSkillLevelId;

  String? _skillError;

  @override
  void initState() {
    super.initState();
    _loadSkills();
  }

  Future<void> _loadSkills() async {
    final service = EmployeeCreateService();
    await service.initializeClient();

    final skills = await service.fetchSkill([]);

    final levels = await service.fetchSkillLevel([]);

    if (!mounted) return;

    setState(() {
      _skills = skills;
      _skillLevels = levels;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bloc = context.read<EmployeeCreateBloc>();
    final state = context.watch<EmployeeCreateBloc>().state;
    final translationService = context.read<LanguageProvider>();

    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          tr(
            "Add new skill",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
            color: isDark ? Colors.white70 : Colors.black54,
          ),
        ],
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.95,
        height:
            MediaQuery.of(context).size.height *
            (_skillError != null ? 0.35 : 0.30),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_skillError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    translationService.getCached(_skillError!) ?? _skillError!,
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const SizedBox(height: 10),

              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  tr(
                    "Skill Type",
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white60 : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 5),
                  DropdownSearch<Map<String, dynamic>>(
                    dropdownBuilder: (context, selectedItem) {
                      if (selectedItem == null) {
                        return tr(
                          "Select Skill Type",
                          style: TextStyle(
                            fontWeight: FontWeight.w400,
                            color: isDark ? Colors.white54 : Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        );
                      }

                      return Text(
                        selectedItem['name'],
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? Colors.white70
                              : const Color(0xff000000),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      );
                    },
                    popupProps: PopupProps.menu(
                      menuProps: MenuProps(
                        backgroundColor: isDark
                            ? Colors.grey[900]
                            : Colors.grey[50],
                        elevation: 12,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    items: state.skillTypes,
                    itemAsString: (item) => item['name'] ?? '',
                    selectedItem: _selectedSkillType,
                    onChanged: (value) async {
                      setState(() {
                        _selectedSkillType = value;
                        _selectedSkillTypeId = value?['id'];
                        _skills = [];
                        _selectedSkill = null;
                        _selectedSkillId = null;
                        _skillLevels = [];
                        _selectedSkillLevel = null;
                        _selectedSkillLevelId = null;
                      });

                      if (value != null &&
                          value['skill_ids'] != null &&
                          value['skill_level_ids'] != null) {
                        final service = EmployeeCreateService();
                        await service.initializeClient();
                        final skills = await service.fetchSkill(
                          value['skill_ids'] ?? [],
                        );
                        final levels = await service.fetchSkillLevel(
                          value['skill_level_ids'] ?? [],
                        );

                        setState(() {
                          _skills = skills;
                          if (_skills.isNotEmpty) {
                            _selectedSkill = _skills.first;
                            _selectedSkillId = _skills.first['id'];
                          }
                          _skillLevels = levels;
                          if (_skillLevels.isNotEmpty) {
                            _selectedSkillLevel = _skillLevels.first;
                            _selectedSkillLevelId = _skillLevels.first['id'];
                          }
                        });
                      }
                    },
                    dropdownDecoratorProps: DropDownDecoratorProps(
                      dropdownSearchDecoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        hintText: translationService.getCached('Select Skill Type'),
                        hintStyle: TextStyle(
                          fontWeight: FontWeight.w400,
                          color: isDark ? Colors.white54 : Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: isDark ? Colors.white24 : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: isDark
                                ? Colors.white
                                : AppStyle.primaryColor,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  tr(
                    "Skill",
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white60 : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 5),
                  DropdownSearch<Map<String, dynamic>>(
                    dropdownBuilder: (context, selectedItem) {
                      if (selectedItem == null) {
                        return tr(
                          "Select Skill",
                          style: TextStyle(
                            fontWeight: FontWeight.w400,
                            color: isDark ? Colors.white54 : Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        );
                      }

                      return Text(
                        selectedItem['name'],
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? Colors.white70
                              : const Color(0xff000000),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      );
                    },
                    popupProps: PopupProps.menu(
                      menuProps: MenuProps(
                        backgroundColor: isDark
                            ? Colors.grey[900]
                            : Colors.grey[50],
                        elevation: 12,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    items: _skills,
                    itemAsString: (item) => item['name'] ?? '',
                    selectedItem: _selectedSkill,
                    onChanged: (value) {
                      setState(() {
                        _selectedSkill = value;
                        _selectedSkillId = value?['id'];
                      });
                    },
                    dropdownDecoratorProps: DropDownDecoratorProps(
                      dropdownSearchDecoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        hintText: translationService.getCached('Select Skill'),
                        hintStyle: TextStyle(
                          fontWeight: FontWeight.w400,
                          color: isDark ? Colors.white54 : Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: isDark ? Colors.white24 : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: isDark
                                ? Colors.white
                                : AppStyle.primaryColor,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  tr(
                    "Skill level",
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white60 : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 5),
                  DropdownSearch<Map<String, dynamic>>(
                    dropdownBuilder: (context, selectedItem) {
                      if (selectedItem == null) {
                        return tr(
                          "Select Level",
                          style: TextStyle(
                            fontWeight: FontWeight.w400,
                            color: isDark ? Colors.white54 : Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        );
                      }

                      return Text(
                        selectedItem['name'],
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? Colors.white70
                              : const Color(0xff000000),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      );
                    },
                    popupProps: PopupProps.menu(
                      menuProps: MenuProps(
                        backgroundColor: isDark
                            ? Colors.grey[900]
                            : Colors.grey[50],
                        elevation: 12,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    items: _skillLevels,
                    itemAsString: (item) => item['name'] ?? '',
                    selectedItem: _selectedSkillLevel,
                    onChanged: (value) {
                      setState(() {
                        _selectedSkillLevel = value;
                        _selectedSkillLevelId = value?['id'];
                      });
                    },
                    dropdownDecoratorProps: DropDownDecoratorProps(
                      dropdownSearchDecoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        hintText: translationService.getCached('Select Skill Level'),
                        hintStyle: TextStyle(
                          fontWeight: FontWeight.w400,
                          color: isDark ? Colors.white54 : Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: isDark ? Colors.white24 : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: isDark
                                ? Colors.white
                                : AppStyle.primaryColor,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? Colors.white : Colors.black87,
                  backgroundColor: isDark ? Colors.grey[800] : Colors.white,
                  side: BorderSide(
                    color: isDark ? Colors.white : AppStyle.primaryColor,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: tr(
                  "CLOSE",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppStyle.primaryColor,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark
                      ? Colors.white
                      : AppStyle.primaryColor,
                  foregroundColor: isDark ? Colors.black : Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  if (_selectedSkillTypeId == null ||
                      _selectedSkillId == null ||
                      _selectedSkillLevelId == null) {
                    setState(() {
                      _skillError =
                          "${translationService.getCached('Please select skill type, skill, and level.')}";
                    });
                    return;
                  }

                  final newSkill = {
                    "skill_type_id": _selectedSkillTypeId,
                    "skill_type_name":
                        _selectedSkillType?['name'] ?? 'Unknown Type',
                    "skill_id": _selectedSkillId,
                    "skill_name": _selectedSkill?['name'] ?? 'Unknown Skill',
                    "skill_level_id": _selectedSkillLevelId,
                    "skill_level_name":
                        _selectedSkillLevel?['name'] ?? 'Unknown Level',
                  };

                  final isDuplicate = state.selectedSkills.any(
                    (s) =>
                        s['skill_id'] == newSkill['skill_id'] &&
                        s['skill_level_id'] == newSkill['skill_level_id'],
                  );

                  if (isDuplicate) {
                    CustomSnackbar.showInfo(
                      context,
                      "This skill & level is already added.",
                    );
                    return;
                  }

                  bloc.add(AddSkill(newSkill));
                  CustomSnackbar.showSuccess(context, "Skill added!");
                  Navigator.pop(context);
                },
                child: tr(
                  'SAVE',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.black : Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
