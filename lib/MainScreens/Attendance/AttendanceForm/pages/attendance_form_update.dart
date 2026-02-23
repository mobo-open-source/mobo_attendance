import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:provider/provider.dart';

import '../../../../CommonWidgets/core/language/translate_widget.dart';
import '../../../../CommonWidgets/core/navigation/data_loss_warning_dialog.dart';
import '../../../../CommonWidgets/core/providers/language_provider.dart';
import '../../../../CommonWidgets/globals.dart';
import '../bloc/attendance_form_bloc.dart';
import '../widgets/attendance_personal_info.dart';

/// A screen widget to update attendance information of a specific employee.
///
/// Displays employee details, time log inputs for check-in and check-out,
/// work summary, and allows saving changes. Handles unsaved changes warning
/// when navigating back.
class AttendanceFormUpdate extends StatefulWidget {
  final String title;
  final int employeeId;
  final String employeeName;
  final String checkIn;
  final String checkOut;
  final String workedHours;
  final String extraHours;
  final String employeeImage;
  final String employeeJob;
  final String employeeEmail;
  final List<Map<String, dynamic>> employees;

  const AttendanceFormUpdate({
    super.key,
    required this.title,
    required this.employeeId,
    required this.employeeName,
    required this.checkIn,
    required this.checkOut,
    required this.workedHours,
    required this.extraHours,
    required this.employeeImage,
    required this.employeeJob,
    required this.employeeEmail,
    required this.employees,
  });

  @override
  State<AttendanceFormUpdate> createState() => _AttendanceFormUpdateState();
}

class _AttendanceFormUpdateState extends State<AttendanceFormUpdate> {
  late TextEditingController checkInController;
  late TextEditingController checkOutController;
  late int selectedEmployeeId;
  late String selectedEmployeeName;
  late String selectedEmployeeImage;
  late String selectedEmployeeJob;
  late String selectedEmployeeEmail;
  bool isSaving = false;
  bool isDirty = false;

  @override
  void initState() {
    super.initState();
    selectedEmployeeId = widget.employeeId;
    selectedEmployeeName = widget.employeeName;
    selectedEmployeeImage = widget.employeeImage;
    selectedEmployeeJob = widget.employeeJob;
    selectedEmployeeEmail = widget.employeeEmail;

    checkInController = TextEditingController(text: widget.checkIn);
    checkOutController = TextEditingController(text: widget.checkOut);

    checkInController.addListener(_markDirty);
    checkOutController.addListener(_markDirty);
  }

  /// Marks the form as dirty if any field changes.
  void _markDirty() {
    if (!isDirty &&
        (checkInController.text != widget.checkIn ||
            checkOutController.text != widget.checkOut ||
            selectedEmployeeId != widget.employeeId)) {
      setState(() => isDirty = true);
    }
  }

  /// Retrieves translated text from the cached language provider.
  ///
  /// Returns the original [key] if no translation is found.
  String catchTranslate(BuildContext context, String key) {
    final service = Provider.of<LanguageProvider>(context, listen: false);
    return service.getCached(key) ?? key;
  }

