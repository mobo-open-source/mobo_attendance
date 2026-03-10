import 'dart:convert';
import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:lottie/lottie.dart';
import 'package:mobo_attendance/CommonWidgets/globals.dart';
import 'package:mobo_attendance/CommonWidgets/shared/widgets/snackbar.dart';
import 'package:mobo_attendance/MainScreens/AppBars/infrastructure/profile_refresh_bus.dart';
import 'package:provider/provider.dart';

import '../../../../CommonWidgets/core/company/infrastructure/company_refresh_bus.dart';
import '../../../../CommonWidgets/core/company/providers/company_provider.dart';
import '../../../../CommonWidgets/core/language/translate_widget.dart';
import '../../../../CommonWidgets/core/providers/language_provider.dart';
import '../../../../CommonWidgets/core/providers/motion_provider.dart';
import '../../../AppBars/pages/common_app_bar.dart';
import '../../../Employees/EmployeeList/bloc/employee_list_bloc.dart';
import '../../../Employees/EmployeeList/pages/employee_list_page.dart';
import '../../LeaveHistory/pages/leave_history_page.dart';
import '../../PendingLeaves/pages/pending_leave_page.dart';
import '../../Report/pages/report_page.dart';
import '../../RequestAbsence/pages/request_absence_page.dart';
import '../bloc/attendance_dashboard_bloc.dart';
import '../widgets/dashboard_shimmer.dart';

/// Main attendance dashboard screen.
///
/// Displays different content based on user role:
/// * Regular employee → personal check-in/out button, today's hours, leave actions
/// * Admin / Leave Manager → team statistics, punctuality breakdown chart, absenteeism trend,
///   pending leave approvals, reports link, etc.
///
/// Features:
/// * Dark/light theme support
/// * Localization-aware number & time formatting
/// * Pull-to-refresh
/// * Motion reduction support
/// * Error & loading states with retry
class AttendanceDashboardPage extends StatelessWidget {
  const AttendanceDashboardPage({super.key});

  // ---------------------------------------------------------------------------
  //  Localization / Formatting Helpers
  // ---------------------------------------------------------------------------

  static Map<String, Map<String, String>> _relativeWords = {
    'ar': {
      'ago': 'قبل',
      'Today': 'اليوم',
      'Yesterday': 'أمس',
      'd': 'ي',
      'AM': 'ص',
      'PM': 'م',
    },
    'fa': {
      'ago': 'قبل',
      'Today': 'امروز',
      'Yesterday': 'دیروز',
      'd': 'ر',
      'AM': 'ق.ظ',
      'PM': 'ب.ظ',
    },
    'ur': {
      'ago': 'قبل',
      'Today': 'آج',
      'Yesterday': 'کل',
      'd': 'د',
      'AM': 'صبح',
      'PM': 'شام',
    },
    'bn': {
      'ago': 'আগে',
      'Today': 'আজ',
      'Yesterday': 'গতকাল',
      'd': 'দি',
      'AM': 'পূর্বাহ্ণ',
      'PM': 'অপরাহ্ণ',
    },
    'th': {
      'ago': 'วันที่แล้ว',
      'Today': 'วันนี้',
      'Yesterday': 'เมื่อวาน',
      'd': 'ว',
      'AM': 'ก่อนเที่ยง',
      'PM': 'หลังเที่ยง',
    },
    'my': {
      'ago': 'အရင်',
      'Today': 'ယနေ့',
      'Yesterday': 'မနေ့က',
      'd': 'ရ',
      'AM': 'နံနက်',
      'PM': 'ညနေ',
    },
  };

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

  /// Converts Latin digits (0-9) to locale-specific native digits
  String localeNumber(String input, String locale) {
    final code = locale.split('_').first.toLowerCase();
    final map = _digitMaps[code];
    if (map == null) return input;

    map.forEach((latin, native) {
      input = input.replaceAll(latin, native);
    });
    return input;
  }

  /// Applies locale-specific formatting to time strings (digits + AM/PM words)
  String localeTime(String input, String locale) {
    final code = locale.split('_').first.toLowerCase();

    final digitMap = _digitMaps[code];
    if (digitMap != null) {
      digitMap.forEach((latin, native) {
        input = input.replaceAll(latin, native);
      });
    }

    final words = _relativeWords[code];
    if (words != null) {
      input = input
          .replaceAll('AM', words['AM'] ?? 'AM')
          .replaceAll('PM', words['PM'] ?? 'PM');
    }

    return input;
  }

  /// Localizes relative date expressions like "Today", "Yesterday", "3d ago"
  String localeLabel(String label, String locale, BuildContext context) {
    final code = locale.split('_').first.toLowerCase();
    final words = _relativeWords[code];
    if (label == 'Today') {
      return words != null ? words['Today']! : catchTranslate(context, 'Today');
    }
    if (label == 'Yesterday') {
      return words != null
          ? words['Yesterday']!
          : catchTranslate(context, 'Yesterday');
    }
    final reg = RegExp(r'(\d+)(d)\s(ago)');
    final match = reg.firstMatch(label);

    if (match != null) {
      final number = localeNumber(match.group(1)!, locale);
      final dText = words != null ? words['d']! : catchTranslate(context, 'd');
      final agoText = words != null
          ? words['ago']!
          : catchTranslate(context, 'ago');

      return '$number$dText $agoText';
    }
    return localeNumber(label, locale);
  }

