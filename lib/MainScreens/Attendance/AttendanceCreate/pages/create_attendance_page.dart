import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../../CommonWidgets/core/language/translate_widget.dart';
import '../../../../CommonWidgets/core/providers/language_provider.dart';
import '../../../../CommonWidgets/globals.dart';
import '../../../../CommonWidgets/shared/widgets/snackbar.dart';
import '../../../Employees/EmployeeForm/Form/widgets/shimmer_employee_details.dart';
import '../../AttendanceForm/pages/attendance_form_page.dart';
import '../bloc/create_attendance_bloc.dart';
import '../widgets/attendance_create_info.dart';

/// Page to create a new attendance entry for employees.
///
/// This page allows selecting an employee, setting check-in and check-out
/// times, viewing a summary of worked hours, and saving the attendance.
///
/// It consists of two main components:
/// 1. `CreateAttendancePage` – the StatefulWidget that initializes the page
///    and triggers the initial data load via the `CreateAttendanceBloc`.
/// 2. `CreateAttendanceView` – the StatelessWidget that builds the UI
///    including employee information, time logs, work summary, and
///    save button.
///
/// The page handles locale-specific digit formatting for Arabic, Farsi,
/// Urdu, Bengali, Thai, and Myanmar numerals, as well as formatting of
/// worked hours and timestamps.
class CreateAttendancePage extends StatefulWidget {
  /// Creates a new instance of the attendance creation page.
  const CreateAttendancePage({super.key});

  @override
  State<CreateAttendancePage> createState() => _CreateAttendancePageState();
}

/// State class for `CreateAttendancePage`.
///
/// Initializes the `CreateAttendanceBloc` to load employee data when the
/// page is first displayed.
class _CreateAttendancePageState extends State<CreateAttendancePage> {
  @override
  void initState() {
    super.initState();
    // Trigger the attendance initialization event
    final bloc = BlocProvider.of<CreateAttendanceBloc>(context);
    bloc.add(InitializeCreateAttendance());
  }

  @override
  Widget build(BuildContext context) {
    return const CreateAttendanceView();
  }
}

/// The main view of the attendance creation page.
///
/// Handles UI rendering, formatting of dates and hours, and interactions
/// such as selecting an employee or updating check-in/check-out times.
///
/// Features:
/// - Locale-specific number formatting for supported languages.
/// - Formatting of datetime strings to "dd MMM yyyy, HH:mm".
/// - Display of worked and extra hours in HH:mm format.
/// - Employee image handling with Base64 decoding or placeholder initials.
/// - Integration with `CreateAttendanceBloc` for state management.
/// - Shows shimmer loading while data is loading.
/// - Displays success and error messages using `CustomSnackbar`.
class CreateAttendanceView extends StatelessWidget {
  const CreateAttendanceView({super.key});

  /// Map of supported locale digit conversions.
  ///
  /// Converts Latin digits to native digits for Arabic (`ar`), Farsi (`fa`),
  /// Urdu (`ur`), Bengali (`bn`), Thai (`th`), and Myanmar (`my`) locales.
  static final Map<String, Map<String, String>> _digitMaps = {
    'ar': {
      '0': '٠',
      '1': '١',
      '2': '٢',
      '3': '٣',
      '4': '٤',
      '5': '٥',
      '6': '٦',
      '7': '٧',
      '8': '٨',
      '9': '٩',
    },
    'fa': {
      '0': '۰',
      '1': '۱',
      '2': '۲',
      '3': '۳',
      '4': '۴',
      '5': '۵',
      '6': '۶',
      '7': '۷',
      '8': '۸',
      '9': '۹',
    },
    'ur': {
      '0': '۰',
      '1': '۱',
      '2': '۲',
      '3': '۳',
      '4': '۴',
      '5': '۵',
      '6': '۶',
      '7': '۷',
      '8': '۸',
      '9': '۹',
    },
    'bn': {
      '0': '০',
      '1': '১',
      '2': '২',
      '3': '৩',
      '4': '৪',
      '5': '৫',
      '6': '৬',
      '7': '৭',
      '8': '৮',
      '9': '৯',
    },
    'th': {
      '0': '๐',
      '1': '๑',
      '2': '๒',
      '3': '๓',
      '4': '๔',
      '5': '๕',
      '6': '๖',
      '7': '๗',
      '8': '๘',
      '9': '๙',
    },
    'my': {
      '0': '၀',
      '1': '၁',
      '2': '၂',
      '3': '၃',
      '4': '၄',
      '5': '၅',
      '6': '၆',
      '7': '၇',
      '8': '၈',
      '9': '၉',
    },
  };