  /// Shows a dialog warning the user about unsaved changes.
  ///
  /// Returns `true` if the user confirms discarding changes, otherwise `false`.
  Future<bool> _showUnsavedChangesDialog(BuildContext context) async {
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

  /// Handles back navigation and checks for unsaved changes.
  ///
  /// Returns `true` if navigation is allowed, otherwise `false`.
  Future<bool> _handleBack() async {
    if (!isDirty) return true;

    return await _showUnsavedChangesDialog(context);
  }

  /// Builds an image widget for the employee.
  ///
  /// Supports both base64 and URL images. Falls back to a placeholder if the image is null or invalid.
  Widget buildImage(String? img, bool isDark, {String? name}) {
    if (img == null) {
      return _placeholder(name, isDark);
    }
    final bool isBase64 = img.startsWith("data:image") || img.length > 500;
    if (isBase64) {
      try {
        final base64String = img.contains(",") ? img.split(",").last : img;
        final bytes = base64Decode(base64String);
        return Image.memory(bytes, height: 60, width: 60, fit: BoxFit.cover);
      } catch (e) {
        return _placeholder(name, isDark);
      }
    }
    return _placeholder(name, isDark);
  }

  /// Generates a placeholder widget with the employee's initial or an icon.
  Widget _placeholder(String? name, isDark) {
    final firstLetter = (name != null && name.isNotEmpty)
        ? name[0].toUpperCase()
        : "";

    return Container(
      height: 60,
      width: 60,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.2)
            : AppStyle.primaryColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(27.5),
      ),
      alignment: Alignment.center,
      child: firstLetter.isNotEmpty
          ? Text(
              firstLetter,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppStyle.primaryColor,
              ),
            )
          : const Icon(Icons.person, size: 30, color: AppStyle.primaryColor),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return WillPopScope(
      onWillPop: _handleBack,
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
              final canLeave = await _handleBack();
              if (canLeave) Navigator.pop(context);
            },
          ),
          title: Text(
            widget.title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
        ),
        body: Stack(
          children: [
            SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    /// Employee Information Section
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
                          /// Section Header
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(16),
                                topRight: Radius.circular(16),
                              ),
                            ),
                            child: tr(
                              'Employee Information',
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
                          /// Editable Employee Dropdown
                          if (selectedEmployeeId == 0)
                            Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                tr(
                                  'Employee',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w400,
                                    color: isDark
                                        ? Colors.white70
                                        : const Color(0xff7F7F7F),
                                  ),
                                ),

                                const SizedBox(height: 10),
                                AttendancePersonalInfo(
                                  label: "Employee",
                                  value: selectedEmployeeName,
                                  prefixIcon: HugeIcons.strokeRoundedUser,
                                  isEditing: true,
                                  dropdownItems: widget.employees,
                                  selectedId: selectedEmployeeId,
                                  onDropdownChanged: (item) {
                                    if (item != null) {
                                      setState(() {
                                        selectedEmployeeId = item['id'];
                                        selectedEmployeeName = item['name'];
                                        selectedEmployeeImage = item['image_1920'];
                                        selectedEmployeeJob = item['job_id'][1];
                                        selectedEmployeeEmail = item['work_email'];
                                        _markDirty();
                                      });
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                          /// Display Employee Card
                          if (selectedEmployeeId > 0)
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Card(
                                margin: const EdgeInsets.only(top: 0),
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                color: isDark ? Colors.grey[850] : Colors.white,
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 30,
                                        backgroundColor: isDark ? Colors.grey[100] : Colors.grey[200],
                                        child:
                                        selectedEmployeeImage != null &&
                                            selectedEmployeeImage!.isNotEmpty
                                            ? ClipOval(
                                                child: buildImage(
                                                  selectedEmployeeImage,
                                                  isDark,
                                                  name: selectedEmployeeName,
                                                ),
                                              )
                                            : _placeholder(
                                              selectedEmployeeName,
                                                isDark,
                                              ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    selectedEmployeeName,
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 16,
                                                      color:
                                                          Theme.of(
                                                                context,
                                                              ).brightness ==
                                                              Brightness.dark
                                                          ? Colors.white
                                                          : Colors.black87,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            if (selectedEmployeeJob != null)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  top: 2,
                                                ),
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      HugeIcons.strokeRoundedWork,
                                                      size: 14,
                                                      color: isDark
                                                          ? Colors.grey[400]
                                                          : Colors.grey[600],
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Expanded(
                                                      child: Text(
                                                        selectedEmployeeJob!,
                                                        style: TextStyle(
                                                          color: isDark
                                                              ? Colors.grey[300]
                                                              : Colors.grey[600],
                                                          fontSize: 13,
                                                        ),
                                                        maxLines: 2,
                                                        overflow:
                                                            TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            const SizedBox(height: 8),
                                            if (selectedEmployeeEmail != null)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  top: 2,
                                                ),
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      HugeIcons.strokeRoundedMail02,
                                                      size: 14,
                                                      color: isDark
                                                          ? Colors.grey[400]
                                                          : Colors.grey[600],
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Expanded(
                                                      child: Text(
                                                        selectedEmployeeEmail!,
                                                        style: TextStyle(
                                                          color: isDark
                                                              ? Colors.grey[300]
                                                              : Colors.grey[600],
                                                          fontSize: 13,
                                                        ),
                                                        maxLines: 2,
                                                        overflow:
                                                            TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          left: 8.0,
                                        ),
                                        child: IconButton(
                                          constraints: const BoxConstraints(
                                            minWidth: 48,
                                            minHeight: 48,
                                          ),
                                          icon: Icon(
                                            HugeIcons
                                                .strokeRoundedCancelCircleHalfDot,
                                            color: isDark
                                                ? Colors.grey[400]
                                                : Colors.grey[600],
                                            size: 24,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              selectedEmployeeId = 0;
                                            });
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
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
                              'TimeLog',
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
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                tr(
                                  'Check In',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w400,
                                    color: isDark
                                        ? Colors.white70
                                        : const Color(0xff7F7F7F),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                AttendancePersonalInfo(
                                  label: "Check In",
                                  value: checkInController.text,
                                  isEditing: true,
                                  isDateInput: true,
                                  controller: checkInController,
                                ),
                                const SizedBox(height: 12),
                                tr(
                                  'Check Out',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w400,
                                    color: isDark
                                        ? Colors.white70
                                        : const Color(0xff7F7F7F),
                                  ),
                                ),
                                const SizedBox(height: 8),

                                AttendancePersonalInfo(
                                  label: "Check Out",
                                  value: checkOutController.text,
                                  isEditing: true,
                                  isDateInput: true,
                                  controller: checkOutController,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

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
                              'Work Summary',
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
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    tr(
                                      "Worked Hours",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w400,
                                        color: isDark
                                            ? Colors.white70
                                            : const Color(0xff7F7F7F),
                                      ),
                                    ),
                                    tr(
                                      widget.workedHours,
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black87,
                                        fontWeight: FontWeight.normal,
                                        fontSize: 14,
                                      ),
                                      textAlign: TextAlign.end,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    tr(
                                      "Extra Hours",
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.grey[400]
                                            : Colors.grey[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    tr(
                                      widget.extraHours,
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black87,
                                        fontWeight: FontWeight.normal,
                                        fontSize: 14,
                                      ),
                                      textAlign: TextAlign.end,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    /// Other sections like TimeLog and Work Summary omitted for brevity

                    /// Save Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: (!isDirty || isSaving || selectedEmployeeId == 0)
                            ? null
                            : () async {
                                setState(() => isSaving = true);
                                context.read<AttendanceFormBloc>().add(
                                  SaveAttendance(
                                    employeeId: selectedEmployeeId,
                                    employeeName: selectedEmployeeName,
                                    checkIn: checkInController.text,
                                    checkOut: checkOutController.text,
                                  ),
                                );
                                await Future.delayed(
                                  const Duration(milliseconds: 600),
                                );

                                if (mounted) {
                                  setState(() => isSaving = false);
                                  Navigator.pop(context);
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark
                              ? Colors.white
                              : AppStyle.primaryColor,
                          foregroundColor: isDark
                              ? Colors.black
                              :Colors.white,
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
            ),
            /// Loading Indicator
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
    );
  }
}
