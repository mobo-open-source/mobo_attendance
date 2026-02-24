import 'dart:convert';
import 'dart:ui';

import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../CommonWidgets/core/company/infrastructure/company_refresh_bus.dart';
import '../../../../../CommonWidgets/core/company/providers/company_provider.dart';
import '../../../../../CommonWidgets/core/language/translate_widget.dart';
import '../../../../../CommonWidgets/core/navigation/data_loss_warning_dialog.dart';
import '../../../../../CommonWidgets/core/providers/language_provider.dart';
import '../../../../../CommonWidgets/core/providers/motion_provider.dart';
import '../../../../../CommonWidgets/globals.dart';
import '../../../../../CommonWidgets/shared/widgets/snackbar.dart';
import '../../../../AppBars/infrastructure/profile_refresh_bus.dart';
import '../../../../AppBars/pages/common_app_bar.dart';
import '../../SmartTabs/PrivateInfo/pages/private_info_page.dart';
import '../../SmartTabs/WorkInfo/pages/work_info_page.dart';
import '../bloc/employee_form_bloc.dart';
import '../services/employee_form_service.dart';
import '../widgets/info_row.dart';
import '../widgets/personal_info.dart';
import '../widgets/shimmer_employee_details.dart';

/// Full-screen page displaying detailed employee information and allowing editing.
///
/// Supports:
/// - View mode (read-only) and edit mode (form fields + save)
/// - Profile photo display + gallery upload in edit mode
/// - Quick actions: call work/mobile, email
/// - Resume timeline (experience/education/certificates) with add/edit/delete
/// - Skills display with progress bars and add/edit/delete
/// - HR settings (type, user link, PIN, badge generation)
/// - Navigation to sub-pages (Work Info, Private Info)
/// - Unsaved changes warning on back navigation
/// - Permission-based editing controls
class EmployeeFormPage extends StatefulWidget {
  final int employeeId;
  final String? employeeName;
  final List<int>? preAppliedEmployeeIds;
  final String? preAppliedFilterName;
  final bool? isOrg;

  const EmployeeFormPage({
    super.key,
    required this.employeeId,
    this.employeeName,
    this.preAppliedEmployeeIds,
    this.preAppliedFilterName,
    this.isOrg,
  });

  @override
  _EmployeeFormPageState createState() => _EmployeeFormPageState();
}

