import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../CommonWidgets/core/language/translate_widget.dart';
import '../../../../CommonWidgets/core/providers/language_provider.dart';
import '../../../../CommonWidgets/core/providers/motion_provider.dart';
import '../../../../CommonWidgets/globals.dart';
import '../../../../CommonWidgets/shared/widgets/snackbar.dart';
import '../../../AppBars/pages/common_app_bar.dart';
import '../../../Employees/EmployeeForm/Form/widgets/shimmer_employee_details.dart';
import '../../AttendanceList/bloc/attendance_list_bloc.dart';
import '../bloc/attendance_form_bloc.dart';
import 'attendance_form_update.dart';

/// A page that displays detailed attendance information for an employee.
///
/// Shows check-in/out times, worked hours, extra hours, mode of attendance,
/// IP address, browser, localisation, and GPS coordinates.
/// Also provides an option to edit attendance if the user has edit access.
class AttendanceFormPage extends StatefulWidget {
  /// The ID of the attendance record to display.
  final int attendanceId;

  /// The working hours associated with the attendance record.
  final String workingHours;

  const AttendanceFormPage({
    super.key,
    required this.attendanceId,
    required this.workingHours,
  });

  @override
  State<AttendanceFormPage> createState() => _AttendanceFormPageState();
}

class _AttendanceFormPageState extends State<AttendanceFormPage> {
  late TextEditingController checkInController;
  late TextEditingController checkOutController;
  /// Maps Latin digits to native digits for supported locales.
  final Map<String, Map<String, String>> _digitMaps = {
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

  @override
  void initState() {
    super.initState();
    checkInController = TextEditingController();
    checkOutController = TextEditingController();

    // Initialize attendance form data
    final bloc = BlocProvider.of<AttendanceFormBloc>(context);
    bloc.add(
      InitializeAttendance(
        attendanceId: widget.attendanceId,
        workingHours: widget.workingHours,
      ),
    );
  }

  @override
  void dispose() {
    checkInController.dispose();
    checkOutController.dispose();
    super.dispose();
  }

  /// Returns the translated string for the given key from cached values.
  String catchTranslate(BuildContext context, String key) {
    final service = Provider.of<LanguageProvider>(context, listen: false);
    return service.getCached(key) ?? key;
  }

  /// Localizes hours string based on the current locale.
  String formattedHoursLocalized(String formattedHours, String locale) {
    return localeNumber(formattedHours, locale);
  }

  /// Safely parses the check-in or check-out value to a string.
  String parseCheckIn(dynamic value) {
    if (value == null) return "";
    if (value is String) return value;
    if (value is bool) return "";
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return WillPopScope(
      onWillPop: () async {
        _handleBackNavigation(context);
        return true;
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
            onPressed: () => _handleBackNavigation(context),
          ),
          title: BlocBuilder<AttendanceFormBloc, AttendanceFormState>(
            builder: (context, state) {
              String title = catchTranslate(context, 'Attendance Details');
              if (state is AttendanceFormLoaded) {
                title = state.isEditing
                    ? catchTranslate(context, "Edit Attendance Details")
                    : catchTranslate(context, "Attendance Details");
              }
              return Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              );
            },
          ),
          actions: [
            BlocBuilder<AttendanceFormBloc, AttendanceFormState>(
              builder: (context, state) {
                if (state is AttendanceFormLoaded &&
                    (state.hasEditAccess ?? false) &&
                    !state.isEditing) {
                  final employeeName =
                      state.record?['employee_id'] is List &&
                          state.record?['employee_id'].length > 1
                      ? state.record!['employee_id'][1].toString()
                      : 'N/A';
                  return IconButton(
                    onPressed: () {
                      final bloc = context.read<AttendanceFormBloc>();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BlocProvider.value(
                            value: bloc,
                            child: AttendanceFormUpdate(
                              title: catchTranslate(context, "Edit Attendance"),
                              employeeId: state.selectedEmployeeId!,
                              employeeImage: state.imageUrl ?? '',
                              employeeJob: safeText(state.record?['job']),
                              employeeEmail: safeText(state.record?['work_email']),
                              employees: state.employees ?? [],
                              employeeName: employeeName,
                              checkIn: parseCheckIn(
                                state.checkIn ?? state.record?['check_in'],
                              ),
                              checkOut: parseCheckIn(
                                state.checkOut ?? state.record?['check_out'],
                              ),
                              workedHours: _formatWorkedHours(
                                state.record?['worked_hours'],
                                context,
                              ),
                              extraHours: _formatWorkedHours(
                                state.record?['overtime_hours'],
                                context,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    tooltip: catchTranslate(context, 'Edit Attendance'),
                    icon: Icon(
                      HugeIcons.strokeRoundedPencilEdit02,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
        body: BlocConsumer<AttendanceFormBloc, AttendanceFormState>(
          listener: (context, state) {
            if (state is AttendanceFormLoaded && state.errorMessage != null) {
              CustomSnackbar.showError(context, state.errorMessage!);
            } else if (state is AttendanceFormLoaded &&
                state.successMessage != null) {
              CustomSnackbar.showSuccess(context, state.successMessage!);
            }
          },
          builder: (context, state) {
            if (state is AttendanceFormInitial ||
                state is AttendanceFormLoading) {
              return ShimmerEmployeeDetails(isDark: isDark);
            }
            if (state is AttendanceFormError) {
              CustomSnackbar.showError(context, state.message);
            }
            final loadedState = state as AttendanceFormLoaded;
            final record = loadedState.record;

            /// Mapping between attendance modes and their labels
            final inAndOut = {
              "Kiosk": "kiosk",
              "Systray": "systray",
              "Manual": "manual",
            };
            final reverseInAndOut = {
              for (var entry in inAndOut.entries) entry.value: entry.key,
            };

            return Stack(
              children: [
                SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        /// Employee info and attendance summary
                        /// Check-in/out, worked hours, extra hours
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
                                if (record != null && record.isNotEmpty) ...[
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      ClipOval(
                                        child: buildImage(
                                          loadedState.imageUrl,
                                          isDark,
                                          name:
                                              record?['employee_id'] is List &&
                                                  record?['employee_id']
                                                          .length >
                                                      1
                                              ? record!['employee_id'][1]
                                              : 'N/A',
                                        ),
                                      ),
                                      const SizedBox(width: 20),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              record?['employee_id'] is List &&
                                                      record?['employee_id']
                                                              .length >
                                                          1
                                                  ? record!['employee_id'][1]
                                                  : 'N/A',
                                              style: TextStyle(
                                                fontSize:
                                                    record!['employee_id'][1]
                                                            .length >
                                                        20
                                                    ? 20
                                                    : (record!['employee_id'][1]
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
                                            const SizedBox(height: 2),
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 6,
                                              crossAxisAlignment:
                                                  WrapCrossAlignment.center,
                                              children: [
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.start,
                                                  children: [
                                                    Icon(
                                                      HugeIcons
                                                          .strokeRoundedNewJob,
                                                      color: isDark
                                                          ? Colors.grey[400]
                                                          : Colors.grey[700],
                                                      size: 14,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Expanded(
                                                      child: Text(
                                                        safeText(
                                                          record?['job'],
                                                        ),
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: isDark
                                                              ? Colors.white60
                                                              : Colors.black54,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.start,
                                                  children: [
                                                    Icon(
                                                      HugeIcons
                                                          .strokeRoundedMail02,
                                                      color: isDark
                                                          ? Colors.grey[400]
                                                          : Colors.grey[700],
                                                      size: 14,
                                                    ),
                                                    SizedBox(width: 5),
                                                    Expanded(
                                                      child: Text(
                                                        safeText(
                                                          record?['work_email'],
                                                        ),
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: isDark
                                                              ? Colors.white60
                                                              : Colors.black54,
                                                        ),
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
                                ],
                                const SizedBox(height: 24),
                                Divider(
                                  color: isDark
                                      ? Colors.white.withOpacity(0.1)
                                      : Colors.grey.shade200,
                                  thickness: 1,
                                  height: 1,
                                ),
                                const SizedBox(height: 20),
                                Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        tr(
                                          "Check In",
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.grey[400]
                                                : Colors.grey[600],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          _formatDateTime(
                                            loadedState.checkIn ??
                                                record?['check_in'],
                                          ),
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black,
                                            fontWeight: FontWeight.normal,
                                            fontSize: 14,
                                          ),
                                          textAlign: TextAlign.end,
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        tr(
                                          "Check Out",
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.grey[400]
                                                : Colors.grey[600],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          _formatDateTime(
                                            loadedState.checkOut ??
                                                record?['check_out'],
                                          ),
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black,
                                            fontWeight: FontWeight.normal,
                                            fontSize: 14,
                                          ),
                                          textAlign: TextAlign.end,
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        tr(
                                          "Worked Hours",
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.grey[400]
                                                : Colors.grey[600],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          _formatWorkedHours(
                                            record?['worked_hours'],
                                            context,
                                          ),
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black,
                                            fontWeight: FontWeight.normal,
                                            fontSize: 14,
                                          ),
                                          textAlign: TextAlign.end,
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 12),
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
                                        Text(
                                          _formatWorkedHours(
                                            record?['overtime_hours'],
                                            context,
                                          ),
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black,
                                            fontWeight: FontWeight.normal,
                                            fontSize: 14,
                                          ),
                                          textAlign: TextAlign.end,
                                        ),
                                      ],
                                    ),

                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                        if (record != null && record.isNotEmpty)...[
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
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  tr(
                                    "Check In",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: isDark
                                          ? Colors.white
                                          : const Color(0xFF1A1A1A),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Row(
                                    mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                    children: [
                                      tr(
                                        "Mode",
                                        style: TextStyle(
                                          color: isDark
                                              ? Colors.grey[400]
                                              : Colors.grey[600],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        reverseInAndOut[record['in_mode']] ??
                                            record['in_mode'] ??
                                            "—",
                                        style: TextStyle(
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black,
                                          fontWeight: FontWeight.normal,
                                          fontSize: 14,
                                        ),
                                        textAlign: TextAlign.end,
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                    children: [
                                      tr(
                                        "IP Address",
                                        style: TextStyle(
                                          color: isDark
                                              ? Colors.grey[400]
                                              : Colors.grey[600],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        safeText(record['in_ip_address']),
                                        style: TextStyle(
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black,
                                          fontWeight: FontWeight.normal,
                                          fontSize: 14,
                                        ),
                                        textAlign: TextAlign.end,
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                    children: [
                                      tr(
                                        "Browser",
                                        style: TextStyle(
                                          color: isDark
                                              ? Colors.grey[400]
                                              : Colors.grey[600],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        safeText(record['in_browser']),
                                        style: TextStyle(
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black,
                                          fontWeight: FontWeight.normal,
                                          fontSize: 14,
                                        ),
                                        textAlign: TextAlign.end,
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                    children: [
                                      tr(
                                        "Localisation",
                                        style: TextStyle(
                                          color: isDark
                                              ? Colors.grey[400]
                                              : Colors.grey[600],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        safeText(record['in_country_name']),
                                        style: TextStyle(
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black,
                                          fontWeight: FontWeight.normal,
                                          fontSize: 14,
                                        ),
                                        textAlign: TextAlign.end,
                                      ),
                                    ],
                                  ),
                                  if (record['in_latitude'] != null &&
                                      record['in_longitude'] != null) ...[
                                    SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                      children: [
                                        tr(
                                          "GPS Coordinates",
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.grey[400]
                                                : Colors.grey[600],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          "${record['in_latitude']}, ${record['in_longitude']}",
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black,
                                            fontWeight: FontWeight.normal,
                                            fontSize: 14,
                                          ),
                                          textAlign: TextAlign.end,
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(""),
                                        Row(
                                          children: [
                                            InkWell(
                                              borderRadius:
                                              BorderRadius.circular(8),
                                              onTap: () {
                                                openMapFromLatLng(
                                                  record['in_latitude'],
                                                  record['in_longitude'],
                                                );
                                              },
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    HugeIcons
                                                        .strokeRoundedMapPinpoint02,
                                                    size: 16,
                                                    color: isDark
                                                        ? Colors.white60
                                                        : AppStyle
                                                        .primaryColor,
                                                  ),
                                                  const SizedBox(
                                                    width: 6,
                                                  ),
                                                  tr(
                                                    "View in Map",
                                                    style: TextStyle(
                                                      color: isDark
                                                          ? Colors.white
                                                          : AppStyle
                                                          .primaryColor,
                                                      fontWeight:
                                                      FontWeight
                                                          .normal,
                                                      fontSize: 14,
                                                    ),
                                                    textAlign:
                                                    TextAlign.end,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          if (record['check_out'] != null &&
                              record['check_out'] != false)
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
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    tr(
                                      "Check Out",
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? Colors.white
                                            : const Color(0xFF1A1A1A),
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    Row(
                                      mainAxisAlignment:
                                      MainAxisAlignment
                                          .spaceBetween,
                                      children: [
                                        tr(
                                          "Mode",
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.grey[400]
                                                : Colors.grey[600],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          reverseInAndOut[record['out_mode']] ??
                                              record['out_mode'] ??
                                              "—",
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black,
                                            fontWeight:
                                            FontWeight.normal,
                                            fontSize: 14,
                                          ),
                                          textAlign: TextAlign.end,
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment:
                                      MainAxisAlignment
                                          .spaceBetween,
                                      children: [
                                        tr(
                                          "IP Address",
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.grey[400]
                                                : Colors.grey[600],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          safeText(
                                            record['out_ip_address'],
                                          ),
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black,
                                            fontWeight:
                                            FontWeight.normal,
                                            fontSize: 14,
                                          ),
                                          textAlign: TextAlign.end,
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment:
                                      MainAxisAlignment
                                          .spaceBetween,
                                      children: [
                                        tr(
                                          "Browser",
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.grey[400]
                                                : Colors.grey[600],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          safeText(
                                            record['out_browser'],
                                          ),
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black,
                                            fontWeight:
                                            FontWeight.normal,
                                            fontSize: 14,
                                          ),
                                          textAlign: TextAlign.end,
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment:
                                      MainAxisAlignment
                                          .spaceBetween,
                                      children: [
                                        tr(
                                          "Localisation",
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.grey[400]
                                                : Colors.grey[600],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          safeText(
                                            record['out_country_name'],
                                          ),
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black,
                                            fontWeight:
                                            FontWeight.normal,
                                            fontSize: 14,
                                          ),
                                          textAlign: TextAlign.end,
                                        ),
                                      ],
                                    ),
                                    if (record['out_latitude'] !=
                                        null &&
                                        record['out_longitude'] !=
                                            null) ...[
                                      SizedBox(height: 12),
                                      Row(
                                        mainAxisAlignment:
                                        MainAxisAlignment
                                            .spaceBetween,
                                        children: [
                                          tr(
                                            "GPS Coordinates",
                                            style: TextStyle(
                                              color: isDark
                                                  ? Colors.grey[400]
                                                  : Colors.grey[600],
                                              fontWeight:
                                              FontWeight.w500,
                                            ),
                                          ),
                                          Text(
                                            "${record['out_latitude']}, ${record['out_longitude']}",
                                            style: TextStyle(
                                              color: isDark
                                                  ? Colors.white
                                                  : Colors.black,
                                              fontWeight: FontWeight.normal,
                                              fontSize: 14,
                                            ),
                                            textAlign: TextAlign.end,
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 12),
                                      Row(
                                        mainAxisAlignment:
                                        MainAxisAlignment
                                            .spaceBetween,
                                        children: [
                                          Text(""),
                                          Row(
                                            children: [
                                              InkWell(
                                                borderRadius:
                                                BorderRadius.circular(
                                                  8,
                                                ),
                                                onTap: () {
                                                  openMapFromLatLng(
                                                    record['out_latitude'],
                                                    record['out_longitude'],
                                                  );
                                                },
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      HugeIcons
                                                          .strokeRoundedMapPinpoint02,
                                                      size: 16,
                                                      color: isDark
                                                          ? Colors
                                                          .white60
                                                          : AppStyle
                                                          .primaryColor,
                                                    ),
                                                    const SizedBox(
                                                      width: 6,
                                                    ),
                                                    tr(
                                                      "View in Map",
                                                      style: TextStyle(
                                                        color: isDark
                                                            ? Colors
                                                            .white
                                                            : AppStyle
                                                            .primaryColor,
                                                        fontWeight:
                                                        FontWeight
                                                            .normal,
                                                        fontSize: 14,
                                                      ),
                                                      textAlign:
                                                      TextAlign
                                                          .end,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            )
                        ]
                        else
                          Center(
                            child: tr(
                              "No attendance records found.",
                              style: TextStyle(
                                fontSize: 20,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (loadedState.isSaving)
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
  }

  /// Safely returns a string value or "—" if null/false.
  String safeText(dynamic value) {
    if (value == null || value == false) return "—";
    return value.toString();
  }

  /// Opens Google Maps with given [lat] and [lng] coordinates.
  Future<void> openMapFromLatLng(dynamic lat, dynamic lng) async {
    if (lat == null || lng == null) return;
    final latitude = lat.toString();
    final longitude = lng.toString();
    if (latitude == '0' || longitude == '0') return;

    final Uri mapUrl = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
    );
    if (!await launchUrl(mapUrl, mode: LaunchMode.externalApplication)) {
    }
  }

  /// Builds an employee image widget, either from a base64 string or placeholder.
  Widget buildImage(String? img, bool isDark, {String? name}) {
    if (img == null) {
      return _placeholder(name, isDark);
    }
    final bool isBase64 = img.startsWith("data:image") || img.length > 500;
    if (isBase64) {
      try {
        final base64String = img.contains(",") ? img.split(",").last : img;
        final bytes = base64Decode(base64String);
        return Image.memory(bytes, height: 70, width: 70, fit: BoxFit.cover);
      } catch (e) {
        return _placeholder(name, isDark);
      }
    }
    return _placeholder(name, isDark);
  }

  /// Returns a placeholder widget for an employee image.
  /// Shows first letter of name or a person icon if no name.
  Widget _placeholder(String? name, isDark) {
    final firstLetter = (name != null && name.isNotEmpty)
        ? name[0].toUpperCase()
        : "";

    return Container(
      height: 70,
      width: 70,
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

  /// Converts Latin digits in [input] to locale-specific digits.
  String localeNumber(String input, String locale) {
    final code = locale.split('_').first.toLowerCase();
    final map = _digitMaps[code];
    if (map == null) return input;

    map.forEach((latin, native) {
      input = input.replaceAll(latin, native);
    });
    return input;
  }

  /// Formats a raw date/time string into a readable format with localization.
  String _formatDateTime(dynamic dateStr) {
    if (dateStr == null || dateStr == false || dateStr == "") return "N/A";
    try {
      final date = DateTime.parse("${dateStr}Z").toLocal();
      final locale = context
          .read<LanguageProvider>()
          .currentCode
          .split('_')
          .first;
      final format = DateFormat('dd MMM yyyy، HH:mm', locale);
      return localeNumber(format.format(date), locale);

    } catch (e) {
      return "N/A";
    }
  }

  /// Formats worked hours (decimal) into HH:mm format with localization.
  String _formatWorkedHours(dynamic raw, BuildContext context) {
    if (raw == null || raw == false || raw == "") return "N/A";

    try {
      double hoursDouble = raw is double ? raw : double.parse(raw.toString());
      final hours = hoursDouble.floor();
      final minutes = ((hoursDouble - hours) * 60).round();

      final translationService = context.read<LanguageProvider>();
      final locale = translationService.currentCode.split('_').first;

      final formatted =
          "${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}";

      return localeNumber(formatted, locale);
    } catch (e) {
      return "N/A";
    }
  }

  /// Handles back navigation and triggers reloading of attendance list.
  void _handleBackNavigation(BuildContext context) {
    final motionProvider = Provider.of<MotionProvider>(context, listen: false);
    final listBloc = context.read<AttendanceListBloc>();
    listBloc.add(const LoadAttendance(page: 0));

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const CommonAppBar(initialIndex: 2),
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
}