  /// Converts a Latin number string to locale-specific digits.
  ///
  /// Example:
  /// ```dart
  /// localeNumber("12:30", "ar") // returns "١٢:٣٠"
  /// ```
  String localeNumber(String input, String locale) {
    final code = locale.split('_').first.toLowerCase();
    final map = _digitMaps[code];
    if (map == null) return input;

    map.forEach((latin, native) {
      input = input.replaceAll(latin, native);
    });
    return input;
  }

  /// Formats a datetime string to a human-readable, localized format.
  ///
  /// Returns "N/A" if input is null or invalid.
  String _formatDateTime(String? dateStr, BuildContext context) {
    if (dateStr == null || dateStr.isEmpty) return "N/A";

    try {
      final date = DateTime.parse(dateStr);
      final translationService = context.read<LanguageProvider>();
      final locale = translationService.currentCode.split('_').first;
      final format = DateFormat('dd MMM yyyy, HH:mm', locale);

      return localeNumber(format.format(date), translationService.currentCode);
    } catch (e) {
      return "N/A";
    }
  }

  /// Formats worked hours into "HH:mm" format.
  ///
  /// Accepts `String`, `int`, or `double` as input.
  String _formatWorkedHours(dynamic raw, BuildContext context) {
    if (raw == null || raw == false || raw.toString().isEmpty) return "00:00";

    try {
      final translationService = context.read<LanguageProvider>();
      final locale = translationService.currentCode.split('_').first;

      String formatted = "00:00";

      if (raw is double) {
        final hours = raw.floor();
        final minutes = ((raw - hours) * 60).round();
        formatted =
            "${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}";
      } else if (raw is int) {
        formatted = "${raw.toString().padLeft(2, '0')}:00";
      } else if (raw is String) {
        if (raw.contains(":")) {
          formatted = raw;
        } else {
          final hoursDouble = double.tryParse(raw) ?? 0;
          final hours = hoursDouble.floor();
          final minutes = ((hoursDouble - hours) * 60).round();
          formatted =
              "${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}";
        }
      }

      return localeNumber(formatted, locale);
    } catch (e) {
      return "00:00";
    }
  }

  /// Builds a circular employee image from a Base64 string or placeholder.
  ///
  /// If image is null or invalid, uses a placeholder with the first letter
  /// of the employee's name.
  Widget _buildImage(String? img, bool isDark, String? name) {
    if (img == null) {
      return Container(
        height: 55,
        width: 55,
        color: isDark
            ? Colors.white.withOpacity(0.2)
            : AppStyle.primaryColor.withOpacity(0.2),
        child: Icon(
          Icons.person,
          size: 30,
          color: isDark ? Colors.white : AppStyle.primaryColor,
        ),
      );
    }
    final bool isBase64 = img.startsWith("data:image") || img.length > 500;
    if (isBase64) {
      try {
        final base64String = img.contains(",") ? img.split(",").last : img;
        final bytes = base64Decode(base64String);
        return ClipOval(
          child: Image.memory(bytes, height: 55, width: 55, fit: BoxFit.cover),
        );
      } catch (e) {
        return _placeholder(name, isDark);
      }
    } else {
      return _placeholder(name, isDark);
    }
  }

