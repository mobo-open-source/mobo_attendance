import 'dart:async';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:lottie/lottie.dart';
import 'package:mobo_attendance/CommonWidgets/globals.dart';
import 'package:mobo_attendance/CommonWidgets/shared/widgets/snackbar.dart';
import 'package:provider/provider.dart';
import '../../../CommonWidgets/core/company/infrastructure/company_refresh_bus.dart';
import '../../../CommonWidgets/core/company/providers/company_provider.dart';
import '../../../CommonWidgets/core/language/translate_widget.dart';
import '../../../CommonWidgets/core/providers/language_provider.dart';
import '../../../CommonWidgets/core/providers/motion_provider.dart';
import '../../AppBars/infrastructure/profile_refresh_bus.dart';
import '../../AppBars/pages/common_app_bar.dart';
import '../bloc/calendar_bloc.dart';
import '../bloc/calendar_event.dart';
import '../bloc/calendar_state.dart';

/// A Flutter page that displays a monthly calendar with attendance, leave, holiday,
/// and work schedule information. Supports localization (including Eastern Arabic,
/// Persian, Bengali, Thai numerals, etc.), dark mode, month/year picker,
/// and detailed attendance view when a date is selected.
///
/// Features:
///   - Month navigation (prev/next & picker)
///   - Localized month/year display & numeral systems
///   - Visual indicators (dots) for present, absent, leave, holiday
///   - Selected date details: clock-in/out time, status, late/early flags
///   - Error handling states (no module, connection error, empty data)
///   - Refresh support via pull-to-refresh
class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  // Maps language codes to localized digit representations (Arabic, Persian, Urdu, Bengali, Thai, Myanmar)
  static Map<String, Map<String, String>> _digitMaps = {
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

  final List<String> months = [
    "January",
    "February",
    "March",
    "April",
    "May",
    "June",
    "July",
    "August",
    "September",
    "October",
    "November",
    "December",
  ];

  late String selectedMonth;
  late int selectedYear;
  DateTime? selectedDate;
  late CalendarBloc calendarBloc;

  /// Converts Western Arabic numerals to localized digits based on current language code.
  /// Falls back to original input if no mapping exists for the locale.
  String localeNumber(String input, String locale) {
    final code = locale.split('_').first.toLowerCase();
    final map = _digitMaps[code];
    if (map == null) return input;

    final buffer = StringBuffer();
    for (final ch in input.characters) {
      buffer.write(map[ch] ?? ch);
    }
    return buffer.toString();
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    selectedMonth = DateFormat.MMMM().format(now);
    selectedYear = now.year;
    selectedDate = now;
  }

  /// Returns list of years shown in the picker (±10 years from current year)
  List<int> get yearList {
    final currentYear = DateTime.now().year;
    return List.generate(21, (index) => currentYear - 10 + index);
  }

  /// Navigates to the previous month/year and triggers data reload
  void _goToPreviousMonth() {
    setState(() {
      final monthIndex = months.indexOf(selectedMonth);
      if (monthIndex == 0) {
        selectedMonth = months[11];
        selectedYear--;
      } else {
        selectedMonth = months[monthIndex - 1];
      }
      selectedDate = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CalendarBloc>().add(
        LoadCalendarData(month: selectedMonth, year: selectedYear),
      );
    });
  }

  /// Navigates to the next month/year and triggers data reload
  void _goToNextMonth() {
    setState(() {
      final monthIndex = months.indexOf(selectedMonth);
      if (monthIndex == 11) {
        selectedMonth = months[0];
        selectedYear++;
      } else {
        selectedMonth = months[monthIndex + 1];
      }
      selectedDate = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CalendarBloc>().add(
        LoadCalendarData(month: selectedMonth, year: selectedYear),
      );
    });
  }

  /// Shows month & year selection dialog with localized dropdowns
  /// Updates selected month/year and reloads calendar data on save
  void _showMonthYearPicker(langCode) async {
    String tempMonth = selectedMonth;
    int tempYear = selectedYear;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: tr(
            "Select Month & Year",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: isDark
                        ? const Color(0xFF2A2A2A)
                        : const Color(0xFFF2F4F6),
                    border: Border.all(color: Colors.transparent, width: 1),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton2<String>(
                      value: tempMonth,
                      isExpanded: true,
                      dropdownStyleData: DropdownStyleData(
                        maxHeight: 200,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: isDark ? Colors.grey[900] : Colors.white,
                        ),
                      ),
                      iconStyleData: const IconStyleData(
                        icon: Icon(Icons.keyboard_arrow_down, size: 16),
                      ),
                      underline: const SizedBox(),
                      items: months
                          .map((m) => DropdownMenuItem(value: m, child: tr(m)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          tempMonth = val;
                          (context as Element).markNeedsBuild();
                        }
                      },
                      buttonStyleData: ButtonStyleData(
                        height: 42,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: isDark
                        ? const Color(0xFF2A2A2A)
                        : const Color(0xFFF2F4F6),
                    border: Border.all(color: Colors.transparent, width: 1),
                  ),
                  child: DropdownButton2<int>(
                    value: tempYear,
                    isExpanded: true,
                    dropdownStyleData: DropdownStyleData(
                      maxHeight: 200,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: isDark ? Colors.grey[900] : Colors.white,
                      ),
                    ),
                    iconStyleData: const IconStyleData(
                      icon: Icon(Icons.keyboard_arrow_down, size: 16),
                    ),
                    underline: const SizedBox(),
                    items: yearList
                        .map(
                          (y) => DropdownMenuItem(
                            value: y,
                            child: Text(localeNumber(y.toString(), langCode)),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        tempYear = val;
                        (context as Element).markNeedsBuild();
                      }
                    },
                    buttonStyleData: ButtonStyleData(
                      height: 42,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                    ),
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
                        selectedMonth = tempMonth;
                        selectedYear = tempYear;
                        selectedDate = null;
                      });
                      context.read<CalendarBloc>().add(
                        LoadCalendarData(
                          month: selectedMonth,
                          year: selectedYear,
                        ),
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
  }

  /// Handles tap on a calendar day → updates selectedDate
  void _onDateSelected(int day) {
    setState(() {
      selectedDate = DateTime(
        selectedYear,
        months.indexOf(selectedMonth) + 1,
        day,
      );
    });
  }

  /// Custom back navigation with optional reduced motion support
  Future<bool> _handleBackNavigation() async {
    final motionProvider = Provider.of<MotionProvider>(context, listen: false);
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
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Main scaffold with pull-to-refresh, dark mode support, and state handling
    // ────────────────────────────────────────────────────────────────
    // States handled:
    //   • Loading
    //   • Loaded (normal calendar + details)
    //   • Error (generic, connection refused, module not installed)
    //   • Empty data
    // ────────────────────────────────────────────────────────────────
    return WillPopScope(
      onWillPop: _handleBackNavigation,
      child: Scaffold(
        backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async {
              final bloc = context.read<CalendarBloc>();
              final current = bloc.state;
              if (current is CalendarLoaded) {
                if (current.catchError) {
                  await context.read<CompanyProvider>().initialize();
                  ProfileRefreshBus.notifyProfileRefresh();
                  CompanyRefreshBus.notify();
                } else {
                  bloc.add(
                    LoadCalendarData(month: selectedMonth, year: selectedYear),
                  );
                }
              }
            },
            color: isDark ? Colors.white : AppStyle.primaryColor,
            child: Column(
              children: [
                Expanded(
                  child: BlocConsumer<CalendarBloc, CalendarState>(
                    listener: (context, state) {
                      if (state is CalendarError) {
                        CustomSnackbar.showError(context, state.message);
                      }
                    },
                    builder: (context, state) {
                      if (state is CalendarLoading) {
                        return Center(
                          child: LoadingAnimationWidget.threeArchedCircle(
                            color: isDark
                                ? Colors.white
                                : AppStyle.primaryColor,
                            size: 60,
                          ),
                        );
                      }
                      if (state is CalendarLoaded) {
                        if (state.isAppNotInstalled)
                          return _buildErrorModuleCheckState(isDark);
                        if (state.catchError) return _buildErrorState(isDark);
                        if (state.connectionError)
                          return _buildConnectionErrorState(isDark);
                        if (state.attendanceData.isEmpty)
                          return _buildEmptyState(isDark);

                        return _buildCalendarWithDetails(
                          state.attendanceData,
                          state.workSchedule,
                          isDark,
                        );
                      }
                      return Center(child: tr("Loading attendance data..."));
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Builds UI shown when a generic server/data error occurs
  Widget _buildErrorState(bool isDark) {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Lottie.asset('assets/Error_404.json', width: 300, height: 300),
              tr(
                'Something went wrong',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 8),
              tr(
                'Pull to refresh or tap retry',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
              const SizedBox(height: 20),
              OutlinedButton(
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
                child: tr('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds UI shown when connection to server is refused
  Widget _buildConnectionErrorState(bool isDark) {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Lottie.asset('assets/Error_404.json', width: 300, height: 300),
              tr(
                'Connection Refused',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 8),
              tr(
                'Pull to refresh or tap retry after connecting your server',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
              const SizedBox(height: 20),
              OutlinedButton(
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
                child: tr('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds UI shown when Time Off / Attendance module is not installed
  Widget _buildErrorModuleCheckState(bool isDark) {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Lottie.asset('assets/Error_404.json', width: 300, height: 300),
              tr(
                'Time Off module is not installed',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 8),
              tr(
                'Pull to refresh or tap retry after enable it',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
              const SizedBox(height: 20),
              OutlinedButton(
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
                child: tr('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds UI shown when no attendance data exists for the month
  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.asset('assets/empty_ghost.json', width: 300, height: 300),
          tr(
            "No data found",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 8),
          tr(
            'Check your internet or server connection',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  /// Returns appropriate HugeIcon for different attendance/leave/holiday statuses
  IconData _getInfoIconForStatus(String status) {
    switch (status.toUpperCase()) {
      case "WEEKEND":
        return HugeIcons.strokeRoundedSleeping;
      case "PUBLIC HOLIDAY":
      case "HOLIDAY":
        return HugeIcons.strokeRoundedStarFace;
      case "ON LEAVE":
      case "LEAVE":
        return HugeIcons.strokeRoundedUserBlock01;
      case "MANDATORY":
      case "MANDATORY DAY":
        return HugeIcons.strokeRoundedHourglass;
      case "ABSENT":
        return HugeIcons.strokeRoundedWifiOff01;
      case "FUTURE DATE":
        return HugeIcons.strokeRoundedTimeSchedule;
      default:
        return HugeIcons.strokeRoundedCalendar03;
    }
  }

  /// Returns human-friendly message explaining the current day status
  String _getFriendlyMessageForStatus(String status) {
    switch (status.toUpperCase()) {
      case "WEEKEND":
        return "It's weekend! No work scheduled.";
      case "PUBLIC HOLIDAY":
      case "HOLIDAY":
        return "Public holiday — Enjoy the day!";
      case "ON LEAVE":
      case "LEAVE":
        return "You're on approved leave today.";
      case "MANDATORY":
      case "MANDATORY DAY":
        return "Mandatory off day.";
      case "ABSENT":
        return "No attendance recorded for this day.";
      case "FUTURE DATE":
        return "This is a future date — attendance not available yet.";
      case "NO RECORD":
        return "No attendance data available.";
      default:
        return "No work details for this day.";
    }
  }

  /// Returns localized cached translation or falls back to key
  String catchTranslate(BuildContext context, String key) {
    final service = Provider.of<LanguageProvider>(context, listen: false);
    return service.getCached(key) ?? key;
  }

  String formatStatus(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1).toLowerCase();
  }

  /// Determines dot color shown under each calendar day
  Color? _getDotColorForDate(
    DateTime date,
    Map<String, Map<String, dynamic>> dayMap,
  ) {
    final String key = date.day.toString();
    final item = dayMap[key];
    if (item == null) return null;

    switch (item['type']) {
      case 'attendance':
        return Colors.green;

      case 'leave':
      case 'mandatory':
        return Colors.red;

      case 'holiday':
        return Colors.black.withOpacity(0.3);

      case 'normal':
      default:
        if (date.weekday != DateTime.sunday && !date.isAfter(DateTime.now())) {
          return Colors.yellow[700];
        }
        return null;
    }
  }

  String toTitleCase(String text) {
    if (text.isEmpty) return text;

    return text
        .toLowerCase()
        .split(' ')
        .map(
          (word) => word.isNotEmpty
              ? '${word[0].toUpperCase()}${word.substring(1)}'
              : '',
        )
        .join(' ');
  }

  /// Builds the main calendar view + selected date details panel
  Widget _buildCalendarWithDetails(
    List<Map<String, dynamic>> attendanceData,
    Map<int, Map<String, String>> workSchedule,
    bool isDark,
  ) {
    // ────────────────────────────────────────────────────────────────
    // Core logic section:
    //   1. Builds month grid with weekday headers
    //   2. Applies visual indicators (dots, Sunday opacity, holidays)
    //   3. Shows detailed attendance/clock-in-out info when date selected
    //   4. Displays late/early flags with color coding
    // ────────────────────────────────────────────────────────────────

    final langCode = context.watch<LanguageProvider>().currentCode;

    final int monthIndex = months.indexOf(selectedMonth) + 1;
    final DateTime firstDayOfMonth = DateTime(selectedYear, monthIndex, 1);
    final int daysInMonth = DateTime(selectedYear, monthIndex + 1, 0).day;
    final int startingWeekday = firstDayOfMonth.weekday % 7;

    final Map<String, Map<String, dynamic>> dayMap = {};
    for (var item in attendanceData) {
      dayMap[item['date']] = item;
    }

    final String selectedDayStr = selectedDate != null
        ? selectedDate!.day.toString()
        : "";
    final Map<String, dynamic>? selectedDayData = dayMap[selectedDayStr];
    final String displayDate = selectedDate != null
        ? localeNumber(
            DateFormat('MMM d, yyyy').format(selectedDate!),
            langCode,
          )
        : catchTranslate(context, "Select a date");

    final DateTime refDate = selectedDate ?? DateTime.now();
    final int weekdayIndex = refDate.weekday - 1;

    final double workFromHour =
        double.tryParse(workSchedule[weekdayIndex]?['work_from'] ?? "9.0") ??
        9.0;
    final double workToHour =
        double.tryParse(workSchedule[weekdayIndex]?['work_to'] ?? "17.5") ??
        17.5;

    final DateTime shiftFrom = _shiftToDate(refDate, workFromHour);
    final DateTime shiftTo = _shiftToDate(refDate, workToHour);

    final String shiftTime =
        "${_formatHour(workFromHour)}-${_formatHour(workToHour)}";

    String clockIn = "--:--";
    String clockOut = "--:--";
    String totalHours = "--";
    String status = "No Record";

    DateTime? rawClockIn;
    DateTime? rawClockOut;
    final bool shouldShowAttendanceDetails =
        selectedDayData != null && selectedDayData['type'] == 'attendance';
    final bool hasSelectedDate = selectedDate != null;

    if (selectedDayData != null) {
      switch (selectedDayData['type']) {
        case 'holiday':
          status =
              selectedDayData['data']?.toString().toUpperCase() ??
              "PUBLIC HOLIDAY";
          break;
        case 'leave':
          status =
              selectedDayData['data']?.toString().toUpperCase() ?? "ON LEAVE";
          break;
        case 'mandatory':
          status =
              selectedDayData['data']?.toString().toUpperCase() ??
              "MANDATORY DAY";
          break;
        case 'attendance':
          final att = selectedDayData['data'] as Map<String, dynamic>;

          DateTime? ci;
          DateTime? co;

          if (att['check_in'] != null) {
            ci = DateFormat('yyyy-MM-dd hh:mm a').parse(att['check_in']);
            rawClockIn = ci;
            clockIn = _formatTime(att['check_in']);
          }

          if (att['check_out'] != null) {
            co = DateFormat('yyyy-MM-dd hh:mm a').parse(att['check_out']);
            rawClockOut = co;
          }

          if (ci != null && co != null) {
            if (co.day != ci.day ||
                co.month != ci.month ||
                co.year != ci.year) {
              co = DateTime(ci.year, ci.month, ci.day, 24, -1);
              rawClockOut = co;
            }
            clockOut = DateFormat('hh:mm a').format(co);

            final Duration diff = co.difference(ci);
            final int h = diff.inHours;
            final int m = diff.inMinutes.remainder(60);
            totalHours = "$h:${m.toString().padLeft(2, '0')} HRS";
          } else if (att['worked_hours'] != null) {
            final double? worked = att['worked_hours'] as double?;
            if (worked != null) {
              final h = worked.floor();
              final m = ((worked - h) * 60).round();
              totalHours = "$h:${m.toString().padLeft(2, '0')} HRS";
            }
          }

          status = "PRESENT";
          break;

        default:
          final DateTime date = DateTime(
            selectedYear,
            monthIndex,
            int.parse(selectedDayStr),
          );
          if (date.weekday == DateTime.sunday) {
            status = "WEEKEND";
          } else if (date.isAfter(DateTime.now())) {
            status = "FUTURE DATE";
          } else {
            status = "ABSENT";
          }
      }
    }
    Color getClockInColor(bool isDark) {
      if (rawClockIn == null) return Colors.grey;
      return rawClockIn!.isAfter(shiftFrom) ? Colors.red : Colors.green;
    }

    Color getClockOutColor(bool isDark) {
      if (rawClockOut == null) return Colors.grey;
      return rawClockOut!.isBefore(shiftTo) ? Colors.red : Colors.green;
    }

    final inStatus = getClockInStatus(rawClockIn, shiftFrom);
    final outStatus = getClockOutStatus(rawClockOut, shiftTo);

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? Colors.black26
                          : Colors.black.withOpacity(0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left, size: 30),
                          color: isDark ? Colors.white : Colors.black,
                          onPressed: () => _goToPreviousMonth(),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _showMonthYearPicker(langCode),
                            child: Center(
                              child: Text(
                                "${catchTranslate(context, selectedMonth)} ${localeNumber(selectedYear.toString(), langCode)}",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right, size: 30),
                          color: isDark ? Colors.white : Colors.black,
                          onPressed: () => _goToNextMonth(),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildCalendarLegend(isDark),
                    ),

                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: List.generate(7, (i) {
                          final days = [
                            'SUN',
                            'MON',
                            'TUE',
                            'WED',
                            'THU',
                            'FRI',
                            'SAT',
                          ];
                          return Expanded(
                            child: Center(
                              child: tr(
                                days[i],
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 7,
                              childAspectRatio: 1.1,
                            ),
                        itemCount: startingWeekday + daysInMonth,
                        itemBuilder: (context, index) {
                          final bool isCurrentMonth =
                              index >= startingWeekday &&
                              index < startingWeekday + daysInMonth;

                          if (index < startingWeekday) {
                            return const SizedBox();
                          }

                          final int dayNumber = index - startingWeekday + 1;
                          final DateTime date = DateTime(
                            selectedYear,
                            monthIndex,
                            dayNumber,
                          );

                          final bool isToday =
                              DateTime.now().year == date.year &&
                              DateTime.now().month == date.month &&
                              DateTime.now().day == date.day;

                          final bool isSelected =
                              selectedDate != null &&
                              selectedDate!.year == date.year &&
                              selectedDate!.month == date.month &&
                              selectedDate!.day == date.day;

                          final bool isSunday = date.weekday == DateTime.sunday;
                          final Color? dotColor = _getDotColorForDate(
                            date,
                            dayMap,
                          );

                          final String dayKey = date.day.toString();
                          final Map<String, dynamic>? dayData = dayMap[dayKey];

                          final bool isHoliday =
                              dayData != null && dayData['type'] == 'holiday';

                          return GestureDetector(
                            onTap: isCurrentMonth
                                ? () => _onDateSelected(dayNumber)
                                : null,
                            child: Opacity(
                              opacity: isCurrentMonth ? 1 : 0.4,
                              child: Container(
                                margin: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppStyle.primaryColor.withOpacity(0.18)
                                      : Colors.transparent,
                                  shape: BoxShape.circle,
                                  border: (isToday && !isSelected)
                                      ? Border.all(
                                          color: Colors.blue[200]!,
                                          width: 2,
                                        )
                                      : null,
                                ),
                                child: Stack(
                                  children: [
                                    Center(
                                      child: Text(
                                        "$dayNumber",
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: isSelected || isToday
                                              ? FontWeight.bold
                                              : FontWeight.w600,
                                          color: isHoliday
                                              ? Colors.black.withOpacity(0.3)
                                              : isSunday
                                              ? Colors.black54
                                              : isDark
                                              ? Colors.white
                                              : (isSelected
                                                    ? AppStyle.primaryColor
                                                    : Colors.black),
                                        ),
                                      ),
                                    ),
                                    if (dotColor != null && !isHoliday)
                                      Positioned(
                                        bottom: 3,
                                        left: 0,
                                        right: 0,
                                        child: Center(
                                          child: Container(
                                            width: 4,
                                            height: 4,
                                            decoration: BoxDecoration(
                                              color: dotColor,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    SizedBox(height: 10),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? Colors.black26
                          : Colors.black.withOpacity(0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      if (!shouldShowAttendanceDetails) ...[
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isDark
                                ? _getStatusColor(
                                    status,
                                    isDark,
                                  ).withOpacity(0.6)
                                : _getStatusColor(
                                    status,
                                    isDark,
                                  ).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            _getInfoIconForStatus(status),
                            size: 24,
                            color: isDark
                                ? Colors.white
                                : _getStatusColor(status, isDark),
                          ),
                        ),
                        SizedBox(width: 12),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  displayDate,
                                  textHeightBehavior: const TextHeightBehavior(
                                    applyHeightToFirstAscent: false,
                                    applyHeightToLastDescent: false,
                                  ),
                                  style: shouldShowAttendanceDetails
                                      ? TextStyle(
                                          fontSize: 16,
                                          height: 1.0,
                                          fontWeight: FontWeight.w600,
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black,
                                        )
                                      : TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.white.withOpacity(0.15)
                                        : _getStatusColor(
                                            status,
                                            isDark,
                                          ).withOpacity(0.10),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    formatStatus(status),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: _getStatusColor(status, isDark),
                                      letterSpacing: 0.1,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (hasSelectedDate) ...[
                              const SizedBox(height: 4),
                              Text(
                                shouldShowAttendanceDetails
                                    ? "${catchTranslate(context, 'Shift Time')} $shiftTime"
                                    : _getFriendlyMessageForStatus(status),
                                textHeightBehavior: const TextHeightBehavior(
                                  applyHeightToFirstAscent: false,
                                  applyHeightToLastDescent: false,
                                ),
                                style: shouldShowAttendanceDetails
                                    ? TextStyle(
                                        fontSize: 14,
                                        height: 1.05,
                                        color: isDark
                                            ? Colors.white70
                                            : Colors.black87,
                                      )
                                    : TextStyle(
                                        fontSize: 12,
                                        color: isDark
                                            ? Colors.grey[400]!
                                            : Colors.grey[600]!,
                                      ),
                              ),
                            ] else ...[
                              SizedBox(height: 10),
                              tr(
                                "Tap a date to view details",
                                style: TextStyle(
                                  fontSize: 14,
                                  height: 1.05,
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.black87,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (hasSelectedDate && shouldShowAttendanceDetails) ...[
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: isDark
                            ? Colors.black26
                            : Colors.black.withOpacity(0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(
                      right: 24.0,
                      left: 8,
                      bottom: 16,
                      top: 16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDetailRow(
                          "${catchTranslate(context, 'Clock In')}",
                          localeNumber(clockIn, langCode),
                          getClockInColor(isDark),
                          isDark,
                          showBottomLine: true,
                          sideText: inStatus.text,
                          sideColor: inStatus.color,
                        ),

                        _buildDetailRow(
                          "${catchTranslate(context, 'Clock Out')}",
                          localeNumber(clockOut, langCode),
                          getClockOutColor(isDark),
                          isDark,
                          showTopLine: true,
                          showBottomLine: false,
                          sideText: outStatus.text,
                          sideColor: outStatus.color,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ],
        ),
      ),
    );
  }

  /// Converts decimal hour (e.g. 9.5 → 9:30) into DateTime for comparison
  DateTime _shiftToDate(DateTime base, double hour) {
    final h = hour.floor();
    final m = ((hour - h) * 60).round();
    return DateTime(base.year, base.month, base.day, h, m);
  }

  /// Renders small legend explaining meaning of each dot color
  Widget _buildCalendarLegend(bool isDark) {
    Widget item(Color color, String label) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          tr(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          item(Colors.green, "Present"),
          item(Colors.yellow[700]!, "Absent"),
          item(Colors.red, "Leave"),
          item(Colors.black.withOpacity(0.3), "Holiday"),
        ],
      ),
    );
  }

  /// Builds one row in the attendance detail section (clock-in / clock-out)
  Widget _buildDetailRow(
    String label,
    String value,
    Color dotColor,
    bool isDark, {
    bool showTopLine = false,
    bool showBottomLine = false,
    String? sideText,
    Color? sideColor,
  }) {
    const rowHeight = 30.0;

    return SizedBox(
      height: rowHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,

        children: [
          SizedBox(
            width: 28,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double centerY = rowHeight / 2;
                final double centerX = constraints.maxWidth / 2;

                const double dotSize = 10;
                const double lineWidth = 2;

                return Stack(
                  children: [
                    if (showTopLine)
                      Positioned(
                        top: 0,
                        left: centerX - lineWidth / 2,
                        child: Container(
                          width: lineWidth,
                          height: centerY - dotSize / 2,
                          color: AppStyle.primaryColor.withOpacity(0.5),
                        ),
                      ),

                    if (showBottomLine)
                      Positioned(
                        top: centerY + dotSize / 2,
                        left: centerX - lineWidth / 2,
                        child: Container(
                          width: lineWidth,
                          height: centerY - dotSize / 2,
                          color: AppStyle.primaryColor.withOpacity(0.5),
                        ),
                      ),

                    Positioned(
                      top: centerY - dotSize / 2,
                      left: centerX - dotSize / 2,
                      child: Container(
                        width: dotSize,
                        height: dotSize,
                        decoration: BoxDecoration(
                          color: AppStyle.primaryColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppStyle.primaryColor,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          const SizedBox(width: 8),

          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                tr(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : sideColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Determines status text & color for clock-out time (early/late/on-time)
  AttendanceStatus getClockOutStatus(DateTime? clockOut, DateTime shiftTo) {
    if (clockOut == null) return const AttendanceStatus("—", Colors.grey);

    if (clockOut.isBefore(shiftTo)) {
      return const AttendanceStatus("Early Out", Colors.red);
    } else if (clockOut.isAfter(shiftTo)) {
      return const AttendanceStatus("Late Out", Colors.green);
    } else {
      return const AttendanceStatus("On Time", Colors.green);
    }
  }

  /// Determines status text & color for clock-in time (early/late/on-time)
  AttendanceStatus getClockInStatus(DateTime? clockIn, DateTime shiftFrom) {
    if (clockIn == null) return const AttendanceStatus("—", Colors.grey);

    if (clockIn.isAfter(shiftFrom)) {
      return const AttendanceStatus("Late In", Colors.red);
    } else if (clockIn.isBefore(shiftFrom)) {
      return const AttendanceStatus("Early In", Colors.green);
    } else {
      return const AttendanceStatus("On Time", Colors.green);
    }
  }

  /// Returns appropriate color for status badges and icons
  Color _getStatusColor(String status, bool isDark) {
    switch (status) {
      case "PRESENT":
        return Colors.green;
      case "ABSENT":
        return Colors.yellow[700]!;
      case "ON LEAVE":
        return Colors.red;
      case "PUBLIC HOLIDAY":
        return Colors.black.withOpacity(0.3);
      case "WEEKEND":
        return Colors.grey;
      default:
        return isDark ? Colors.white70 : Colors.black87;
    }
  }

  /// Formats decimal hour to HH:mm string (used for shift time display)
  String _formatHour(double hour) {
    final h = hour.floor();
    final m = ((hour - h) * 60).round();
    return "${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}";
  }

  /// Safely formats raw check-in/out time string to hh:mm a format
  String _formatTime(String? raw) {
    if (raw == null) return "--:--";
    try {
      final dt = DateFormat('yyyy-MM-dd hh:mm a').parse(raw);
      return DateFormat('hh:mm a').format(dt);
    } catch (e) {
      return "--:--";
    }
  }
}

/// Simple value class used to represent clock-in/out status (text + color)
class AttendanceStatus {
  final String text;
  final Color color;

  const AttendanceStatus(this.text, this.color);
}