class _EmployeeFormPageState extends State<EmployeeFormPage> {
  bool _hasDispatched = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Load employee data only once when dependencies change
    if (!_hasDispatched) {
      _hasDispatched = true;
      context.read<EmployeeFormBloc>().add(LoadEmployee(widget.employeeId));
    }
  }

  /// Static list of employee types used in dropdowns
  final List<Map<String, String>> employeeTypes = const [
    {"key": "employee", "label": "Employee"},
    {"key": "student", "label": "Student"},
    {"key": "trainee", "label": "Trainee"},
    {"key": "contractor", "label": "Contractor"},
    {"key": "freelance", "label": "Freelancer"},
  ];

  /// Converts internal employee type key to human-readable label
  String getEmployeeTypeLabel(String? key) {
    if (key == null || key == 'false') return "N/A";
    final found = employeeTypes.firstWhere(
      (e) => e["key"] == key,
      orElse: () => {"label": "N/A"},
    );
    return found["label"] ?? "N/A";
  }

  /// Extracts display name from Odoo many2one field (usually [id, name])
  String _displayName(dynamic field) {
    if (field == null || field == false) return 'N/A';
    if (field is List && field.length > 1) return field[1].toString();
    return 'N/A';
  }

  /// Handles back navigation with different behaviors based on context
  Future<void> _handleBackNavigation(BuildContext context) async {
    final motionProvider = Provider.of<MotionProvider>(context, listen: false);

    if (widget.isOrg == true) {
      Navigator.pop(context);
      return;
    }
    if (widget.preAppliedEmployeeIds != null &&
        widget.preAppliedEmployeeIds!.isNotEmpty) {
      Navigator.pop(context);
      return;
    }

    // Default: go back to dashboard (index 1)
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const CommonAppBar(initialIndex: 1),
        transitionDuration: motionProvider.reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 300),
        reverseTransitionDuration: motionProvider.reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 300),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          if (motionProvider.reduceMotion) return child;
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  /// Opens gallery to pick and upload new profile image (base64)
  Future<void> _pickImage(BuildContext context) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      final base64 = base64Encode(bytes);
      context.read<EmployeeFormBloc>().add(UpdateProfileImage(base64));
    }
  }

  /// Safe string extraction from Odoo values (handles null/false)
  String odooStr(dynamic v, {String fallback = ''}) {
    if (v == null) return fallback;
    if (v is bool) return fallback;
    if (v is String) return v.trim();
    return v.toString();
  }

  /// Checks if Odoo field has meaningful value
  bool odooHasValue(dynamic v) {
    if (v == null || v is bool) return false;
    return v.toString().trim().isNotEmpty;
  }

  /// Safe integer parsing from Odoo values
  int? odooInt(dynamic v) {
    if (v == null || v is bool) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  /// Reusable quick action button (call, sms, email)
  Widget quickAction({
    required VoidCallback? onTap,
    required IconData icon,
    required String label,
    required Color color,
    bool isDark = false,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: 54,
            width: 54,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  blurRadius: 12,
                  color: Colors.black.withOpacity(0.08),
                ),
              ],
            ),
            child: Icon(icon, size: 20, color: color),
          ),
        ),
        const SizedBox(height: 6),
        tr(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white60 : Colors.black54,
          ),
        ),
      ],
    );
  }

  /// Helper to get translated string with fallback
  String catchTranslate(BuildContext context, String key) {
    final service = Provider.of<LanguageProvider>(context, listen: false);
    return service.getCached(key) ?? key;
  }

  /// Shows confirmation dialog before discarding unsaved changes
  Future<bool> _showUnsavedChangesDialog(context) async {
    final result = await DataLossWarningDialog.show(
      context: context,
      title: catchTranslate(context, 'Discard Changes?'),
      message: catchTranslate(
        context,
        'You have unsaved changes. Do you want to discard them?',
      ),
      confirmText: catchTranslate(context, 'Discard'),
      cancelText: catchTranslate(context, 'Keep Editing'),
    );
    return result ?? false;
  }

  /// Small icon + text row (used for job/department display)
  Widget _iconWithText({
    required IconData icon,
    required String text,
    required bool isDark,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: isDark ? Colors.white54 : Colors.black54, size: 14),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final motionProvider = Provider.of<MotionProvider>(context, listen: false);

    return BlocBuilder<EmployeeFormBloc, EmployeeFormState>(
      builder: (context, state) {
        return WillPopScope(
          onWillPop: () async {
            if (!state.isEditing) {
              _handleBackNavigation(context);
              return true;
            } else if (state.isEditing && !state.hasChanges) {
              context.read<EmployeeFormBloc>().add(CancelEdit());
            } else {
              final discard = await _showUnsavedChangesDialog(context);

              if (discard) {
                context.read<EmployeeFormBloc>().add(CancelEdit());
              }
            }
            return false;
          },
          child: Scaffold(
            backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
            appBar: AppBar(
              elevation: 0,
              backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
              surfaceTintColor: Colors.transparent,
              leading: IconButton(
                icon: Icon(
                  HugeIcons.strokeRoundedArrowLeft01,
                  color: isDark ? Colors.white : Colors.black,
                  size: 28,
                ),
                onPressed: () async {
                  final state = context.read<EmployeeFormBloc>().state;

                  if (!state.isEditing) {
                    _handleBackNavigation(context);
                  } else if (state.isEditing && !state.hasChanges) {
                    context.read<EmployeeFormBloc>().add(CancelEdit());
                  } else {
                    final discard = await _showUnsavedChangesDialog(context);
                    if (discard)
                      context.read<EmployeeFormBloc>().add(CancelEdit());
                  }
                },
              ),
              title: BlocBuilder<EmployeeFormBloc, EmployeeFormState>(
                builder: (context, state) {
                  return Text(
                    state.isEditing
                        ? catchTranslate(context, 'Edit Employee')
                        : catchTranslate(context, 'Employee Details'),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  );
                },
              ),
              actions: [
                BlocBuilder<EmployeeFormBloc, EmployeeFormState>(
                  builder: (context, state) {
                    if (state.hasEditPermission && !state.isEditing) {
                      return Row(
                        children: [
                          IconButton(
                            onPressed: () => context
                                .read<EmployeeFormBloc>()
                                .add(ToggleEditMode()),
                            tooltip: catchTranslate(context, 'Edit Employee'),
                            icon: Icon(
                              HugeIcons.strokeRoundedPencilEdit02,
                              color: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                            ),
                          ),
                          PopupMenuButton<String>(
                            position: PopupMenuPosition.under,
                            icon: Icon(
                              Icons.more_vert,
                              color: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                              size: 20,
                            ),
                            color: isDark ? Colors.grey[900] : Colors.white,
                            elevation: 8,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            itemBuilder: (context) {
                              if (state.employeeDetails?['parent_id'] == null ||
                                  state.employeeDetails?['parent_id'] == false)
                                return [
                                  PopupMenuItem(
                                    value: 'work_info',
                                    child: Row(
                                      children: [
                                        Icon(
                                          HugeIcons.strokeRoundedWork,
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 12),
                                        tr(
                                          "Work Information",
                                          style: TextStyle(
                                            fontWeight: FontWeight.w500,
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (state.hasEditPermission)
                                    PopupMenuItem(
                                      value: 'private_info',
                                      child: Row(
                                        children: [
                                          Icon(
                                            HugeIcons
                                                .strokeRoundedMessageSecure01,
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 12),
                                          tr(
                                            "Private Information",
                                            style: TextStyle(
                                              fontWeight: FontWeight.w500,
                                              color: isDark
                                                  ? Colors.white
                                                  : Colors.black,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ];
                              return [
                                PopupMenuItem(
                                  value: 'work_info',
                                  child: Row(
                                    children: [
                                      Icon(
                                        HugeIcons.strokeRoundedWork,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      tr(
                                        "Work Information",
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (state.hasEditPermission)
                                  PopupMenuItem(
                                    value: 'private_info',
                                    child: Row(
                                      children: [
                                        Icon(
                                          HugeIcons
                                              .strokeRoundedMessageSecure01,
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 12),
                                        tr(
                                          "Private Information",
                                          style: TextStyle(
                                            fontWeight: FontWeight.w500,
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ];
                            },
                            onSelected: (value) {
                              final id = state.employeeDetails!['id'];

                              switch (value) {
                                case 'work_info':
                                  Navigator.push(
                                    context,
                                    PageRouteBuilder(
                                      pageBuilder: (_, __, ___) =>
                                          WorkInfoPage(employeeId: id),
                                      transitionDuration:
                                          motionProvider.reduceMotion
                                          ? Duration.zero
                                          : const Duration(milliseconds: 300),
                                      transitionsBuilder:
                                          (_, animation, __, child) =>
                                              motionProvider.reduceMotion
                                              ? child
                                              : FadeTransition(
                                                  opacity: animation,
                                                  child: child,
                                                ),
                                    ),
                                  );
                                  break;

                                case 'private_info':
                                  Navigator.push(
                                    context,
                                    PageRouteBuilder(
                                      pageBuilder: (_, __, ___) =>
                                          PrivateInfoPage(employeeId: id),
                                      transitionDuration:
                                          motionProvider.reduceMotion
                                          ? Duration.zero
                                          : const Duration(milliseconds: 300),
                                      transitionsBuilder:
                                          (_, animation, __, child) =>
                                              motionProvider.reduceMotion
                                              ? child
                                              : FadeTransition(
                                                  opacity: animation,
                                                  child: child,
                                                ),
                                    ),
                                  );
                                  break;
                              }
                            },
                          ),
                        ],
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
            body: BlocConsumer<EmployeeFormBloc, EmployeeFormState>(
              listener: (context, state) {
                if (state.errorMessage != null) {
                  CustomSnackbar.showError(context, state.errorMessage!);
                  context.read<EmployeeFormBloc>().emit(
                    state.copyWith(clearMessage: true),
                  );
                }
                if (state.warningMessage != null) {
                  CustomSnackbar.showWarning(context, state.warningMessage!);
                  context.read<EmployeeFormBloc>().emit(
                    state.copyWith(clearMessage: true),
                  );
                }

                if (state.successMessage != null) {
                  CustomSnackbar.showSuccess(context, state.successMessage!);
                  context.read<EmployeeFormBloc>().emit(
                    state.copyWith(clearMessage: true),
                  );
                }
              },

              builder: (context, state) {
                if (state.isLoading)
                  return ShimmerEmployeeDetails(isDark: isDark);

                if (state.employeeDetails == null) {
                  return _buildCenteredLottie(
                    lottie: 'assets/empty_ghost.json',
                    title: 'No Employee found',
                    subtitle: 'Click retry to restart',
                    isDark: isDark,
                    button: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark
                            ? Colors.white
                            : AppStyle.primaryColor,
                        side: BorderSide(
                          color: isDark
                              ? Colors.grey[600]!
                              : AppStyle.primaryColor.withOpacity(0.3),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () async {
                        await context.read<CompanyProvider>().initialize();
                        ProfileRefreshBus.notifyProfileRefresh();
                        CompanyRefreshBus.notify();
                      },
                      child: tr(
                        'Clear All Filters',
                        style: TextStyle(
                          color: isDark ? Colors.white : AppStyle.primaryColor,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  );
                }

                final details = state.employeeDetails!;
                final resumeCategories =
                    details['resume_categories'] as Map<String, dynamic>? ?? {};
                final skillCategories =
                    details['skill_categories'] as Map<String, dynamic>? ?? {};

                final email = odooStr(details['work_email'], fallback: '');

                final workPhone = odooStr(details['work_phone']);
                final mobilePhone = odooStr(details['mobile_phone']);

                return Stack(
                  children: [
                    if (!state.isEditing) ...[
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── Profile Header Card ──────────────────────────────────────
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
                                padding: const EdgeInsets.all(18.0),
                                child: Column(
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        _buildProfileImage(
                                          context,
                                          state,
                                          isDark,
                                        ),
                                        const SizedBox(width: 20),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                state.employeeDetails?['name']
                                                            ?.toString()
                                                            .trim()
                                                            .isNotEmpty ==
                                                        true
                                                    ? state
                                                          .employeeDetails!['name']
                                                    : widget.employeeName,
                                                style: TextStyle(
                                                  fontSize:
                                                      state
                                                              .employeeDetails?['name']
                                                              .length >
                                                          20
                                                      ? 20
                                                      : (state
                                                                    .employeeDetails?['name']
                                                                    .length >
                                                                15
                                                            ? 22
                                                            : 24),
                                                  fontWeight: FontWeight.bold,
                                                  color: isDark
                                                      ? Colors.white
                                                      : const Color(0xFF1A1A1A),
                                                ),
                                              ),
                                              const SizedBox(height: 5),

                                              Wrap(
                                                spacing: 8,
                                                runSpacing: 6,
                                                children: [
                                                  _iconWithText(
                                                    icon: HugeIcons
                                                        .strokeRoundedNewJob,
                                                    text: _displayName(
                                                      details['job_id'],
                                                    ),
                                                    isDark: isDark,
                                                  ),
                                                  _iconWithText(
                                                    icon: HugeIcons
                                                        .strokeRoundedDepartement,
                                                    text: _displayName(
                                                      details['department_id'],
                                                    ),
                                                    isDark: isDark,
                                                  ),
                                                ],
                                              ),

                                              const SizedBox(height: 20),

                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Column(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        "Manager",
                                                        style: TextStyle(
                                                          color: isDark
                                                              ? Colors.grey[400]
                                                              : Colors
                                                                    .grey[600],
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        _displayName(
                                                          details['parent_id'],
                                                        ),
                                                        style: TextStyle(
                                                          color: isDark
                                                              ? Colors.white
                                                              : Colors.black87,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 14,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(width: 30),
                                                  Column(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        "Coach",
                                                        style: TextStyle(
                                                          color: isDark
                                                              ? Colors.grey[400]
                                                              : Colors
                                                                    .grey[600],
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        _displayName(
                                                          details['coach_id'],
                                                        ),
                                                        style: TextStyle(
                                                          color: isDark
                                                              ? Colors.white
                                                              : Colors.black87,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 14,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (odooHasValue(workPhone) ||
                                        odooHasValue(mobilePhone) ||
                                        odooHasValue(email)) ...[
                                      const SizedBox(height: 10),
                                      Divider(
                                        color: isDark
                                            ? Colors.white.withOpacity(0.1)
                                            : Colors.grey.shade200,
                                        thickness: 1,
                                        height: 1,
                                      ),
                                      const SizedBox(height: 20),
                                    ],
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceAround,
                                      children: [
                                        if (odooHasValue(workPhone))
                                          quickAction(
                                            isDark: isDark,
                                            label: "Work Call",
                                            icon: HugeIcons.strokeRoundedCall02,
                                            color: Colors.green,
                                            onTap: () => launchUrl(
                                              Uri(
                                                scheme: 'tel',
                                                path: workPhone,
                                              ),
                                            ),
                                          ),

                                        if (odooHasValue(mobilePhone))
                                          quickAction(
                                            isDark: isDark,
                                            label: "Mobile",
                                            icon: HugeIcons
                                                .strokeRoundedSmartPhone03,
                                            color: Colors.blue,
                                            onTap: () => launchUrl(
                                              Uri(
                                                scheme: 'sms',
                                                path: mobilePhone,
                                              ),
                                            ),
                                          ),

                                        if (odooHasValue(email))
                                          quickAction(
                                            isDark: isDark,
                                            label: "Email",
                                            icon: HugeIcons.strokeRoundedMail02,
                                            color: Colors.orange,
                                            onTap: () => launchUrl(
                                              Uri(
                                                scheme: 'mailto',
                                                path: email,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // ── Resume Section ────────────────────────────────────────────────
                            _buildResumeSection(
                              context,
                              state,
                              resumeCategories,
                              isDark,
                            ),
                            // ── Skills Section ────────────────────────────────────────────────
                            _buildSkillsSection(
                              context,
                              state,
                              skillCategories,
                              isDark,
                            ),
                            // ── HR Settings (visible only if permitted) ────────────────────────
                            if (state.hasEditPermission) ...[
                              _buildHRSettingsSection(
                                context,
                                state,
                                details,
                                isDark,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ] else ...[
                      // ── Edit Mode ────────────────────────────────────────────────────────
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Profile + Basic Info Card
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
                                    Center(
                                      child: _buildProfileImage(
                                        context,
                                        state,
                                        isDark,
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
                                    PersonalInfo(
                                      label: "Name",
                                      value:
                                          (state
                                                  .nameController
                                                  .text
                                                  ?.isNotEmpty ??
                                              false)
                                          ? state.nameController.text
                                          : '',
                                      isEditing: true,
                                      controller: state.nameController,
                                      onTextChanged: (_) => context
                                          .read<EmployeeFormBloc>()
                                          .add(FormFieldChanged()),
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
                                    PersonalInfo(
                                      label: "Job",
                                      value: _displayName(details['job_id']),
                                      isEditing: state.isEditing,
                                      dropdownItems: state.jobList,
                                      selectedId: state.jobId,
                                      onDropdownChanged: (v) {
                                        context.read<EmployeeFormBloc>().add(
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
                                    PersonalInfo(
                                      label: "Department",
                                      value: _displayName(
                                        details['department_id'],
                                      ),
                                      isEditing: state.isEditing,
                                      dropdownItems: state.departmentList,
                                      selectedId: state.departmentId,
                                      onDropdownChanged: (v) {
                                        context.read<EmployeeFormBloc>().add(
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
                                    PersonalInfo(
                                      label: "Email",
                                      value:
                                          (state
                                                  .emailController
                                                  .text
                                                  ?.isNotEmpty ??
                                              false)
                                          ? state.emailController.text
                                          : '',
                                      isEditing: true,
                                      controller: state.emailController,
                                      onTextChanged: (_) => context
                                          .read<EmployeeFormBloc>()
                                          .add(FormFieldChanged()),
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
                                    PersonalInfo(
                                      label: "Work Phone",

                                      value:
                                          (state
                                                  .workPhoneController
                                                  .text
                                                  ?.isNotEmpty ??
                                              false)
                                          ? state.workPhoneController.text
                                          : '',
                                      isEditing: true,
                                      controller: state.workPhoneController,
                                      onTextChanged: (_) => context
                                          .read<EmployeeFormBloc>()
                                          .add(FormFieldChanged()),
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
                                    PersonalInfo(
                                      label: "Mobile Phone",
                                      value:
                                          (state
                                                  .mobilePhoneController
                                                  .text
                                                  ?.isNotEmpty ??
                                              false)
                                          ? state.mobilePhoneController.text
                                          : '',
                                      isEditing: true,
                                      controller: state.mobilePhoneController,
                                      onTextChanged: (_) => context
                                          .read<EmployeeFormBloc>()
                                          .add(FormFieldChanged()),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Work Details Card (manager, coach, type, user, PIN, badge)
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
                                      'Work Details',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.grey[900],
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                  ),
                                  Divider(
                                    height: 1,
                                    color: isDark
                                        ? Colors.grey[700]
                                        : Colors.grey[200],
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(24.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
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
                                        InfoText(
                                          label: "Manager",
                                          value: _displayName(
                                            details['parent_id'],
                                          ),
                                          isEditing: state.isEditing,
                                          dropdownItems: state.managerCoachList,
                                          selectedId: state.managerId,

                                          onDropdownChanged: (v) {
                                            context
                                                .read<EmployeeFormBloc>()
                                                .add(UpdateManager(v?['id']));
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
                                        InfoText(
                                          label: "Coach",
                                          value: _displayName(
                                            details['coach_id'],
                                          ),
                                          isEditing: state.isEditing,
                                          dropdownItems: state.managerCoachList,
                                          selectedId: state.coachId,

                                          onDropdownChanged: (v) {
                                            context
                                                .read<EmployeeFormBloc>()
                                                .add(UpdateCoach(v?['id']));
                                          },
                                        ),
                                        const SizedBox(height: 12),
                                        tr(
                                          'Employee Type',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w400,
                                            color: isDark
                                                ? Colors.white70
                                                : const Color(0xff7F7F7F),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        InfoText(
                                          label: "Employee Type",
                                          value: getEmployeeTypeLabel(
                                            state.employeeType,
                                          ),
                                          isEditing: state.isEditing,
                                          selection: employeeTypes
                                              .map(
                                                (e) => {
                                                  "id": e["key"]!,
                                                  "name": e["label"]!,
                                                },
                                              )
                                              .toList(),
                                          selectedKey: state.employeeType,
                                          onSelectionChanged: (key) {
                                            context
                                                .read<EmployeeFormBloc>()
                                                .add(UpdateEmployeeType(key));
                                          },
                                        ),
                                        const SizedBox(height: 12),
                                        tr(
                                          'Related User',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w400,
                                            color: isDark
                                                ? Colors.white70
                                                : const Color(0xff7F7F7F),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        InfoText(
                                          label: "Related User",
                                          value: _displayName(
                                            details['user_id'],
                                          ),
                                          isEditing: state.isEditing,
                                          dropdownItems: state.userList,
                                          selectedId: state.relatedUserId,

                                          onDropdownChanged: (v) {
                                            context
                                                .read<EmployeeFormBloc>()
                                                .add(
                                                  UpdateRelatedUser(v?['id']),
                                                );
                                          },
                                        ),
                                        const SizedBox(height: 12),
                                        tr(
                                          'PIN Code',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w400,
                                            color: isDark
                                                ? Colors.white70
                                                : const Color(0xff7F7F7F),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        InfoText(
                                          label: "PIN Code",
                                          value:
                                              (state
                                                      .pinController
                                                      .text
                                                      ?.isNotEmpty ??
                                                  false)
                                              ? state.pinController.text
                                              : '',
                                          isEditing: state.isEditing,
                                          controller: state.pinController,
                                          onTextChanged: (_) => context
                                              .read<EmployeeFormBloc>()
                                              .add(FormFieldChanged()),
                                        ),
                                        const SizedBox(height: 12),
                                        tr(
                                          'Badge ID',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w400,
                                            color: isDark
                                                ? Colors.white70
                                                : const Color(0xff7F7F7F),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        InfoText(
                                          label: "Badge ID",
                                          value:
                                              (state
                                                      .badgeController
                                                      .text
                                                      ?.isNotEmpty ??
                                                  false)
                                              ? state.badgeController.text
                                              : '',
                                          isEditing: state.isEditing,
                                          controller: state.badgeController,
                                          onTextChanged: (_) => context
                                              .read<EmployeeFormBloc>()
                                              .add(FormFieldChanged()),
                                        ),
                                        if (state.badgeController.text
                                                .trim()
                                                .isEmpty ||
                                            state.badgeController.text.trim() ==
                                                'N/A') ...[
                                          const SizedBox(height: 12),
                                          TextButton(
                                            onPressed: () => context
                                                .read<EmployeeFormBloc>()
                                                .add(GenerateBadge()),
                                            child: tr(
                                              "Generate Badge",
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: isDark
                                                    ? Colors.white
                                                    : AppStyle.primaryColor,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Save Button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: (!state.isSaving && state.hasChanges)
                                    ? () => context
                                          .read<EmployeeFormBloc>()
                                          .add(SaveEmployee())
                                    : null,
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
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                    horizontal: 16,
                                  ),
                                  elevation: 0,
                                  shadowColor: Colors.transparent,
                                  disabledBackgroundColor: isDark
                                      ? Colors.grey[700]!
                                      : Colors.grey[400]!,
                                ),
                                child: tr(
                                  "Save Changes",
                                  style: TextStyle(
                                    color: isDark ? Colors.black : Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Full-screen saving overlay
                    if (state.isSaving)
                      Center(
                        child: LoadingAnimationWidget.fourRotatingDots(
                          color: isDark ? Colors.white : AppStyle.primaryColor,
                          size: 60,
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  // ── Helper Widgets & Dialogs ───────────────────────────────────────────────

  /// Centered empty state with Lottie animation and optional retry button
  Widget _buildCenteredLottie({
    required String lottie,
    required String title,
    String? subtitle,
    Widget? button,
    required bool isDark,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Lottie.asset(lottie, width: 260),
                  const SizedBox(height: 8),
                  tr(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 6),
                    tr(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                  if (button != null) ...[const SizedBox(height: 12), button],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Profile image display with edit overlay (edit mode only)
  Widget _buildProfileImage(
    BuildContext context,
    EmployeeFormState state,
    bool isDark,
  ) {
    final name = state.employeeDetails?['name']?.toString() ?? '?';
    final letter = name.isNotEmpty ? name[0].toUpperCase() : '?';

    final base64Str = state.profileImageBase64;

    if (base64Str == null || base64Str.isEmpty)
      return _placeholder(letter, isDark);

    try {
      final decodedPreview = utf8.decode(
        base64Decode(base64Str),
        allowMalformed: true,
      );
      final isSvg =
          decodedPreview.contains('<svg') || decodedPreview.contains('<?xml');
      return SizedBox(
        width: (state.isEditing) ? 90 : 70,
        height: (state.isEditing) ? 90 : 70,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            ClipOval(
              child: SizedBox(
                width: (state.isEditing) ? 90 : 70,
                height: (state.isEditing) ? 90 : 70,
                child: isSvg
                    ? SvgPicture.memory(
                        base64Decode(base64Str),
                        fit: BoxFit.cover,
                        placeholderBuilder: (_) => _placeholder(letter, isDark),
                      )
                    : Image.memory(
                        base64Decode(base64Str),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _placeholder(letter, isDark),
                      ),
              ),
            ),

            if (state.isEditing)
              Positioned(
                right: 0,
                bottom: 0,
                child: GestureDetector(
                  onTap: () => _pickImage(context),
                  child: Container(
                    height: 30,
                    width: 30,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white : AppStyle.primaryColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? Colors.black : Colors.white,
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      HugeIcons.strokeRoundedImageAdd02,
                      size: 18,
                      color: isDark ? Colors.black : Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    } catch (e) {
      return _placeholder(letter, isDark);
    }
  }

  /// Fallback placeholder avatar with initial letter
  Widget _placeholder(String letter, bool isDark) {
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        color: AppStyle.primaryColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.bold,
          color: AppStyle.primaryColor,
        ),
      ),
    );
  }

  /// Builds the entire resume section (timeline view + add button)
  Widget _buildResumeSection(
    BuildContext context,
    EmployeeFormState state,
    Map<String, dynamic> resumeCategories,
    bool isDark,
  ) {
    return Container(
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
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                tr(
                  'Resume',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                  ),
                ),
                if (state.hasEditPermission)
                  TextButton(
                    onPressed: () => _showAddResumeDialog(context, state),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: isDark ? Colors.white : Colors.black,
                      ),
                      child: tr(
                        "Add Resume",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.black : Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            if (resumeCategories.isNotEmpty) ...[
              ...resumeCategories.entries.map((entry) {
                final categoryName = entry.key;
                final categoryData = entry.value as Map<String, dynamic>;
                final categoryId = categoryData["id"] ?? 0;
                final items = categoryData["items"] as List? ?? [];

                return _buildCategorySection(
                  categoryName,
                  categoryId,
                  items,
                  isDark,
                  context,
                  state,
                );
              }).toList(),
            ] else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[800] : Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      HugeIcons.strokeRoundedNote,
                      size: 48,
                      color: isDark ? Colors.grey[600] : Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    tr(
                      'No resume added yet',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    tr(
                      'Tap "Add Resume" to get started',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.grey[500] : Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Removes HTML tags from description
  String safeHtmlStr(dynamic v) {
    if (v == null || v == false) return '';
    if (v is! String) return v.toString();

    var text = v.trim();

    if (RegExp(r'^<<.*>>$').hasMatch(text)) return '';

    text = text.replaceAll(RegExp(r'<[^>]*>'), '');

    return text;
  }

  /// Builds one resume category section with timeline items
  Widget _buildCategorySection(
    String categoryName,
    int categoryId,
    List items,
    bool isDark,
    BuildContext context,
    EmployeeFormState state,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          categoryName,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        const SizedBox(height: 16),
        ...List.generate(items.length, (index) {
          final item = items[index];
          final isLast = index == items.length - 1;
          return _buildTimelineItem(
            state.hasEditPermission,
            safeStr(item["date_start"], fallback: "No Date") +
                (safeStr(item["date_end"]).isNotEmpty
                    ? " - ${safeStr(item["date_end"])}"
                    : ""),
            safeStr(item["name"], fallback: "No Company"),
            safeHtmlStr(item["description"]),
            item['id'],
            categoryId,
            isDark,
            isFirst: index == 0,
            isLast: isLast,
            onDelete: () => context.read<EmployeeFormBloc>().add(
              DeleteResumeLine(item['id']),
            ),
            onTap: state.hasEditPermission
                ? () => _showEditResumeDialog(context, state, item, categoryId)
                : null,
          );
        }),
        const SizedBox(height: 10),
      ],
    );
  }

  /// Safe string extraction (handles null/false/empty)
  String safeStr(dynamic v, {String fallback = ''}) {
    if (v == null || v == false) return fallback;
    final s = v.toString().trim();
    return s.isEmpty ? fallback : s;
  }

  /// Builds a single timeline item in resume section
  Widget _buildTimelineItem(
    bool hasEditPermission,
    String date,
    String title,
    String subtitle,
    int lineId,
    int categoryId,
    bool isDark, {
    required bool isLast,
    required bool isFirst,
    VoidCallback? onDelete,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(left: 20),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (!isLast)
              Positioned(
                left: 5,
                top: isFirst ? 6 : 0,
                bottom: isLast ? 6 : 0,
                child: Container(
                  width: 2,
                  color: isDark
                      ? Colors.white.withOpacity(0.3)
                      : AppStyle.primaryColor.withOpacity(0.3),
                ),
              ),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      margin: EdgeInsets.only(top: 3),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white : AppStyle.primaryColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        date,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                          ),
                          if (hasEditPermission && onDelete != null)
                            IconButton(
                              icon: Icon(
                                HugeIcons.strokeRoundedDelete03,
                                size: 18,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                              onPressed: onDelete,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                        ],
                      ),
                      if (subtitle.isNotEmpty) ...[
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<String> translateText(String key) async {
    final translationService = context.read<LanguageProvider>();
    return await translationService.translate(key);
  }

  /// Dialog to add a new resume line
  void _showAddResumeDialog(BuildContext pageContext, EmployeeFormState state) {
    final translationService = context.read<LanguageProvider>();

    final bloc = pageContext.read<EmployeeFormBloc>();
    final isDark = Theme.of(pageContext).brightness == Brightness.dark;

    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    Map<String, dynamic>? selectedType;
    int? selectedTypeId;
    DateTimeRange? selectedRange;
    String? titleError;
    String? durationError;
    String? resumeError;
    bool isSaving = false;

    void resetErrors() {
      titleError = null;
      durationError = null;
      resumeError = null;
    }

    showDialog(
      context: pageContext,
      barrierDismissible: false,
      builder: (dialogContext) {
        return BlocProvider.value(
          value: bloc,
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                backgroundColor: isDark
                    ? const Color(0xFF2A2A2A)
                    : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
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
                  ],
                ),
                content: Container(
                  height: resumeError != null
                      ? MediaQuery.of(context).size.height * 0.45
                      : MediaQuery.of(context).size.height * 0.40,
                  width: MediaQuery.of(context).size.width * 0.95,
                  child: Stack(
                    children: [
                      SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 10),
                            if (resumeError != null) ...[
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  resumeError!,
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                tr(
                                  "Title",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: isDark
                                        ? Colors.white60
                                        : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                TextField(
                                  controller: titleController,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.white70
                                        : const Color(0xff000000),
                                  ),
                                  onChanged: (_) =>
                                      setDialogState(() => titleError = null),
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    hintText: "e.g. Odoo Inc.",
                                    hintStyle: TextStyle(
                                      fontWeight: FontWeight.w400,
                                      color: isDark
                                          ? Colors.white54
                                          : Colors.grey[600],
                                      fontStyle: FontStyle.italic,
                                    ),
                                    errorText: titleError,
                                    errorBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color: Colors.red[900]!,
                                      ),
                                    ),
                                    focusedErrorBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color: Colors.red[900]!,
                                      ),
                                    ),
                                    prefixIcon: Icon(
                                      HugeIcons.strokeRoundedWork,
                                      color: isDark
                                          ? Colors.grey[400]
                                          : Colors.grey[500],
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color: isDark
                                            ? Colors.white24
                                            : Colors.transparent,
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
                                    color: isDark
                                        ? Colors.white70
                                        : const Color(0xff7F7F7F),
                                  ),
                                ),
                                const SizedBox(height: 5),
                                DropdownSearch<Map<String, dynamic>>(
                                  dropdownBuilder: (context, selectedItem) {
                                    if (selectedItem == null) {
                                      return Text(
                                        "Select Type",
                                        style: TextStyle(
                                          fontWeight: FontWeight.w400,
                                          color: isDark
                                              ? Colors.white54
                                              : Colors.grey[600],
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
                                    showSearchBox: true,
                                    menuProps: MenuProps(
                                      backgroundColor: isDark
                                          ? Colors.grey[900]
                                          : Colors.grey[50],
                                      elevation: 12,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    searchFieldProps: TextFieldProps(
                                      decoration: InputDecoration(
                                        hintText: translationService.getCached(
                                          "Search Type",
                                        ),
                                        hintStyle: TextStyle(
                                          fontWeight: FontWeight.w400,
                                          color: isDark
                                              ? Colors.white54
                                              : Colors.grey[600],
                                          fontStyle: FontStyle.italic,
                                        ),
                                        prefixIcon: const Icon(Icons.search),
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                  ),
                                  items: state.resumeTypeList,
                                  itemAsString: (item) => item['name'] ?? '',
                                  selectedItem: selectedType,
                                  onChanged: (value) {
                                    setDialogState(() {
                                      selectedType = value;
                                      selectedTypeId = value?['id'];
                                    });
                                  },
                                  dropdownDecoratorProps:
                                      DropDownDecoratorProps(
                                        dropdownSearchDecoration:
                                            InputDecoration(
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 8,
                                                  ),
                                              hintText: translationService
                                                  .getCached('Select Type'),
                                              hintStyle: TextStyle(
                                                fontWeight: FontWeight.w400,
                                                color: isDark
                                                    ? Colors.white54
                                                    : Colors.grey[600],
                                                fontStyle: FontStyle.italic,
                                              ),
                                              prefixIcon: Icon(
                                                HugeIcons.strokeRoundedTask01,
                                                color: isDark
                                                    ? Colors.white70
                                                    : const Color(0xff7F7F7F),
                                              ),
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              enabledBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                borderSide: BorderSide(
                                                  color: isDark
                                                      ? Colors.white24
                                                      : Colors.transparent,
                                                  width: 1.5,
                                                ),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
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
                                    color: isDark
                                        ? Colors.white70
                                        : const Color(0xff7F7F7F),
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
                                      setDialogState(() {
                                        selectedRange = range;
                                        durationError = null;
                                      });
                                    }
                                  },
                                  child: InputDecorator(
                                    decoration: InputDecoration(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                      hintText: translationService.getCached(
                                        'Select Date →',
                                      ),
                                      hintStyle: TextStyle(
                                        fontWeight: FontWeight.w400,
                                        color: isDark
                                            ? Colors.white54
                                            : Colors.grey[600],
                                        fontStyle: FontStyle.italic,
                                      ),
                                      errorText: durationError,
                                      prefixIcon: Icon(
                                        Icons.calendar_month,
                                        color: isDark
                                            ? Colors.grey[400]
                                            : Colors.grey[500],
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                          color: isDark
                                              ? Colors.white24
                                              : Colors.transparent,
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
                                      selectedRange == null
                                          ? translationService.getCached(
                                                  "Select Date →",
                                                ) ??
                                                "Select Date →"
                                          : "${selectedRange!.start.toString().split(' ')[0]} → ${selectedRange!.end.toString().split(' ')[0]}",
                                      style: selectedRange == null
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
                                    color: isDark
                                        ? Colors.white70
                                        : const Color(0xff7F7F7F),
                                  ),
                                ),
                                const SizedBox(height: 5),
                                TextField(
                                  controller: descriptionController,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.white70
                                        : const Color(0xff000000),
                                  ),
                                  maxLines: 3,
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color: isDark
                                            ? Colors.white24
                                            : Colors.transparent,
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
                                    hintStyle: TextStyle(
                                      fontWeight: FontWeight.w400,
                                      color: isDark
                                          ? Colors.white54
                                          : Colors.grey[600],
                                      fontStyle: FontStyle.italic,
                                    ),
                                    hintText: translationService.getCached(
                                      "Enter description...",
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (isSaving)
                        Center(
                          child: LoadingAnimationWidget.fourRotatingDots(
                            color: isDark
                                ? Colors.white
                                : AppStyle.primaryColor,
                            size: 60,
                          ),
                        ),
                    ],
                  ),
                ),
                actions: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: isDark
                                ? Colors.white
                                : Colors.black87,
                            backgroundColor: isDark
                                ? Colors.grey[800]
                                : Colors.white,
                            side: BorderSide(
                              color: isDark
                                  ? Colors.white
                                  : AppStyle.primaryColor,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: tr(
                            "CLOSE",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.white
                                  : AppStyle.primaryColor,
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
                            foregroundColor: isDark
                                ? Colors.black
                                : Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: isSaving
                              ? null
                              : () async {
                                  setDialogState(() {
                                    resetErrors();
                                    titleError =
                                        titleController.text.trim().isEmpty
                                        ? "${translationService.getCached('Title is required')}"
                                        : null;
                                    durationError = selectedRange == null
                                        ? "${translationService.getCached('Duration is required')}"
                                        : null;
                                    isSaving = true;
                                  });

                                  if (titleError != null ||
                                      durationError != null) {
                                    setDialogState(() => isSaving = false);
                                    return;
                                  }

                                  final data = {
                                    "employee_id": state.employeeDetails!['id'],
                                    "name": titleController.text.trim(),
                                    "line_type_id": selectedTypeId,
                                    "date_start": selectedRange!.start
                                        .toString()
                                        .split(' ')[0],
                                    "date_end": selectedRange!.end
                                        .toString()
                                        .split(' ')[0],
                                    "description": descriptionController.text
                                        .trim(),
                                  };

                                  pageContext.read<EmployeeFormBloc>().add(
                                    AddResumeLine(data),
                                  );

                                  Navigator.pop(dialogContext);
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
            },
          ),
        );
      },
    );
  }

  String safeDate(dynamic v) {
    if (v == null || v == false || v.toString().isEmpty) return "";
    return v.toString();
  }

  /// Dialog to edit an existing resume line
  void _showEditResumeDialog(
    BuildContext pageContext,
    EmployeeFormState state,
    Map<String, dynamic> item,
    int categoryId,
  ) {
    final bloc = pageContext.read<EmployeeFormBloc>();

    final isDark = Theme.of(pageContext).brightness == Brightness.dark;
    String initialStart = safeDate(item["date_start"]);
    String initialEnd = safeDate(item["date_end"]);

    DateTimeRange? initialRange;

    if (initialStart.isNotEmpty && initialEnd.isNotEmpty) {
      try {
        final startDate = DateTime.parse(initialStart);
        final endDate = DateTime.parse(initialEnd);
        initialRange = DateTimeRange(start: startDate, end: endDate);
      } catch (_) {
        initialRange = null;
      }
    }

    final titleController = TextEditingController(text: safeStr(item["name"]));

    final descriptionController = TextEditingController(
      text: safeStr(item["description"]),
    );

    Map<String, dynamic>? selectedType;
    int? selectedTypeId = categoryId;
    DateTimeRange? selectedRange = initialRange;
    String date_start = initialStart;
    String date_end = initialEnd;

    String? titleError;
    String? durationError;
    String? resumeError;
    bool isSaving = false;

    selectedType = {
      'id': categoryId,
      'name': item["line_type_id"] is List ? item["line_type_id"][1] : "Others",
    };

    void resetErrors() {
      titleError = null;
      durationError = null;
      resumeError = null;
    }

    final translationService = context.read<LanguageProvider>();
    showDialog(
      context: pageContext,
      barrierDismissible: false,
      builder: (dialogContext) {
        return BlocProvider.value(
          value: bloc,
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                backgroundColor: isDark
                    ? const Color(0xFF2A2A2A)
                    : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    tr(
                      "Edit resume line",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ],
                ),
                content: Container(
                  height: resumeError != null
                      ? MediaQuery.of(context).size.height * 0.45
                      : MediaQuery.of(context).size.height * 0.40,
                  width: MediaQuery.of(context).size.width * 0.95,
                  child: Stack(
                    children: [
                      SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 10),
                            if (resumeError != null) ...[
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  resumeError!,
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],

                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                tr(
                                  "Title",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: isDark
                                        ? Colors.white60
                                        : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                TextField(
                                  controller: titleController,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.white70
                                        : const Color(0xff000000),
                                  ),
                                  onChanged: (_) =>
                                      setDialogState(() => titleError = null),
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    hintText: "e.g. Odoo Inc.",
                                    hintStyle: TextStyle(
                                      fontWeight: FontWeight.w400,
                                      color: isDark
                                          ? Colors.white54
                                          : Colors.grey[600],
                                      fontStyle: FontStyle.italic,
                                    ),
                                    errorText: titleError,
                                    errorBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color: Colors.red[900]!,
                                      ),
                                    ),
                                    focusedErrorBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color: Colors.red[900]!,
                                      ),
                                    ),
                                    prefixIcon: Icon(
                                      HugeIcons.strokeRoundedWork,
                                      color: isDark
                                          ? Colors.grey[400]
                                          : Colors.grey[500],
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color: isDark
                                            ? Colors.white24
                                            : Colors.transparent,
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
                                    color: isDark
                                        ? Colors.white70
                                        : const Color(0xff7F7F7F),
                                  ),
                                ),
                                const SizedBox(height: 5),
                                DropdownSearch<Map<String, dynamic>>(
                                  dropdownBuilder: (context, selectedItem) {
                                    if (selectedItem == null) {
                                      return Text(
                                        "Select Type",
                                        style: TextStyle(
                                          fontWeight: FontWeight.w400,
                                          color: isDark
                                              ? Colors.white54
                                              : Colors.grey[600],
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
                                    showSearchBox: true,
                                    menuProps: MenuProps(
                                      backgroundColor: isDark
                                          ? Colors.grey[900]
                                          : Colors.grey[50],
                                      elevation: 12,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    searchFieldProps: TextFieldProps(
                                      decoration: InputDecoration(
                                        hintText: translationService.getCached(
                                          "Search Type",
                                        ),
                                        hintStyle: TextStyle(
                                          fontWeight: FontWeight.w400,
                                          color: isDark
                                              ? Colors.white54
                                              : Colors.grey[600],
                                          fontStyle: FontStyle.italic,
                                        ),
                                        prefixIcon: const Icon(Icons.search),
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                  ),
                                  items: state.resumeTypeList,
                                  itemAsString: (item) => item['name'] ?? '',
                                  selectedItem: selectedType,
                                  onChanged: (value) {
                                    setDialogState(() {
                                      selectedType = value;
                                      selectedTypeId = value?['id'];
                                    });
                                  },
                                  dropdownDecoratorProps:
                                      DropDownDecoratorProps(
                                        dropdownSearchDecoration:
                                            InputDecoration(
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 8,
                                                  ),
                                              hintText: translationService
                                                  .getCached('Select Type'),
                                              hintStyle: TextStyle(
                                                fontWeight: FontWeight.w400,
                                                color: isDark
                                                    ? Colors.white54
                                                    : Colors.grey[600],
                                                fontStyle: FontStyle.italic,
                                              ),
                                              prefixIcon: Icon(
                                                HugeIcons.strokeRoundedTask01,
                                                color: isDark
                                                    ? Colors.white70
                                                    : const Color(0xff7F7F7F),
                                              ),
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              enabledBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                borderSide: BorderSide(
                                                  color: isDark
                                                      ? Colors.white24
                                                      : Colors.transparent,
                                                  width: 1.5,
                                                ),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
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
                                    color: isDark
                                        ? Colors.white70
                                        : const Color(0xff7F7F7F),
                                  ),
                                ),
                                const SizedBox(height: 5),
                                InkWell(
                                  onTap: () async {
                                    final range = await showDateRangePicker(
                                      context: context,
                                      firstDate: DateTime(1990),
                                      lastDate: DateTime(2100),
                                      initialDateRange: selectedRange,
                                    );
                                    if (range != null) {
                                      setDialogState(() {
                                        selectedRange = range;
                                        date_start = range.start
                                            .toString()
                                            .split(' ')[0];
                                        date_end = range.end.toString().split(
                                          ' ',
                                        )[0];
                                        durationError = null;
                                      });
                                    }
                                  },
                                  child: InputDecorator(
                                    decoration: InputDecoration(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                      hintText: translationService.getCached(
                                        'Select Date →',
                                      ),
                                      hintStyle: TextStyle(
                                        fontWeight: FontWeight.w400,
                                        color: isDark
                                            ? Colors.white54
                                            : Colors.grey[600],
                                        fontStyle: FontStyle.italic,
                                      ),
                                      errorText: durationError,
                                      prefixIcon: Icon(
                                        Icons.calendar_month,
                                        color: isDark
                                            ? Colors.grey[400]
                                            : Colors.grey[500],
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                          color: isDark
                                              ? Colors.white24
                                              : Colors.transparent,
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
                                      selectedRange == null
                                          ? translationService.getCached(
                                                  "Select Date →",
                                                ) ??
                                                "Select Date →"
                                          : "${selectedRange!.start.toString().split(' ')[0]} → ${selectedRange!.end.toString().split(' ')[0]}",
                                      style: selectedRange == null
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
                                    color: isDark
                                        ? Colors.white70
                                        : const Color(0xff7F7F7F),
                                  ),
                                ),
                                const SizedBox(height: 5),
                                TextField(
                                  controller: descriptionController,
                                  maxLines: 3,
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color: isDark
                                            ? Colors.white24
                                            : Colors.transparent,
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
                                    hintStyle: TextStyle(
                                      fontWeight: FontWeight.w400,
                                      color: isDark
                                          ? Colors.white54
                                          : Colors.grey[600],
                                      fontStyle: FontStyle.italic,
                                    ),
                                    hintText: translationService.getCached(
                                      "Enter description...",
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (isSaving)
                        Center(
                          child: LoadingAnimationWidget.fourRotatingDots(
                            color: isDark
                                ? Colors.white
                                : AppStyle.primaryColor,
                            size: 60,
                          ),
                        ),
                    ],
                  ),
                ),
                actions: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: isDark
                                ? Colors.white
                                : Colors.black87,
                            backgroundColor: isDark
                                ? Colors.grey[800]
                                : Colors.white,
                            side: BorderSide(
                              color: isDark
                                  ? Colors.white
                                  : AppStyle.primaryColor,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: tr(
                            "CLOSE",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.white
                                  : AppStyle.primaryColor,
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
                            foregroundColor: isDark
                                ? Colors.black
                                : Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: isSaving
                              ? null
                              : () async {
                                  setDialogState(() {
                                    resetErrors();
                                    titleError =
                                        titleController.text.trim().isEmpty
                                        ? "${translationService.getCached('Title is required')}"
                                        : null;
                                    durationError = selectedRange == null
                                        ? "${translationService.getCached('Duration is required')}"
                                        : null;
                                    isSaving = true;
                                  });

                                  if (titleError != null ||
                                      durationError != null) {
                                    setDialogState(() => isSaving = false);
                                    return;
                                  }

                                  final data = {
                                    "name": titleController.text.trim(),
                                    "line_type_id": selectedTypeId,
                                    "date_start": date_start,
                                    "date_end": date_end,
                                    "description": descriptionController.text
                                        .trim(),
                                  };

                                  pageContext.read<EmployeeFormBloc>().add(
                                    UpdateResumeLine(item['id'], data),
                                  );

                                  Navigator.pop(dialogContext);
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
            },
          ),
        );
      },
    );
  }

  /// Builds the skills section with category grouping and progress bars
  Widget _buildSkillsSection(
    BuildContext context,
    EmployeeFormState state,
    Map<String, dynamic> skillCategories,
    bool isDark,
  ) {
    return Container(
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
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                tr(
                  'Skills',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                  ),
                ),
                if (state.hasEditPermission)
                  TextButton(
                    onPressed: () => _showAddSkillDialog(context, state),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: isDark ? Colors.white : Colors.black,
                      ),
                      child: tr(
                        "Add Skill",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.black : Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (skillCategories.isNotEmpty) ...[
              ...skillCategories.entries.map((entry) {
                final categoryName = entry.key;
                final skills = entry.value as List<dynamic>;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      categoryName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 15),
                    ...skills
                        .map(
                          (skill) => _buildSkillItem(
                            state.hasEditPermission,
                            skill["name"] ?? "Unknown",
                            skill["level"] ?? "N/A",
                            skill["progress"] ?? 0,
                            isDark,
                            onDelete: () => context
                                .read<EmployeeFormBloc>()
                                .add(DeleteSkill(skill['id'])),
                            onTap: state.hasEditPermission
                                ? () => _showEditSkillDialog(
                                    context,
                                    state,
                                    skill,
                                  )
                                : null,
                          ),
                        )
                        .toList(),
                    const SizedBox(height: 16),
                  ],
                );
              }).toList(),
            ] else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[800] : Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      HugeIcons.strokeRoundedNote,
                      size: 48,
                      color: isDark ? Colors.grey[600] : Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    tr(
                      'No skill added yet',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    tr(
                      'Tap "Add Skill" to get started',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.grey[500] : Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Builds a single skill item with progress bar and delete/edit actions
  Widget _buildSkillItem(
    bool hasEditPermission,
    String skillName,
    String level,
    int percent,
    bool isDark, {
    VoidCallback? onDelete,
    VoidCallback? onTap,
  }) {
    final skillContent = Padding(
      padding: const EdgeInsets.only(bottom: 10.0, left: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white : Colors.black87,
                  shape: BoxShape.circle,
                ),
              ),
              Expanded(
                child: Text(
                  skillName,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                level,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: percent / 100,
                    minHeight: 6,
                    backgroundColor: isDark
                        ? Colors.white12
                        : AppStyle.primaryColor.withOpacity(0.3),
                    valueColor: AlwaysStoppedAnimation(
                      isDark ? Colors.white70 : AppStyle.primaryColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                "$percent%",
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white : AppStyle.primaryColor,
                ),
              ),
              if (hasEditPermission && onDelete != null)
                IconButton(
                  icon: Icon(
                    HugeIcons.strokeRoundedDelete03,
                    size: 18,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                  onPressed: onDelete,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
        ],
      ),
    );

    if (hasEditPermission) {
      return InkWell(onTap: onTap, child: skillContent);
    } else {
      return Tooltip(
        message: skillName,
        triggerMode: TooltipTriggerMode.tap,
        waitDuration: const Duration(milliseconds: 300),
        showDuration: const Duration(seconds: 2),
        preferBelow: false,
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        child: skillContent,
      );
    }
  }

  /// Dialog to add a new skill
  void _showAddSkillDialog(BuildContext pageContext, EmployeeFormState state) {
    final isDark = Theme.of(pageContext).brightness == Brightness.dark;
    final EmployeeFormService _employeeService = EmployeeFormService();

    Map<String, dynamic>? selectedSkillType;
    int? selectedSkillTypeId;
    List<Map<String, dynamic>> skills = [];
    Map<String, dynamic>? selectedSkill;
    int? selectedSkillId;
    List<Map<String, dynamic>> skillLevels = [];
    Map<String, dynamic>? selectedSkillLevel;
    int? selectedSkillLevelId;

    String? skillError;
    bool isSaving = false;

    void resetError() {
      skillError = null;
    }

    Future<void> loadInitialOptions() async {
      if (state.skillTypeList.isEmpty) return;

      selectedSkillType = state.skillTypeList.first;
      selectedSkillTypeId = selectedSkillType!['id'];

      final skillIds = selectedSkillType!['skill_ids'];
      if (skillIds is List && skillIds.isNotEmpty) {
        skills = await _employeeService.fetchSkill(skillIds);
        if (skills.isNotEmpty) {
          selectedSkill = skills.first;
          selectedSkillId = selectedSkill!['id'];
        }
      } else {
        skills = [];
        selectedSkill = null;
        selectedSkillId = null;
      }

      final skillLevelIds = selectedSkillType!['skill_level_ids'];
      if (skillLevelIds is List && skillLevelIds.isNotEmpty) {
        skillLevels = await _employeeService.fetchSkillLevel(skillLevelIds);
        if (skillLevels.isNotEmpty) {
          selectedSkillLevel = skillLevels.first;
          selectedSkillLevelId = selectedSkillLevel!['id'];
        }
      } else {
        skillLevels = [];
        selectedSkillLevel = null;
        selectedSkillLevelId = null;
      }
    }

    final translationService = context.read<LanguageProvider>();

    showDialog(
      context: pageContext,
      barrierDismissible: false,
      builder: (dialogContext) {
        bool initialized = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            if (!initialized) {
              initialized = true;
              loadInitialOptions().then((_) => setDialogState(() {}));
            }
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
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
                ],
              ),
              content: Container(
                height: skillError != null
                    ? MediaQuery.of(context).size.height * 0.32
                    : MediaQuery.of(context).size.height * 0.28,
                width: MediaQuery.of(context).size.width * 0.95,
                child: Stack(
                  children: [
                    SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 10),
                          if (skillError != null) ...[
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                skillError!,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              tr(
                                "Skill Type",
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: isDark
                                      ? Colors.white60
                                      : Colors.black87,
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
                                        color: isDark
                                            ? Colors.white54
                                            : Colors.grey[600],
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
                                  showSearchBox: true,
                                  menuProps: MenuProps(
                                    backgroundColor: isDark
                                        ? Colors.grey[900]
                                        : Colors.grey[50],
                                    elevation: 12,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  searchFieldProps: TextFieldProps(
                                    decoration: InputDecoration(
                                      hintText: translationService.getCached(
                                        "Search Skill Type",
                                      ),
                                      hintStyle: TextStyle(
                                        fontWeight: FontWeight.w400,
                                        color: isDark
                                            ? Colors.white54
                                            : Colors.grey[600],
                                        fontStyle: FontStyle.italic,
                                      ),
                                      prefixIcon: const Icon(Icons.search),
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                                items: state.skillTypeList,
                                itemAsString: (item) => item['name'] ?? '',
                                selectedItem: selectedSkillType,
                                onChanged: (value) async {
                                  setDialogState(() {
                                    selectedSkillType = value;
                                    selectedSkillTypeId = value?['id'];
                                    skills = [];
                                    selectedSkill = null;
                                    selectedSkillId = null;
                                    skillLevels = [];
                                    selectedSkillLevel = null;
                                    selectedSkillLevelId = null;
                                  });

                                  if (value == null) return;

                                  await _employeeService.initializeClient();
                                  final fetchedSkills = await _employeeService
                                      .fetchSkill(value['skill_ids'] ?? []);
                                  final fetchedLevels = await _employeeService
                                      .fetchSkillLevel(
                                        value['skill_level_ids'] ?? [],
                                      );

                                  setDialogState(() {
                                    skills = fetchedSkills;
                                    if (fetchedSkills.isNotEmpty) {
                                      selectedSkill = fetchedSkills.first;
                                      selectedSkillId = selectedSkill!['id'];
                                    }
                                    skillLevels = fetchedLevels;
                                    if (fetchedLevels.isNotEmpty) {
                                      selectedSkillLevel = fetchedLevels.first;
                                      selectedSkillLevelId =
                                          selectedSkillLevel!['id'];
                                    }
                                  });
                                },
                                dropdownDecoratorProps: DropDownDecoratorProps(
                                  dropdownSearchDecoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    hintText: translationService.getCached(
                                      'Select Skill Type',
                                    ),
                                    hintStyle: TextStyle(
                                      fontWeight: FontWeight.w400,
                                      color: isDark
                                          ? Colors.white54
                                          : Colors.grey[600],
                                      fontStyle: FontStyle.italic,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color: isDark
                                            ? Colors.white24
                                            : Colors.transparent,
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
                                  color: isDark
                                      ? Colors.white60
                                      : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 5),
                              DropdownSearch<Map<String, dynamic>>(
                                dropdownBuilder: (context, selectedItem) {
                                  if (selectedItem == null) {
                                    return Text(
                                      "Select Skill",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w400,
                                        color: isDark
                                            ? Colors.white54
                                            : Colors.grey[600],
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
                                  showSearchBox: true,
                                  menuProps: MenuProps(
                                    backgroundColor: isDark
                                        ? Colors.grey[900]
                                        : Colors.grey[50],
                                    elevation: 12,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  searchFieldProps: TextFieldProps(
                                    decoration: InputDecoration(
                                      hintText: translationService.getCached(
                                        "Search Skill",
                                      ),
                                      hintStyle: TextStyle(
                                        fontWeight: FontWeight.w400,
                                        color: isDark
                                            ? Colors.white54
                                            : Colors.grey[600],
                                        fontStyle: FontStyle.italic,
                                      ),
                                      prefixIcon: const Icon(Icons.search),
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                                items: skills,
                                itemAsString: (item) => item['name'] ?? '',
                                selectedItem: selectedSkill,
                                onChanged: (value) {
                                  setDialogState(() {
                                    selectedSkill = value;
                                    selectedSkillId = value?['id'];
                                  });
                                },
                                dropdownDecoratorProps: DropDownDecoratorProps(
                                  dropdownSearchDecoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    hintText: translationService.getCached(
                                      'Select Skill',
                                    ),
                                    hintStyle: TextStyle(
                                      fontWeight: FontWeight.w400,
                                      color: isDark
                                          ? Colors.white54
                                          : Colors.grey[600],
                                      fontStyle: FontStyle.italic,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color: isDark
                                            ? Colors.white24
                                            : Colors.transparent,
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
                                  color: isDark
                                      ? Colors.white60
                                      : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 5),
                              DropdownSearch<Map<String, dynamic>>(
                                dropdownBuilder: (context, selectedItem) {
                                  if (selectedItem == null) {
                                    return Text(
                                      "Select Level",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w400,
                                        color: isDark
                                            ? Colors.white54
                                            : Colors.grey[600],
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
                                  showSearchBox: true,
                                  menuProps: MenuProps(
                                    backgroundColor: isDark
                                        ? Colors.grey[900]
                                        : Colors.grey[50],
                                    elevation: 12,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  searchFieldProps: TextFieldProps(
                                    decoration: InputDecoration(
                                      hintText: translationService.getCached(
                                        "Search Skill Level",
                                      ),
                                      hintStyle: TextStyle(
                                        fontWeight: FontWeight.w400,
                                        color: isDark
                                            ? Colors.white54
                                            : Colors.grey[600],
                                        fontStyle: FontStyle.italic,
                                      ),
                                      prefixIcon: const Icon(Icons.search),
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                                items: skillLevels,
                                itemAsString: (item) => item['name'] ?? '',
                                selectedItem: selectedSkillLevel,
                                onChanged: (value) {
                                  setDialogState(() {
                                    selectedSkillLevel = value;
                                    selectedSkillLevelId = value?['id'];
                                  });
                                },
                                dropdownDecoratorProps: DropDownDecoratorProps(
                                  dropdownSearchDecoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    hintText: translationService.getCached(
                                      'Select Skill Level',
                                    ),
                                    hintStyle: TextStyle(
                                      fontWeight: FontWeight.w400,
                                      color: isDark
                                          ? Colors.white54
                                          : Colors.grey[600],
                                      fontStyle: FontStyle.italic,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color: isDark
                                            ? Colors.white24
                                            : Colors.transparent,
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
                    if (isSaving)
                      Center(
                        child: LoadingAnimationWidget.fourRotatingDots(
                          color: isDark ? Colors.white : AppStyle.primaryColor,
                          size: 60,
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isDark
                              ? Colors.white
                              : Colors.black87,
                          backgroundColor: isDark
                              ? Colors.grey[800]
                              : Colors.white,
                          side: BorderSide(
                            color: isDark
                                ? Colors.white
                                : AppStyle.primaryColor,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: tr(
                          "CLOSE",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.white
                                : AppStyle.primaryColor,
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
                        onPressed: isSaving
                            ? null
                            : () async {
                                setDialogState(() {
                                  resetError();
                                  isSaving = true;
                                });

                                if (selectedSkillTypeId == null ||
                                    selectedSkillId == null ||
                                    selectedSkillLevelId == null) {
                                  setDialogState(() {
                                    skillError =
                                        "${translationService.getCached('Please select skill type, skill, and level')}";
                                    isSaving = false;
                                  });
                                  return;
                                }
                                final skillCategories =
                                    state.employeeDetails?['skill_categories']
                                        as Map<String, dynamic>?;
                                bool alreadyExists = false;
                                if (skillCategories != null) {
                                  for (var category in skillCategories.values) {
                                    if (category is List) {
                                      for (var skill in category) {
                                        if (skill['skillId'] ==
                                            selectedSkillId) {
                                          alreadyExists = true;
                                          break;
                                        }
                                      }
                                    }
                                    if (alreadyExists) break;
                                  }
                                }

                                if (alreadyExists) {
                                  setDialogState(() {
                                    skillError =
                                        "${translationService.getCached('Two levels for the same skill is not allowed')}";
                                    isSaving = false;
                                  });
                                  return;
                                }

                                final data = {
                                  "employee_id": state.employeeDetails!['id'],
                                  "skill_id": selectedSkillId,
                                  "skill_level_id": selectedSkillLevelId,
                                  "skill_type_id": selectedSkillTypeId,
                                };
                                pageContext.read<EmployeeFormBloc>().add(
                                  AddSkill(data),
                                );

                                Navigator.pop(dialogContext);
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
          },
        );
      },
    );
  }

  /// Dialog to edit an existing skill
  void _showEditSkillDialog(
    BuildContext pageContext,
    EmployeeFormState state,
    Map<String, dynamic> skill,
  ) {
    final isDark = Theme.of(pageContext).brightness == Brightness.dark;
    final employeeService = EmployeeFormService();
    final String currentType = skill["type"] ?? "Others";
    final int currentSkillId = skill["skillId"] ?? 0;
    final String currentLevel = skill["level"] ?? "N/A";

    Map<String, dynamic>? selectedSkillType;
    int? selectedSkillTypeId;
    List<Map<String, dynamic>> skills = [];
    Map<String, dynamic>? selectedSkill;
    int? selectedSkillId = currentSkillId;
    List<Map<String, dynamic>> skillLevels = [];
    Map<String, dynamic>? selectedSkillLevel;
    int? selectedSkillLevelId;

    String? skillError;
    bool isSaving = false;

    selectedSkillType = state.skillTypeList.firstWhere(
      (item) => item['name'] == currentType,
      orElse: () => <String, dynamic>{},
    );
    selectedSkillTypeId = selectedSkillType!['id'];

    void resetError() {
      skillError = null;
    }

    Future<void> loadInitialOptions() async {
      if (selectedSkillTypeId == null) return;

      final fetchedSkills = await employeeService.fetchSkill(
        selectedSkillType?['skill_ids'] ?? [],
      );
      final fetchedLevels = await employeeService.fetchSkillLevel(
        selectedSkillType?['skill_level_ids'] ?? [],
      );

      skills = fetchedSkills;
      skillLevels = fetchedLevels;

      selectedSkill = fetchedSkills.firstWhere(
        (s) => s['id'] == currentSkillId,
        orElse: () => {
          'id': currentSkillId,
          'name': skill["name"] ?? "Unknown",
        },
      );
      selectedSkillId = currentSkillId;

      selectedSkillLevel = fetchedLevels.firstWhere(
        (l) => l['name'] == currentLevel,
        orElse: () => {'name': currentLevel},
      );
      selectedSkillLevelId = skill["skill_level_id"] is List
          ? skill["skill_level_id"][0]
          : null;
    }

    final translationService = context.read<LanguageProvider>();
    showDialog(
      context: pageContext,
      barrierDismissible: false,
      builder: (dialogContext) {
        bool initialized = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            if (!initialized) {
              initialized = true;
              loadInitialOptions().then((_) => setDialogState(() {}));
            }
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              content: Container(
                height: skillError != null
                    ? MediaQuery.of(context).size.height * 0.32
                    : MediaQuery.of(context).size.height * 0.28,
                width: MediaQuery.of(context).size.width * 0.95,
                child: Stack(
                  children: [
                    SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 10),
                          if (skillError != null) ...[
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                skillError!,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],

                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              tr(
                                "Skill Type",
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: isDark
                                      ? Colors.white60
                                      : Colors.black87,
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
                                        color: isDark
                                            ? Colors.white54
                                            : Colors.grey[600],
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
                                  showSearchBox: true,
                                  menuProps: MenuProps(
                                    backgroundColor: isDark
                                        ? Colors.grey[900]
                                        : Colors.grey[50],
                                    elevation: 12,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  searchFieldProps: TextFieldProps(
                                    decoration: InputDecoration(
                                      hintText: translationService.getCached(
                                        "Search Skill Type",
                                      ),
                                      hintStyle: TextStyle(
                                        fontWeight: FontWeight.w400,
                                        color: isDark
                                            ? Colors.white54
                                            : Colors.grey[600],
                                        fontStyle: FontStyle.italic,
                                      ),
                                      prefixIcon: const Icon(Icons.search),
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                                items: state.skillTypeList,
                                itemAsString: (item) => item['name'] ?? '',
                                selectedItem: selectedSkillType,
                                onChanged: (value) async {
                                  setDialogState(() {
                                    selectedSkillType = value;
                                    selectedSkillTypeId = value?['id'];
                                    skills = [];
                                    selectedSkill = null;
                                    selectedSkillId = null;
                                    skillLevels = [];
                                    selectedSkillLevel = null;
                                    selectedSkillLevelId = null;
                                  });

                                  if (value == null) return;

                                  await employeeService.initializeClient();
                                  final fetchedSkills = await employeeService
                                      .fetchSkill(value['skill_ids'] ?? []);
                                  final fetchedLevels = await employeeService
                                      .fetchSkillLevel(
                                        value['skill_level_ids'] ?? [],
                                      );

                                  setDialogState(() {
                                    skills = fetchedSkills;
                                    if (fetchedSkills.isNotEmpty) {
                                      selectedSkill = fetchedSkills.first;
                                      selectedSkillId = selectedSkill!['id'];
                                    }
                                    skillLevels = fetchedLevels;
                                    if (fetchedLevels.isNotEmpty) {
                                      selectedSkillLevel = fetchedLevels.first;
                                      selectedSkillLevelId =
                                          selectedSkillLevel!['id'];
                                    }
                                  });
                                },
                                dropdownDecoratorProps: DropDownDecoratorProps(
                                  dropdownSearchDecoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    hintText: translationService.getCached(
                                      'Select Skill Type',
                                    ),
                                    hintStyle: TextStyle(
                                      fontWeight: FontWeight.w400,
                                      color: isDark
                                          ? Colors.white54
                                          : Colors.grey[600],
                                      fontStyle: FontStyle.italic,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color: isDark
                                            ? Colors.white24
                                            : Colors.transparent,
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
                                  color: isDark
                                      ? Colors.white60
                                      : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 5),
                              DropdownSearch<Map<String, dynamic>>(
                                dropdownBuilder: (context, selectedItem) {
                                  if (selectedItem == null) {
                                    return Text(
                                      "Select Skill",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w400,
                                        color: isDark
                                            ? Colors.white54
                                            : Colors.grey[600],
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
                                  showSearchBox: true,
                                  menuProps: MenuProps(
                                    backgroundColor: isDark
                                        ? Colors.grey[900]
                                        : Colors.grey[50],
                                    elevation: 12,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  searchFieldProps: TextFieldProps(
                                    decoration: InputDecoration(
                                      hintText: translationService.getCached(
                                        "Search Skill",
                                      ),
                                      hintStyle: TextStyle(
                                        fontWeight: FontWeight.w400,
                                        color: isDark
                                            ? Colors.white54
                                            : Colors.grey[600],
                                        fontStyle: FontStyle.italic,
                                      ),
                                      prefixIcon: const Icon(Icons.search),
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                                items: skills,
                                itemAsString: (item) => item['name'] ?? '',
                                selectedItem: selectedSkill,
                                onChanged: (value) {
                                  setDialogState(() {
                                    selectedSkill = value;
                                    selectedSkillId = value?['id'];
                                  });
                                },
                                dropdownDecoratorProps: DropDownDecoratorProps(
                                  dropdownSearchDecoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    hintText: translationService.getCached(
                                      'Select Skill',
                                    ),
                                    hintStyle: TextStyle(
                                      fontWeight: FontWeight.w400,
                                      color: isDark
                                          ? Colors.white54
                                          : Colors.grey[600],
                                      fontStyle: FontStyle.italic,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color: isDark
                                            ? Colors.white24
                                            : Colors.transparent,
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
                                  color: isDark
                                      ? Colors.white60
                                      : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 5),
                              DropdownSearch<Map<String, dynamic>>(
                                popupProps: PopupProps.menu(
                                  showSearchBox: true,
                                  menuProps: MenuProps(
                                    backgroundColor: isDark
                                        ? Colors.grey[900]
                                        : Colors.grey[50],
                                    elevation: 12,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  searchFieldProps: TextFieldProps(
                                    decoration: InputDecoration(
                                      hintText: translationService.getCached(
                                        "Search Skill Level",
                                      ),
                                      hintStyle: TextStyle(
                                        fontWeight: FontWeight.w400,
                                        color: isDark
                                            ? Colors.white54
                                            : Colors.grey[600],
                                        fontStyle: FontStyle.italic,
                                      ),
                                      prefixIcon: const Icon(Icons.search),
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                                items: skillLevels,
                                itemAsString: (item) => item['name'] ?? '',
                                selectedItem: selectedSkillLevel,
                                onChanged: (value) {
                                  setDialogState(() {
                                    selectedSkillLevel = value;
                                    selectedSkillLevelId = value?['id'];
                                  });
                                },
                                dropdownDecoratorProps: DropDownDecoratorProps(
                                  dropdownSearchDecoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    hintText: translationService.getCached(
                                      'Select Skill Level',
                                    ),
                                    hintStyle: TextStyle(
                                      fontWeight: FontWeight.w400,
                                      color: isDark
                                          ? Colors.white54
                                          : Colors.grey[600],
                                      fontStyle: FontStyle.italic,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color: isDark
                                            ? Colors.white24
                                            : Colors.transparent,
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
                    if (isSaving)
                      Center(
                        child: LoadingAnimationWidget.fourRotatingDots(
                          color: isDark ? Colors.white : AppStyle.primaryColor,
                          size: 60,
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isDark
                              ? Colors.white
                              : Colors.black87,
                          backgroundColor: isDark
                              ? Colors.grey[800]
                              : Colors.white,
                          side: BorderSide(
                            color: isDark
                                ? Colors.white
                                : AppStyle.primaryColor,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: tr(
                          "CLOSE",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.white
                                : AppStyle.primaryColor,
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
                        onPressed: isSaving
                            ? null
                            : () async {
                                setDialogState(() {
                                  resetError();
                                  isSaving = true;
                                });

                                if (selectedSkillTypeId == null ||
                                    selectedSkillId == null ||
                                    selectedSkillLevelId == null) {
                                  setDialogState(() {
                                    skillError =
                                        "${translationService.getCached('Please select skill type, skill, and level')}";
                                    isSaving = false;
                                  });
                                  return;
                                }

                                final data = {
                                  "skill_id": selectedSkillId,
                                  "skill_level_id": selectedSkillLevelId,
                                  "skill_type_id": selectedSkillTypeId,
                                };

                                pageContext.read<EmployeeFormBloc>().add(
                                  UpdateSkill(skill['id'], data),
                                );

                                Navigator.pop(dialogContext);
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
          },
        );
      },
    );
  }

  /// HR Settings section (employee type, related user, PIN, badge)
  Widget _buildHRSettingsSection(
    BuildContext context,
    EmployeeFormState state,
    Map<String, dynamic> details,
    bool isDark,
  ) {
    final badgeText = state.badgeController.text.trim();

    return Container(
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
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            tr(
              'HR Settings',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                tr(
                  "Employee Type",
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  getEmployeeTypeLabel(state.employeeType),
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontWeight: FontWeight.normal,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.end,
                ),
              ],
            ),
            SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                tr(
                  "Related User",
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  _displayName(details['user_id']),
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontWeight: FontWeight.normal,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.end,
                ),
              ],
            ),

            const SizedBox(height: 10),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                tr(
                  "PIN Code",
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  (state.pinController.text?.isNotEmpty ?? false)
                      ? state.pinController.text
                      : 'N/A',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontWeight: FontWeight.normal,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.end,
                ),
              ],
            ),
            SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                tr(
                  "Badge ID",
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  (state.badgeController.text?.isNotEmpty ?? false)
                      ? state.badgeController.text
                      : 'N/A',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontWeight: FontWeight.normal,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.end,
                ),
              ],
            ),
            if (badgeText.isEmpty || badgeText == 'N/A') ...[
              SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(""),
                  TextButton(
                    onPressed: () =>
                        context.read<EmployeeFormBloc>().add(GenerateBadge()),
                    child: tr(
                      "Generate Badge",
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : AppStyle.primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