  // ---------------------------------------------------------------------------
  //  Main Build Method
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final motionProvider = Provider.of<MotionProvider>(context, listen: false);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
      body: BlocConsumer<AttendanceDashboardBloc, AttendanceDashboardState>(
        listener: (context, state) {
          if (state.errorMessage != null) {
            CustomSnackbar.showError(context, state.errorMessage!);
          }
        },
        builder: (context, state) {
          if (state.isLoading && !state.leaveAction) {
            return DashboardShimmer(isDark: isDark);
          }
          if (state.catchError) {
            return RefreshIndicator(
              onRefresh: () async {
                await context.read<CompanyProvider>().initialize();
                ProfileRefreshBus.notifyProfileRefresh();
                CompanyRefreshBus.notify();
              },
              color: isDark ? Colors.white : AppStyle.primaryColor,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Center(
                  child: Container(
                    height: MediaQuery.of(context).size.height * 0.8,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Lottie.asset(
                          'assets/Error_404.json',
                          width: 300,
                          height: 300,
                          fit: BoxFit.contain,
                          repeat: true,
                          animate: true,
                        ),
                        tr(
                          'Something went wrong',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(height: 8),
                        tr(
                          'Pull to refresh or tap retry',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.normal,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton(
                          onPressed: () async {
                            await context.read<CompanyProvider>().initialize();
                            ProfileRefreshBus.notifyProfileRefresh();
                            CompanyRefreshBus.notify();
                          },
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
                          child: tr(
                            'Retry',
                            style: TextStyle(
                              color: isDark
                                  ? Colors.white
                                  : AppStyle.primaryColor,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }
          if (state.connectionError) {
            return RefreshIndicator(
              onRefresh: () async {
                await context.read<CompanyProvider>().initialize();
                ProfileRefreshBus.notifyProfileRefresh();
                CompanyRefreshBus.notify();
              },
              color: isDark ? Colors.white : AppStyle.primaryColor,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Center(
                  child: Container(
                    height: MediaQuery.of(context).size.height * 0.8,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Lottie.asset(
                          'assets/Error_404.json',
                          width: 300,
                          height: 300,
                          fit: BoxFit.contain,
                          repeat: true,
                          animate: true,
                        ),
                        tr(
                          'Connection Refused',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(height: 8),
                        tr(
                          'Pull to refresh or tap retry after connecting your server',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.normal,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton(
                          onPressed: () async {
                            await context.read<CompanyProvider>().initialize();
                            ProfileRefreshBus.notifyProfileRefresh();
                            CompanyRefreshBus.notify();
                          },
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
                          child: tr(
                            'Retry',
                            style: TextStyle(
                              color: isDark
                                  ? Colors.white
                                  : AppStyle.primaryColor,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              context.read<AttendanceDashboardBloc>().add(LoadDashboardData());
            },
            color: isDark ? Colors.white : AppStyle.primaryColor,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderCard(context, state, isDark),

                  const SizedBox(height: 24),

                  if (!state.accessForAdmin) ...[
                    _buildCheckInOutButton(context, state, isDark),
                    const SizedBox(height: 16),
                  ],

                  state.accessForAdmin
                      ? _buildAdminOverview(context, state, isDark)
                      : _buildEmployeeHoursCards(state, isDark, context),

                  const SizedBox(height: 24),
                  if (!state.accessForAdmin) ...[
                    _buildActionButtonsRow(
                      context,
                      state,
                      motionProvider,
                      isDark,
                    ),
                  ],

                  const SizedBox(height: 24),

                  if (!state.accessForAdmin &&
                      !state.accessForLeaveManager) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: tr(
                        'Recent Activity',
                        style: TextStyle(
                          fontSize: 18,
                          fontFamily: GoogleFonts.inter().fontFamily,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                    SizedBox(height: 12),
                    _buildRecentActivitySection(state, isDark, context),
                  ],
                  if (!state.accessForAdmin && state.accessForLeaveManager) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: tr(
                        'Recent Activity',
                        style: TextStyle(
                          fontSize: 18,
                          fontFamily: GoogleFonts.inter().fontFamily,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                    SizedBox(height: 12),
                    _buildRecentActivitySection(state, isDark, context),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Returns time-of-day based greeting ("Good Morning", "Good Afternoon", etc.)
  String getTimeGreeting(BuildContext context) {
    final hour = DateTime.now().hour;

    if (hour >= 5 && hour < 12) {
      return catchTranslate(context, "Good Morning");
    } else if (hour >= 12 && hour < 17) {
      return catchTranslate(context, "Good Afternoon");
    } else if (hour >= 17 && hour < 21) {
      return catchTranslate(context, "Good Evening");
    } else {
      return catchTranslate(context, "Good Night");
    }
  }

  // ---------------------------------------------------------------------------
  //  UI Building Sections
  // ---------------------------------------------------------------------------

  /// Builds the top greeting + profile picture card
  Widget _buildHeaderCard(
    BuildContext context,
    AttendanceDashboardState state,
    bool isDark,
  ) {
    final translationService = context.watch<LanguageProvider>();
    final bool isSvg =
        state.profileImageBytes != null &&
        utf8
            .decode(state.profileImageBytes!, allowMalformed: true)
            .contains('<svg');

    final textGreeting = getTimeGreeting(context);
    final adminDescription =
        translationService.getCached(
          "Here's today's overview of your workforce attendance and activities",
        ) ??
        "Here's today's overview of your workforce attendance and activities";

    final userDescription =
        translationService.getCached(
          "Track and manage your attendance smoothly",
        ) ??
        "Track and manage your attendance smoothly";

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF2A2A2A), const Color(0xFF2A2A2A)]
              : [AppStyle.primaryColor, AppStyle.primaryColor.withOpacity(0.9)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${textGreeting} ${state.userName ?? ''}',
                  style: GoogleFonts.manrope(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    height: 1.2,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.visible,
                ),
                const SizedBox(height: 6),
                Text(
                  state.accessForAdmin
                      ? '$adminDescription'
                      : '$userDescription',
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    letterSpacing: 0,
                    fontWeight: FontWeight.w400,
                    height: 1.3,
                    color: isDark
                        ? Colors.white
                        : Colors.white.withOpacity(0.9),
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.visible,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: ClipOval(
              child: state.profileImageBytes != null
                  ? (isSvg
                        ? SvgPicture.memory(
                            state.profileImageBytes!,
                            fit: BoxFit.cover,
                          )
                        : Image.memory(
                            state.profileImageBytes!,
                            fit: BoxFit.cover,
                          ))
                  : Icon(
                      HugeIcons.strokeRoundedUser,
                      size: 30,
                      color: Colors.white.withOpacity(0.9),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  /// Renders large check-in / check-out button (employee view only)
  Widget _buildCheckInOutButton(
    BuildContext context,
    AttendanceDashboardState state,
    bool isDark,
  ) {
    final translationService = context.watch<LanguageProvider>();
    final checkout = translationService.getCached("CHECK OUT");
    final checkIn = translationService.getCached("CHECK IN");
    final loading = translationService.getCached("Loading...");

    final bloc = context.read<AttendanceDashboardBloc>();

    final String label = state.isCheckIn ? '$checkout' : '$checkIn';
    final IconData icon = state.isCheckIn
        ? HugeIcons.strokeRoundedLogout02
        : HugeIcons.strokeRoundedLogin02;
    final Color color = state.isCheckIn ? Colors.red : Colors.green;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: state.isCheckInLoading
            ? null
            : () => state.isCheckIn
                  ? bloc.add(CheckOutRequested())
                  : bloc.add(CheckInRequested()),
        style: OutlinedButton.styleFrom(
          foregroundColor: isDark ? Colors.white : Colors.black87,
          backgroundColor: isDark ? Colors.grey[900] : Colors.white,
          side: BorderSide(color: isDark ? Colors.white : color, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        icon: state.isCheckInLoading
            ? LoadingAnimationWidget.staggeredDotsWave(
                color: isDark ? Colors.white : color,
                size: 24,
              )
            : Icon(icon, color: isDark ? Colors.white : color),
        label: Text(
          state.isCheckInLoading ? '$loading' : label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : color,
          ),
        ),
      ),
    );
  }

  /// Admin/Leave Manager overview: stats cards, reports, pending leaves, charts
  Widget _buildAdminOverview(
    BuildContext context,
    AttendanceDashboardState state,
    bool isDark,
  ) {
    final motionProvider = Provider.of<MotionProvider>(context, listen: false);
    final translationService = context.read<LanguageProvider>();
    final locale = translationService.currentCode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: tr(
            'Attendance Overview',
            style: TextStyle(
              fontSize: 18,
              fontFamily: GoogleFonts.inter().fontFamily,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ),
        const SizedBox(height: 12),

        GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.2,
          ),
          children: [
            _buildDashboardCard(
              context,
              title: catchTranslate(context, 'Total Staff'),
              icon: HugeIcons.strokeRoundedUserGroup,
              color: const Color(0xFF4CAF50),
              count: state.staffCount?.toString() ?? "0",
              subtitle: catchTranslate(context, 'Total active staff members'),
              onTap: () {
                final motionProvider = Provider.of<MotionProvider>(
                  context,
                  listen: false,
                );
                Navigator.pushReplacement(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (_, __, ___) =>
                        const CommonAppBar(initialIndex: 1),
                    transitionDuration: motionProvider.reduceMotion
                        ? Duration.zero
                        : const Duration(milliseconds: 300),
                    transitionsBuilder: (_, animation, __, child) =>
                        motionProvider.reduceMotion
                        ? child
                        : FadeTransition(opacity: animation, child: child),
                  ),
                );
              },
            ),
            _buildDashboardCard(
              context,
              title: catchTranslate(context, 'Present'),
              icon: HugeIcons.strokeRoundedUserCheck01,
              color: const Color(0xFF4991E4),
              count: state.staffPresentCount?.toString() ?? "0",
              subtitle: catchTranslate(context, 'Employees present for today'),
              onTap: () {
                _navigateToEmployeeList(
                  context,
                  state.staffPresentIds ?? [],
                  "Present Employees",
                );
              },
            ),
            _buildDashboardCard(
              context,
              title: catchTranslate(context, 'Absent'),
              icon: HugeIcons.strokeRoundedUserRemove01,
              color: const Color(0xFFF30B0B),
              count: state.staffAbsentCount?.toString() ?? "0",
              subtitle: catchTranslate(context, 'Employees absent for today'),
              onTap: () {
                _navigateToEmployeeList(
                  context,
                  state.staffAbsentIds ?? [],
                  "Absent Employees",
                );
              },
            ),
            _buildDashboardCard(
              context,
              title: catchTranslate(context, 'Status'),
              icon: HugeIcons.strokeRoundedProgress02,
              color: const Color(0xFFE6A936),
              countWidget: Text(
                "${localeNumber((state.staffPresentCount ?? 0).toString(), locale)}  / ${localeNumber((state.staffCount ?? 0).toString(), locale)}",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              subtitle: catchTranslate(context, 'Current availability'),
              onTap: () {
                _navigateToEmployeeList(
                  context,
                  state.staffPresentIds ?? [],
                  "Present Employees",
                );
              },
            ),
          ],
        ),
        SizedBox(height: 30),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: tr(
            'Reports & Approvals',
            style: TextStyle(
              fontSize: 18,
              fontFamily: GoogleFonts.inter().fontFamily,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ),
        SizedBox(height: 12),

        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (_, __, ___) => ReportPage(),
                transitionDuration: motionProvider.reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 300),
                transitionsBuilder: (_, animation, __, child) =>
                    motionProvider.reduceMotion
                    ? child
                    : FadeTransition(opacity: animation, child: child),
              ),
            );
          },
          child: Container(
            constraints: const BoxConstraints(minHeight: 80),
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[850] : Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black26
                      : Colors.black.withOpacity(0.05),
                  blurRadius: 16,
                  spreadRadius: 2,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Color(0xFF6A4FC6).withOpacity(0.6)
                        : Color(0xFF6A4FC6).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    HugeIcons.strokeRoundedTransactionHistory,
                    size: 24,
                    color: isDark ? Colors.white : Color(0xFF6A4FC6),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      tr(
                        'View Reports',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      tr(
                        'Check reports of your team’s attendance',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        softWrap: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        GestureDetector(
          onTap: () {
            if (!state.isAppNotInstalled)
              Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (_, __, ___) => PendingLeavePage(),
                  transitionDuration: motionProvider.reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 300),
                  transitionsBuilder: (_, animation, __, child) =>
                      motionProvider.reduceMotion
                      ? child
                      : FadeTransition(opacity: animation, child: child),
                ),
              );
          },
          child: Container(
            constraints: const BoxConstraints(minHeight: 80),
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[850] : Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black26
                      : Colors.black.withOpacity(0.05),
                  blurRadius: 16,
                  spreadRadius: 2,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Color(0xFFF48C06).withOpacity(0.6)
                        : Color(0xFFF48C06).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    HugeIcons.strokeRoundedAlertDiamond,
                    size: 24,
                    color: isDark ? Colors.white : Color(0xFFF48C06),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      tr(
                        'Pending Approvals',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      tr(
                        state.isAppNotInstalled
                            ? ("Time Off module is not installed yet, ${state.accessForAdmin ? ("Please enable it from Apps") : ("Please contact your administrator to enable it")} for getting this feature")
                            : ('${localeNumber(state.leavePendingCount.toString(), locale)} ${catchTranslate(context, 'Leaves awaiting your review')}'),
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[400]! : Colors.grey[600]!,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        softWrap: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        SizedBox(height: 30),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: tr(
            'Attendance Trends & Insights',
            style: TextStyle(
              fontSize: 18,
              fontFamily: GoogleFonts.inter().fontFamily,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ),
        SizedBox(height: 12),

        SizedBox(
          height: 250,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[850] : Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: isDark ? Colors.black26 : Colors.grey.withOpacity(0.2),
                  blurRadius: 6,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: _punctualityBarChart(state, isDark, context),
          ),
        ),
        SizedBox(height: 20),
        SizedBox(
          height: 250,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[850] : Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: isDark ? Colors.black26 : Colors.grey.withOpacity(0.2),
                  blurRadius: 6,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: _absenteesTrendLineChart(state, isDark, context),
          ),
        ),

        SizedBox(height: 30),
      ],
    );
  }

  void _navigateToEmployeeList(
    BuildContext context,
    List<int> ids,
    String title,
  ) {
    if (ids.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider(
          create: (context) => EmployeeListBloc(
            preAppliedEmployeeIds: ids,
            preAppliedFilterName: title,
            preApplied: true,
          )..add(InitializeEmployeeList()),
          child: const EmployeeListPage(),
        ),
      ),
    );
  }

  /// Reusable stat card used in admin overview
  Widget _buildDashboardCard(
    BuildContext context, {
    required String title,
    String? count,
    Widget? countWidget,
    required String subtitle,
    required Color color,
    VoidCallback? onTap,
    IconData? icon,
    Widget? trailingWidget,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final translationService = context.read<LanguageProvider>();
    final locale = translationService.currentCode;

    return GestureDetector(
      onTap: onTap,

      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[850] : Colors.white,
          borderRadius: BorderRadius.circular(12),

          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withOpacity(0.15)
                  : color.withOpacity(0.08),
              blurRadius: 6,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        countWidget ??
                            Text(
                              localeNumber(count ?? "0", locale),
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                        const SizedBox(height: 4),
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.grey[300] : Colors.grey[700],
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? color.withOpacity(0.6)
                          : color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child:
                        trailingWidget ??
                        (icon != null
                            ? Icon(
                                icon,
                                size: 20,
                                color: isDark ? Colors.white : color,
                              )
                            : const SizedBox()),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Bar chart showing On Time / Early / Late / Absent breakdown
  Widget _punctualityBarChart(
    AttendanceDashboardState state,
    bool isDark,
    BuildContext context,
  ) {
    final attendance = state.attendanceStatus;

    final onTime = state.staffOnTimeCount ?? 0;
    final onTimeIds = attendance?.onTimeIds ?? [];
    final earlyIn = state.staffEarlyInCount ?? 0;
    final earlyInIds = attendance?.earlyInIds ?? [];
    final lateIn = state.staffLateInCount ?? 0;
    final lateInIds = attendance?.lateInIds ?? [];
    final absent = state.staffAbsentCount ?? 0;
    final absentIds = state.staffAbsentIds ?? [];
    final bool hasData =
        onTime != 0 || earlyIn != 0 || lateIn != 0 || absent != 0;
    final maxValue = [onTime, earlyIn, lateIn, absent].reduce(max).toDouble();
    final double interval = (maxValue / 4)
        .ceilToDouble()
        .clamp(1, double.infinity)
        .toDouble();
    bool _isDialogShowing = false;
    final translationService = context.watch<LanguageProvider>();
    final locale = translationService.currentCode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        tr(
          'Punctuality Breakdown',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: hasData
              ? Center(
                  child: BarChart(
                    BarChartData(
                      maxY: maxValue + interval,
                      alignment: BarChartAlignment.spaceAround,
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchTooltipData: BarTouchTooltipData(
                          tooltipPadding: EdgeInsets.zero,
                          tooltipMargin: 0,
                        ),
                        touchCallback: (event, response) {
                          if (response == null || response.spot == null)
                            return;

                          if (event is! FlTapUpEvent) return;

                          if (_isDialogShowing) return;
                          _isDialogShowing = true;

                          final x = response.spot!.touchedBarGroup.x;
                          int count = 0;
                          String label = '';
                          List<int> Ids = [];
                          switch (x) {
                            case 0:
                              count = onTime;
                              label = "On Time";
                              Ids = onTimeIds;
                              break;
                            case 1:
                              count = earlyIn;
                              label = "Early In";
                              Ids = earlyInIds;
                              break;
                            case 2:
                              count = lateIn;
                              label = "Late In";
                              Ids = lateInIds;
                              break;
                            case 3:
                              count = absent;
                              label = "Absent";
                              Ids = absentIds;
                              break;
                          }

                          showDialog(
                            context: context,
                            builder: (context) {
                              return AlertDialog(
                                backgroundColor: isDark
                                    ? Colors.grey[800]
                                    : Colors.white,
                                title: Text(
                                  '${catchTranslate(context, '$label')} ${catchTranslate(context, 'Details')}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black,
                                    fontSize: 18,
                                  ),
                                ),
                                content: Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: localeNumber(
                                          count.toString(),
                                          locale,
                                        ),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isDark
                                              ? Colors.white70
                                              : Colors.black87,
                                          fontSize: 14,
                                        ),
                                      ),
                                      TextSpan(
                                        text:
                                            ' ${catchTranslate(context, 'employee(s) fall under')} ',
                                        style: TextStyle(
                                          fontWeight: FontWeight.normal,
                                          color: isDark
                                              ? Colors.white60
                                              : Colors.black54,
                                          fontSize: 14,
                                        ),
                                      ),
                                      TextSpan(
                                        text: catchTranslate(
                                          context,
                                          '$label',
                                        ),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black,
                                          fontSize: 14,
                                        ),
                                      ),
                                      TextSpan(
                                        text:
                                            '. ${catchTranslate(context, 'Regular attendance helps maintain productivity and ensures smooth workflow.')}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.normal,
                                          color: isDark
                                              ? Colors.white60
                                              : Colors.black54,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                actions: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: () {
                                            Navigator.pop(context);
                                          },
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
                                              borderRadius:
                                                  BorderRadius.circular(8.0),
                                            ),
                                          ),
                                          child: tr(
                                            "CANCEL",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: isDark
                                                  ? Colors.white
                                                  : AppStyle.primaryColor,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: () async {
                                            _navigateToEmployeeList(
                                              context,
                                              Ids ?? [],
                                              "$label Employees",
                                            );
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                AppStyle.primaryColor,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8.0),
                                            ),
                                          ),
                                          child: tr(
                                            "VIEW",
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              );
                            },
                          ).then((_) => _isDialogShowing = false);
                        },
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 28,
                            interval: interval,
                            getTitlesWidget: (value, meta) => Text(
                              value.toInt().toString(),
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark
                                    ? Colors.white54
                                    : Colors.black54,
                              ),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              switch (value.toInt()) {
                                case 0:
                                  return _barLabel("On Time", isDark);
                                case 1:
                                  return _barLabel("Early In", isDark);
                                case 2:
                                  return _barLabel("Late In", isDark);
                                case 3:
                                  return _barLabel("Absent", isDark);
                                default:
                                  return const SizedBox();
                              }
                            },
                          ),
                        ),
                        topTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawHorizontalLine: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: isDark
                              ? Colors.grey.shade700.withOpacity(0.5)
                              : Colors.grey.shade400.withOpacity(0.7),
                          strokeWidth: 1.0,
                          dashArray: [7, 5],
                        ),
                      ),
                      borderData: FlBorderData(
                        show: true,
                        border: Border(
                          bottom: BorderSide(
                            color: isDark ? Colors.white24 : Colors.black26,
                            width: 1,
                          ),
                          left: BorderSide(
                            color: isDark ? Colors.white24 : Colors.black26,
                            width: 1,
                          ),
                        ),
                      ),
                      barGroups: [
                        _bar(0, onTime, AppStyle.primaryColor),
                        _bar(1, earlyIn, AppStyle.primaryColor),
                        _bar(2, lateIn, AppStyle.primaryColor),
                        _bar(3, absent, AppStyle.primaryColor),
                      ],
                    ),
                  ),
                )
              : Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.bar_chart,
                        color: isDark ? Colors.white60 : Colors.black54,
                        size: 20,
                      ),
                      const SizedBox(height: 10),
                      tr(
                        "No punctuality breakdown data available",
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _barLabel(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: tr(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: isDark ? Colors.white70 : Colors.black87,
        ),
      ),
    );
  }

  BarChartGroupData _bar(int x, int y, Color color) {
    double barHeight = y.toDouble();
    if (y == 0) barHeight = 0;

    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: barHeight,
          width: 26,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(6),
            bottom: Radius.zero,
          ),
          color: y == 0 ? color : color,
        ),
      ],
    );
  }

  /// Line chart showing absenteeism trend over last 7 days
  Widget _absenteesTrendLineChart(
    AttendanceDashboardState state,
    bool isDark,
    BuildContext context,
  ) {
    final absenteeism = state.last7DaysAbsenteeismTrend;

    if (absenteeism.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              HugeIcons.strokeRoundedChartLineData03,
              color: isDark ? Colors.white60 : Colors.black54,
              size: 20,
            ),
            const SizedBox(height: 10),
            tr(
              "No absenteeism data for the last 7 days",
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
          ],
        ),
      );
    }

    final spots = List.generate(
      absenteeism.length,
      (index) => FlSpot(
        index.toDouble(),
        (absenteeism[index]['absentCount'] ?? 0).toDouble(),
      ),
    );

    final maxValue = (absenteeism
        .map((e) => (e['absentCount'] ?? 0) as num)
        .map((e) => e.toDouble())
        .reduce((a, b) => a > b ? a : b));

    final double interval = (maxValue / 4).ceilToDouble().clamp(
      1,
      double.infinity,
    );

    final labels = [
      '6d ago',
      '5d ago',
      '4d ago',
      '3d ago',
      '2d ago',
      'Yesterday',
      'Today',
    ];
    final translationService = context.watch<LanguageProvider>();
    final locale = translationService.currentCode;
    final localizedLabels = labels
        .map((e) => localeLabel(e, locale, context))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        tr(
          'Absenteeism Trend',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: maxValue + 1,
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final dayIndex = value.toInt();
                      if (dayIndex < 0 || dayIndex >= labels.length) {
                        return const SizedBox();
                      }
                      return Text(
                        localizedLabels[dayIndex],
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                          fontSize: 10,
                        ),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: interval,
                    getTitlesWidget: (value, meta) => Text(
                      value.toInt().toString(),
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              gridData: FlGridData(
                show: true,
                drawHorizontalLine: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: isDark
                      ? Colors.grey.shade700.withOpacity(0.5)
                      : Colors.grey.shade400.withOpacity(0.7),
                  strokeWidth: 1.0,
                  dashArray: [7, 5],
                ),
              ),
              borderData: FlBorderData(
                show: true,
                border: Border.all(
                  color: isDark ? Colors.white24 : Colors.black26,
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: AppStyle.primaryColor,
                  barWidth: 3,
                  dotData: const FlDotData(show: true),
                  belowBarData: BarAreaData(
                    show: true,
                    color: AppStyle.primaryColor.withOpacity(0.3),
                  ),
                ),
              ],
              lineTouchData: LineTouchData(
                enabled: true,
                handleBuiltInTouches: true,
                touchTooltipData: LineTouchTooltipData(
                  tooltipRoundedRadius: 8,
                  tooltipPadding: const EdgeInsets.all(8),
                  tooltipMargin: 8,
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                ),
                touchCallback: (FlTouchEvent event, LineTouchResponse? touchResponse) {
                  if (event is FlTapUpEvent && touchResponse != null) {
                    final touchedSpot = touchResponse.lineBarSpots?.first;
                    if (touchedSpot != null) {
                      final index = touchedSpot.spotIndex;
                      final dayLabel = localizedLabels[index];
                      final absentCount =
                          absenteeism[index]['absentCount'] ?? 0;
                      final absentUpdatedCount = localeNumber(
                        absentCount.toString(),
                        locale,
                      );

                      final absentEmployeeIds =
                          absenteeism[index]['absentEmployeeIds'] ?? [];

                      showDialog(
                        context: context,
                        builder: (context) {
                          return AlertDialog(
                            backgroundColor: isDark
                                ? Colors.grey[800]
                                : Colors.white,
                            title: tr(
                              'Absentee Details',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black,
                                fontSize: 18,
                              ),
                            ),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: '$absentUpdatedCount',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black,
                                          fontSize: 14,
                                        ),
                                      ),
                                      TextSpan(
                                        text:
                                            ' ${catchTranslate(context, 'number of employees who were absent on')} ',
                                        style: TextStyle(
                                          fontWeight: FontWeight.normal,
                                          color: isDark
                                              ? Colors.white60
                                              : Colors.black54,
                                          fontSize: 14,
                                        ),
                                      ),
                                      TextSpan(
                                        text: '$dayLabel',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black,
                                          fontSize: 14,
                                        ),
                                      ),
                                      TextSpan(
                                        text:
                                            '. ${catchTranslate(context, 'Regular attendance helps maintain productivity and ensures smooth workflow.')}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.normal,
                                          color: isDark
                                              ? Colors.white60
                                              : Colors.black54,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            actions: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () {
                                        Navigator.pop(context);
                                      },
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
                                          borderRadius: BorderRadius.circular(
                                            8.0,
                                          ),
                                        ),
                                      ),
                                      child: tr(
                                        "CANCEL",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isDark
                                              ? Colors.white
                                              : AppStyle.primaryColor,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () async {
                                        _navigateToEmployeeList(
                                          context,
                                          absentEmployeeIds ?? [],
                                          "Absent Employees",
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppStyle.primaryColor,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8.0,
                                          ),
                                        ),
                                      ),
                                      child: tr(
                                        "VIEW",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
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
                  }
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  bool isRTLLanguage(Locale locale) {
    const rtlLanguages = [
      'ar',
      'fa',
      'ur',
      'he',
      'ps',
      'sd',
      'ug',
      'dv',
      'ku',
      'yi',
    ];

    return rtlLanguages.contains(locale.languageCode);
  }

  String catchTranslate(BuildContext context, String key) {
    final service = Provider.of<LanguageProvider>(context, listen: false);
    return service.getCached(key) ?? key;
  }

  /// Employee view: today's hours + check-in time cards
  Widget _buildEmployeeHoursCards(
    AttendanceDashboardState state,
    bool isDark,
    BuildContext context,
  ) {
    final translationService = context.watch<LanguageProvider>();
    final locale = translationService.currentCode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: tr(
            "Today's Attendance",
            style: TextStyle(
              fontSize: 18,
              fontFamily: GoogleFonts.inter().fontFamily,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ),
        const SizedBox(height: 12),
        GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.2,
          ),
          children: [
            _dashboardCard(
              height: 130,
              isDark: isDark,
              title: catchTranslate(context, "Hours"),
              subtitle: catchTranslate(context, "Hours recorded for today"),
              child: state.isTimerLoading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      localeNumber(state.workedHoursText.toString(), locale),
                      maxLines: 1,
                      softWrap: false,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 22,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
              icon: HugeIcons.strokeRoundedLoading01,
              color: const Color(0xFF45B641),
            ),

            _dashboardCard(
              height: 130,
              isDark: isDark,
              title: catchTranslate(context, "Check In"),
              subtitle: catchTranslate(context, "First login time today"),
              child: Text(
                localeTime(state.checkInTime, locale),
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 22,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              icon: HugeIcons.strokeRoundedAlarmClock,
              color: const Color(0xFFEAC407),
            ),
          ],
        ),
        SizedBox(height: 10),
      ],
    );
  }

  /// Reusable small card used for employee hours & check-in time
  Widget _dashboardCard({
    required double height,
    required bool isDark,
    required String title,
    required String subtitle,
    required Widget child,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(12),

        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.15)
                : color.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      child,
                      const SizedBox(height: 4),
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.grey[300]! : Colors.grey[700]!,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark
                        ? color.withOpacity(0.6)
                        : color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    size: 17,
                    color: isDark ? Colors.white : color,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Leave related quick action cards (request, history, pending for Leave Manager)
  Widget _buildActionButtonsRow(
    BuildContext context,
    AttendanceDashboardState state,
    MotionProvider motionProvider,
    bool isDark,
  ) {
    final translationService = context.watch<LanguageProvider>();
    final locale = translationService.currentCode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: tr(
            'Leave Management',
            style: TextStyle(
              fontSize: 18,
              fontFamily: GoogleFonts.inter().fontFamily,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (!state.accessForAdmin && state.accessForLeaveManager) ...[
          GestureDetector(
            onTap: () {
              if (!state.isAppNotInstalled)
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (_, __, ___) => PendingLeavePage(),
                    transitionDuration: motionProvider.reduceMotion
                        ? Duration.zero
                        : const Duration(milliseconds: 300),
                    transitionsBuilder: (_, animation, __, child) =>
                        motionProvider.reduceMotion
                        ? child
                        : FadeTransition(opacity: animation, child: child),
                  ),
                );
            },
            child: Container(
              constraints: const BoxConstraints(minHeight: 80),
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[850] : Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black26
                        : Colors.black.withOpacity(0.05),
                    blurRadius: 16,
                    spreadRadius: 2,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Color(0xFFF48C06).withOpacity(0.6)
                          : Color(0xFFF48C06).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      HugeIcons.strokeRoundedAlertDiamond,
                      size: 24,
                      color: isDark ? Colors.white : Color(0xFFF48C06),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        tr(
                          'Pending Approvals',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        tr(
                          state.isAppNotInstalled
                              ? ("Time Off module is not installed yet, ${state.accessForAdmin ? ("Please enable it from Apps") : ("Please contact your administrator to enable it")} for getting this feature")
                              : '${localeNumber(state.leavePendingCount.toString(), locale)} ${catchTranslate(context, 'Leaves awaiting your review')}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? Colors.grey[400]!
                                : Colors.grey[600]!,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          softWrap: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        GestureDetector(
          onTap: () {
            if (!state.isAppNotInstalled)
              Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (_, __, ___) => RequestAbsencePage(),
                  transitionDuration: motionProvider.reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 300),
                  transitionsBuilder: (_, animation, __, child) =>
                      motionProvider.reduceMotion
                      ? child
                      : FadeTransition(opacity: animation, child: child),
                ),
              );
          },
          child: Container(
            constraints: const BoxConstraints(minHeight: 80),
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[850] : Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black26
                      : Colors.black.withOpacity(0.05),
                  blurRadius: 16,
                  spreadRadius: 2,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Color(0xFF5D389E).withOpacity(0.6)
                        : Color(0xFF5D389E).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    HugeIcons.strokeRoundedCalendar03,
                    size: 22,
                    color: isDark ? Colors.white : Color(0xFF5D389E),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      tr(
                        'Request Absence',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      tr(
                        state.isAppNotInstalled
                            ? ("Time Off module is not installed yet, ${state.accessForAdmin ? ("Please enable it from Apps") : ("Please contact your administrator to enable it")} for getting this feature")
                            : 'Request leave for upcoming days',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[400]! : Colors.grey[600]!,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        softWrap: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        GestureDetector(
          onTap: () {
            if (!state.isAppNotInstalled)
              Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (_, __, ___) => LeaveHistoryPage(),
                  transitionDuration: motionProvider.reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 300),
                  transitionsBuilder: (_, animation, __, child) =>
                      motionProvider.reduceMotion
                      ? child
                      : FadeTransition(opacity: animation, child: child),
                ),
              );
          },
          child: Container(
            constraints: const BoxConstraints(minHeight: 80),
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[850] : Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black26
                      : Colors.black.withOpacity(0.05),
                  blurRadius: 16,
                  spreadRadius: 2,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Color(0xFFE332DA).withOpacity(0.6)
                        : Color(0xFFE332DA).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    HugeIcons.strokeRoundedTransactionHistory,
                    size: 24,
                    color: isDark ? Colors.white : Color(0xFFE332DA),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      tr(
                        'Leave History',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      tr(
                        state.isAppNotInstalled
                            ? ("Time Off module is not installed yet, ${state.accessForAdmin ? ("Please enable it from Apps") : ("Please contact your administrator to enable it")} for getting this feature")
                            : 'Track your past leave records',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[400]! : Colors.grey[600]!,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        softWrap: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 10),
      ],
    );
  }

  /// Displays list of today's check-in / check-out events
  Widget _buildRecentActivitySection(
    AttendanceDashboardState state,
    bool isDark,
    BuildContext context,
  ) {
    final translationService = context.watch<LanguageProvider>();
    final locale = translationService.currentCode;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            state.recentActivity.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(
                            HugeIcons.strokeRoundedActivity01,
                            color: isDark ? Colors.white60 : Colors.black54,
                            size: 24,
                          ),
                          const SizedBox(height: 20),
                          tr(
                            'No recent activity',
                            style: TextStyle(
                              color: isDark ? Colors.white60 : Colors.black54,
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    itemCount: state.recentActivity.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, index) {
                      final item = state.recentActivity[index];
                      final isCheckIn = item['type'] == 'Check In';
                      return ListTile(
                        leading: Icon(
                          isCheckIn
                              ? HugeIcons.strokeRoundedLogin02
                              : HugeIcons.strokeRoundedLogout02,
                          color: isCheckIn
                              ? (isDark ? Colors.white54 : Colors.green)
                              : (isDark ? Colors.white54 : Colors.red),
                        ),
                        title: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            tr(
                              item['type']!,
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              localeTime(item['time'].toString(), locale),
                              style: TextStyle(
                                color: isDark ? Colors.white70 : Colors.black87,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        trailing: Text(
                          item['mode']!,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }
}