  /// Builds a placeholder avatar with the employee's first letter.
  Widget _placeholder(String? name, isDark) {
    final firstLetter = (name != null && name.isNotEmpty)
        ? name[0].toUpperCase()
        : "";

    return Container(
      height: 55,
      width: 55,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.2)
            : AppStyle.primaryColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(0),
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

  /// Retrieves a translated string from cached translations.
  ///
  /// Falls back to the key if translation is missing.
  String catchTranslate(BuildContext context, String key) {
    final service = Provider.of<LanguageProvider>(context, listen: false);
    return service.getCached(key) ?? key;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
        leading: IconButton(
          icon: Icon(
            HugeIcons.strokeRoundedArrowLeft01,
            color: isDark ? Colors.white : Colors.black,
            size: 28,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: tr(
          "Create Attendance",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
      ),
      body: BlocConsumer<CreateAttendanceBloc, CreateAttendanceState>(
        listener: (context, state) {
          if (state is CreateAttendanceSuccess) {
            CustomSnackbar.showSuccess(context, state.message);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AttendanceFormPage(
                  attendanceId: state.attendanceId,
                  workingHours: "From ${state.checkIn}",
                ),
              ),
            );
          } else if (state is CreateAttendanceLoaded && state.errorMessage != null) {
            CustomSnackbar.showError(context, state.errorMessage!);
          }
        },
        builder: (context, state) {
          if (state is CreateAttendanceLoading) {
            return ShimmerEmployeeDetails(isDark: isDark);
          }

          if (state is CreateAttendanceLoaded) {
            return Stack(
              children: [
                SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                                  'Employee Information',
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
                              if(!state.isEmployeeSelect)
                                Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    tr(
                                      "Employee",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w400,
                                        color: isDark
                                            ? Colors.white70
                                            : const Color(0xff7F7F7F),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    AttendanceCreateInfo(
                                      label: "Employee",
                                      prefixIcon: HugeIcons.strokeRoundedUser,
                                      value: state.selectedEmployeeName ?? "",
                                      isEditing: true,
                                      dropdownItems: state.employees,
                                      selectedId: state.isEmployeeSelect
                                          ? state.selectedEmployeeId
                                          : null,
                                      onDropdownChanged: (value) {
                                        if (value != null) {
                                          context
                                              .read<CreateAttendanceBloc>()
                                              .add(SelectEmployee(value));
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              if (state.isEmployeeSelect) ...[
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
                                            backgroundColor:
                                                Theme.of(context).brightness ==
                                                    Brightness.dark
                                                ? Colors.grey[100]
                                                : Colors.grey[200],
                                            child:
                                                state.employeeImage != null &&
                                                    state
                                                        .employeeImage!
                                                        .isNotEmpty
                                                ? _buildImage(
                                                    state.employeeImage,
                                                    isDark,
                                                    state.selectedEmployeeName,
                                                  )
                                                : _placeholder(
                                                    state.selectedEmployeeName,
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
                                                        state
                                                            .selectedEmployeeName!,
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
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
                                                if (state.employeeJob != null)
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          top: 2,
                                                        ),
                                                    child: Row(
                                                      children: [
                                                        Icon(
                                                          HugeIcons
                                                              .strokeRoundedWork,
                                                          size: 14,
                                                          color: isDark
                                                              ? Colors.grey[400]
                                                              : Colors.grey[600],
                                                        ),
                                                        const SizedBox(width: 6),
                                                        Expanded(
                                                          child: Text(
                                                            state.employeeJob!,
                                                            style: TextStyle(
                                                              color: isDark
                                                                  ? Colors
                                                                        .grey[300]
                                                                  : Colors
                                                                        .grey[600],
                                                              fontSize: 13,
                                                            ),
                                                            maxLines: 2,
                                                            overflow: TextOverflow
                                                                .ellipsis,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                const SizedBox(height: 8),
                                                if (state.employeeEmail != null)
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          top: 2,
                                                        ),
                                                    child: Row(
                                                      children: [
                                                        Icon(
                                                          HugeIcons
                                                              .strokeRoundedMail02,
                                                          size: 14,
                                                          color: isDark
                                                              ? Colors.grey[400]
                                                              : Colors.grey[600],
                                                        ),
                                                        const SizedBox(width: 6),
                                                        Expanded(
                                                          child: Text(
                                                            state.employeeEmail!,
                                                            style: TextStyle(
                                                              color: isDark
                                                                  ? Colors
                                                                        .grey[300]
                                                                  : Colors
                                                                        .grey[600],
                                                              fontSize: 13,
                                                            ),
                                                            maxLines: 2,
                                                            overflow: TextOverflow
                                                                .ellipsis,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          if (state.selectedEmployeeId != null)
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
                                                  context
                                                      .read<
                                                        CreateAttendanceBloc
                                                      >()
                                                      .add(
                                                        ClearSelectedEmployee(),
                                                      );
                                                },
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
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
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
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
                                    AttendanceCreateInfo(
                                      label: "Check In",
                                      value: _formatDateTime(
                                        state.checkIn,
                                        context,
                                      ),
                                      isEditing: true,
                                      isDateInput: true,
                                      onDateChanged: (date) => context
                                          .read<CreateAttendanceBloc>()
                                          .add(UpdateCheckIn(date)),
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
                                    AttendanceCreateInfo(
                                      label: "Check Out",
                                      value: _formatDateTime(
                                        state.checkOut,
                                        context,
                                      ),
                                      isEditing: true,
                                      isDateInput: true,
                                      onDateChanged: (date) => context
                                          .read<CreateAttendanceBloc>()
                                          .add(UpdateCheckOut(date)),
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
                                          _formatWorkedHours(
                                            state.workedHours,
                                            context,
                                          ),
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
                                    const SizedBox(height: 10),
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
                                          _formatWorkedHours(
                                            "00:00",
                                            context,
                                          ),
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
                                    const SizedBox(height: 10),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        tr(
                                          "Check In",
                                          style: TextStyle(
                                            fontWeight: FontWeight.w400,
                                            color: isDark
                                                ? Colors.white70
                                                : const Color(0xff7F7F7F),
                                          ),
                                        ),
                                        tr(
                                          state.checkIn.isNotEmpty
                                              ? catchTranslate(
                                                  context,
                                                  "Manual",
                                                )
                                              : "-",
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
                                    const SizedBox(height: 10),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        tr(
                                          "Check Out",
                                          style: TextStyle(
                                            fontWeight: FontWeight.w400,
                                            color: isDark
                                                ? Colors.white70
                                                : const Color(0xff7F7F7F),
                                          ),
                                        ),
                                        tr(
                                          state.checkOut.isNotEmpty
                                              ? catchTranslate(
                                                  context,
                                                  "Manual",
                                                )
                                              : "-",
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

                        BlocBuilder<
                          CreateAttendanceBloc,
                          CreateAttendanceState
                        >(
                          builder: (context, state) {
                            final isSaving = state is CreateAttendanceSaving;
                            final canCreate =
                                state is CreateAttendanceLoaded &&
                                state.selectedEmployeeId != null;

                            return SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: (canCreate && !isSaving && state.isEmployeeSelect)
                                    ? () => context
                                          .read<CreateAttendanceBloc>()
                                          .add(SaveAttendance())
                                    : null,
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
                                icon: Icon(
                                  HugeIcons.strokeRoundedNoteAdd,
                                  color: isDark ? Colors.black : Colors.white,
                                  size: 20,
                                ),
                                label: isSaving
                                    ? LoadingAnimationWidget.threeArchedCircle(
                                        color: isDark
                                            ? Colors.black
                                            : Colors.white,
                                        size: 22,
                                      )
                                    : tr(
                                        "Create Attendance",
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
                      ],
                    ),
                  ),
                ),
                if (state is CreateAttendanceSaving)
                  Center(
                    child: LoadingAnimationWidget.fourRotatingDots(
                      color: isDark ? Colors.white : AppStyle.primaryColor,
                      size: 60,
                    ),
                  ),
              ],
            );
          }

          return Center(
            child: Container(
              child: LoadingAnimationWidget.fourRotatingDots(
                color: isDark ? Colors.white : AppStyle.primaryColor,
                size: 60,
              ),
            ),
          );
        },
      ),
    );
  }
}
