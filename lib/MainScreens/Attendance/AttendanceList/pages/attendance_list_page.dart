import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:intl/intl.dart';

import '../../../../CommonWidgets/core/company/infrastructure/company_refresh_bus.dart';
import '../../../../CommonWidgets/core/company/providers/company_provider.dart';
import '../../../../CommonWidgets/core/language/translate_widget.dart';
import '../../../../CommonWidgets/core/providers/language_provider.dart';
import '../../../../CommonWidgets/globals.dart';
import '../../../../CommonWidgets/shared/widgets/snackbar.dart';
import '../../../../Rating/review_service.dart';
import '../../../AppBars/infrastructure/profile_refresh_bus.dart';
import '../../AttendanceCreate/pages/create_attendance_page.dart';
import '../../AttendanceForm/pages/attendance_form_page.dart';
import '../bloc/attendance_list_bloc.dart';

/// Main screen displaying list of attendance records with filtering, grouping,
/// pagination, search, and refresh capabilities.
///
/// Features:
///   - Search by employee/date/email
///   - Filter chips (My Attendance, My Team, At Work, Errors, Last 7 Days)
///   - Grouping by employee / check-in date / check-out date
///   - Pagination with prev/next controls
///   - Pull-to-refresh
///   - FAB to create new attendance (when permitted)
///   - Error / empty / loading states with Lottie animations
class AttendanceListPage extends StatefulWidget {
  const AttendanceListPage({super.key});

  @override
  State<AttendanceListPage> createState() => _AttendanceListPageState();
}

class _AttendanceListPageState extends State<AttendanceListPage> {
  final TextEditingController _searchController = TextEditingController();

  /// Human-readable filter names → technical filter values used in API/bloc
  final Map<String, String> filterTechnicalNames = {
    "My Attendance": "my_attendance",
    "My Team": "my_team",
    "At Work": "at_work",
    "Errors": "errors",
    "Last 7 Days": "last_7_days",
  };

  /// Human-readable group options → technical group keys
  final Map<String, String> groupTechnicalNames = {
    "Check In": "check_in",
    "Employee": "employee",
    "Check Out": "check_out",
  };

  /// Available grouping time units for check-in / check-out grouping
  final Map<String, String> dateUnits = {
    "Year": "year",
    "Quarter": "quarter",
    "Month": "month",
    "Week": "week",
    "Day": "day",
  };

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Groups attendance records based on the selected grouping strategy.
  ///
  /// Supports grouping by:
  ///   - employee         → by employee name
  ///   - check_in         → by date bucket (year/quarter/month/week/day)
  ///   - check_out        → by date bucket (year/quarter/month/week/day)
  ///
  /// Returns list of group objects: [{"group": "Group Name", "attendance": [...]}, ...]
  List<Map<String, dynamic>> _groupAttendance(
    List<Map<String, dynamic>> attendance,
    String groupBy,
    AttendanceLoaded state,
  ) {
    final Map<String, List<Map<String, dynamic>>> grouped = {};

    for (var data in attendance) {
      String key = "Unknown";

      if (groupBy == "employee") {
        key = (data["employee_id"] is List && data["employee_id"].isNotEmpty)
            ? data["employee_id"][1]
            : "None";
      } else if (groupBy == "check_in" || groupBy == "check_out") {
        final String field = groupBy == "check_in" ? "check_in" : "check_out";
        String? dateStr;

        if (data[field] is String && data[field].isNotEmpty) {
          dateStr = data[field];
        } else if (data[field] is List && data[field].length > 1) {
          dateStr = data[field][1];
        }

        final String unit = groupBy == "check_in"
            ? (state.selectedCheckInUnit ?? "day")
            : (state.selectedCheckOutUnit ?? "day");

        String dateKey = "No Date";
        if (dateStr != null) {
          final date = DateTime.parse(dateStr);
          switch (unit) {
            case "year":
              dateKey = "${date.year}";
              break;
            case "quarter":
              int quarter = ((date.month - 1) ~/ 3) + 1;
              dateKey = "Q$quarter ${date.year}";
              break;
            case "month":
              dateKey = DateFormat('MMM yyyy').format(date);
              break;
            case "week":
              int week =
                  ((date.day +
                          DateTime(date.year, date.month, 1).weekday -
                          1) ~/
                      7) +
                  1;
              dateKey = "Week $week ${date.year}";
              break;
            case "day":
            default:
              dateKey = DateFormat('dd MMM yyyy').format(date);
              break;
          }
        }
        key = dateKey;
      }

      grouped.putIfAbsent(key, () => []);
      grouped[key]!.add(data);
    }

    return grouped.entries
        .map((e) => {"group": e.key, "attendance": e.value})
        .toList();
  }

  /// Pull-to-refresh handler — reloads current view or reinitializes company data on error
  Future<void> _refreshAttendance() async {
    final bloc = context.read<AttendanceListBloc>();

    final current = bloc.state;
    if (current is AttendanceLoaded) {
      if (current.catchError) {
        // Likely auth/company data issue → try to recover
        await context.read<CompanyProvider>().initialize();
        ProfileRefreshBus.notifyProfileRefresh();
        CompanyRefreshBus.notify();
      } else {
        bloc.add(
          LoadAttendance(
            page: 0,
            selectedFilters: current.selectedFilters,
            selectedGroupBy: current.selectedGroupBy,
            selectedCheckInUnit: current.selectedCheckInUnit,
            selectedCheckOutUnit: current.selectedCheckOutUnit,
            searchText: current.searchText,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final translationService = context.read<LanguageProvider>();
    final locale = translationService.currentCode;

    return Scaffold(
      backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
      body: BlocConsumer<AttendanceListBloc, AttendanceListState>(
        listener: (context, state) {
          if (state is AttendanceLoaded && state.errorMessage != null) {
            CustomSnackbar.showError(context, state.errorMessage!);
          } else if (state is AttendanceDeletedSuccess) {
            CustomSnackbar.showSuccess(
              context,
              'Attendance deleted successfully',
            );
            ReviewService().trackSignificantEvent();
            Future.delayed(const Duration(seconds: 3), () {
              ReviewService().checkAndShowRating(context);
            });
          }
        },
        builder: (context, state) {
          return Stack(
            children: [
              RefreshIndicator(
                color: isDark ? Colors.white : AppStyle.primaryColor,
                onRefresh: _refreshAttendance,
                child: Column(
                  children: [
                    // Search + filter button
                    Padding(
                      padding: const EdgeInsets.only(
                        top: 0.0,
                        left: 16.0,
                        right: 16.0,
                        bottom: 16.0,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: Color(0xFF000000).withOpacity(0.05),
                              offset: Offset(0, 6),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Consumer<LanguageProvider>(
                          builder: (_, ts, __) {
                            return TextField(
                              controller: _searchController,
                              style: TextStyle(
                                color: isDark
                                    ? Colors.white
                                    : Color(0xff1E1E1E),
                                fontWeight: FontWeight.w400,
                                fontStyle: FontStyle.normal,
                                fontSize: 15,
                                height: 1.0,
                                letterSpacing: 0.0,
                              ),
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                isDense: true,
                                alignLabelWithHint: true,
                                hintText:
                                    ts.getCached(
                                      'Search by employee, date or mail',
                                    ) ??
                                    'Search by employee, date or mail',
                                hintStyle: TextStyle(
                                  color: isDark
                                      ? Colors.white
                                      : Color(0xff1E1E1E),
                                  fontWeight: FontWeight.w400,
                                  fontStyle: FontStyle.normal,
                                  fontSize: 15,
                                  height: 1.0,
                                  letterSpacing: 0.0,
                                ),
                                prefixIcon: IconButton(
                                  icon: Icon(
                                    HugeIcons.strokeRoundedFilterHorizontal,
                                    color: isDark
                                        ? Colors.grey[400]
                                        : Colors.grey[600],
                                    size: 18,
                                  ),
                                  tooltip:
                                      ts.getCached('Filter & Group By') ??
                                      'Filter & Group By',
                                  splashRadius: 20,
                                  padding: EdgeInsets.zero,
                                  constraints: BoxConstraints(
                                    minWidth: 32,
                                    minHeight: 32,
                                  ),
                                  onPressed: () =>
                                      _openFilterGroupBySheet(context),
                                ),
                                filled: true,
                                fillColor: isDark
                                    ? Colors.grey[850]
                                    : Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: isDark
                                        ? Colors.white
                                        : AppStyle.primaryColor,
                                  ),
                                ),
                              ),
                              onChanged: (value) {
                                final currentState = context
                                    .read<AttendanceListBloc>()
                                    .state;
                                if (currentState is AttendanceLoaded) {
                                  context.read<AttendanceListBloc>().add(
                                    SearchAttendance(
                                      searchText: value.trim(),
                                      selectedFilters:
                                          currentState.selectedFilters,
                                      selectedGroupBy:
                                          currentState.selectedGroupBy,
                                      selectedCheckInUnit:
                                          currentState.selectedCheckInUnit,
                                      selectedCheckOutUnit:
                                          currentState.selectedCheckOutUnit,
                                    ),
                                  );
                                }
                              },
                            );
                          },
                        ),
                      ),
                    ),

                    if (state is AttendanceLoaded)
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minWidth:
                                MediaQuery.of(context).size.width -
                                32,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 8.0,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Builder(
                                  builder: (context) {
                                    final hasFilters =
                                        state.selectedFilters.isNotEmpty;
                                    final hasGroupBy =
                                        state.selectedGroupBy != null;

                                    if (!hasFilters && !hasGroupBy) {
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                          vertical: 6,
                                        ),
                                        child: tr(
                                          "No filters applied",
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark
                                                ? Colors.white70
                                                : Colors.black54,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      );
                                    }

                                    String? groupDisplayName;
                                    if (hasGroupBy) {
                                      groupDisplayName = groupTechnicalNames
                                          .keys
                                          .firstWhere(
                                            (key) =>
                                                groupTechnicalNames[key] ==
                                                state.selectedGroupBy,
                                            orElse: () => state
                                                .selectedGroupBy!,
                                          );
                                    }

                                    return Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (hasFilters)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isDark
                                                  ? Colors.white70
                                                  : Colors.black,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  localeNumber(
                                                    state.selectedFilters.length
                                                        .toString(),
                                                    locale,
                                                  ),
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: isDark
                                                        ? Colors.black
                                                        : Colors.white,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                tr(
                                                  "Active",
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: isDark
                                                        ? Colors.black
                                                        : Colors.white,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),

                                        if (hasGroupBy) ...[
                                          if (hasFilters)
                                            const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isDark
                                                  ? Colors.white70
                                                  : Colors.black,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  HugeIcons.strokeRoundedLayer,
                                                  size: 16,
                                                  color: isDark
                                                      ? Colors.black
                                                      : Colors.white,
                                                ),
                                                const SizedBox(width: 6),
                                                tr(
                                                  groupDisplayName ?? "Group",
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: isDark
                                                        ? Colors.black
                                                        : Colors.white,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ],
                                    );
                                  },
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? Colors.grey[800]
                                            : Colors.grey[100],
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: isDark
                                              ? Colors.grey[700]!
                                              : Colors.grey[300]!,
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        "${localeNumber(state.pageRange.toString(), locale)} / ${localeNumber(state.totalCount.toString(), locale)}",
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: isDark
                                              ? Colors.white70
                                              : Colors.black87,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 4.0,
                                      ),
                                      child: InkWell(
                                        onTap: state.currentPage > 0
                                            ? () => context
                                                  .read<AttendanceListBloc>()
                                                  .add(
                                                    LoadAttendance(
                                                      page:
                                                          state.currentPage - 1,
                                                      selectedFilters:
                                                          state.selectedFilters,
                                                      selectedGroupBy:
                                                          state.selectedGroupBy,
                                                      selectedCheckInUnit: state
                                                          .selectedCheckInUnit,
                                                      selectedCheckOutUnit: state
                                                          .selectedCheckOutUnit,
                                                      searchText:
                                                          state.searchText,
                                                    ),
                                                  )
                                            : null,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 8.0,
                                            horizontal: 4,
                                          ),
                                          child: Icon(
                                            HugeIcons.strokeRoundedArrowLeft01,
                                            size: 20,
                                            color: state.currentPage > 0
                                                ? (isDark
                                                      ? Colors.white
                                                      : Colors.black87)
                                                : (isDark
                                                      ? Colors.grey[600]
                                                      : Colors.grey[400]),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Container(
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 4.0,
                                      ),
                                      child: InkWell(
                                        onTap:
                                            state.displayedCount <
                                                state.totalCount
                                            ? () => context
                                                  .read<AttendanceListBloc>()
                                                  .add(
                                                    LoadAttendance(
                                                      page:
                                                          state.currentPage + 1,
                                                      selectedFilters:
                                                          state.selectedFilters,
                                                      selectedGroupBy:
                                                          state.selectedGroupBy,
                                                      selectedCheckInUnit: state
                                                          .selectedCheckInUnit,
                                                      selectedCheckOutUnit: state
                                                          .selectedCheckOutUnit,
                                                      searchText:
                                                          state.searchText,
                                                    ),
                                                  )
                                            : null,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 8.0,
                                            horizontal: 4,
                                          ),
                                          child: Icon(
                                            HugeIcons.strokeRoundedArrowRight01,
                                            size: 20,
                                            color:
                                                state.displayedCount <
                                                    state.totalCount
                                                ? (isDark
                                                      ? Colors.white
                                                      : Colors.black87)
                                                : (isDark
                                                      ? Colors.grey[600]
                                                      : Colors.grey[400]),
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
                      ),
                    Expanded(child: _buildBody(state, isDark)),
                  ],
                ),
              ),
              // Loading overlay during paging
              if (state is AttendanceLoaded && state.isPaging)
                Center(
                  child: LoadingAnimationWidget.staggeredDotsWave(
                    color: AppStyle.primaryColor,
                    size: 50,
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton:
          BlocBuilder<AttendanceListBloc, AttendanceListState>(
            builder: (context, state) {
              if (state is AttendanceLoaded && state.accessForAction) {
                return FloatingActionButton(
                  backgroundColor: isDark
                      ? Colors.white
                      : AppStyle.primaryColor,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CreateAttendancePage(),
                      ),
                    ).then(
                      (_) => context.read<AttendanceListBloc>().add(
                        const LoadAttendance(page: 0),
                      ),
                    );
                  },
                  child: Icon(
                    HugeIcons.strokeRoundedAdd01,
                    color: isDark ? Colors.black : Colors.white,
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
    );
  }

  /// Builds main content area — handles loading / error / empty / data states
  Widget _buildBody(AttendanceListState state, bool isDark) {
    if (state is AttendanceInitial || state is AttendanceLoading) {
      return _buildShimmerList(isDark);
    }

    if (state is AttendanceLoaded) {
      if (!state.catchError) {
        if(!state.connectionError) {
          if (state.attendance.isEmpty) {
            final hasFilters =
                state.selectedFilters.isNotEmpty ||
                    (state.selectedGroupBy?.isNotEmpty ?? false);
            return _buildCenteredLottie(
              lottie: 'assets/empty_ghost.json',
              title: 'No attendances found',
              subtitle: hasFilters ? 'Try adjusting your filter' : null,
              isDark: isDark,
              button: hasFilters
                  ? OutlinedButton(
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
                onPressed: () {
                  context.read<AttendanceListBloc>().add(ClearFilters());
                },
                child: tr(
                  'Clear All Filters',
                  style: TextStyle(
                    color: isDark ? Colors.white : AppStyle.primaryColor,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              )
                  : null,
            );
          }
        }else{
          return _buildCenteredLottie(
            lottie: 'assets/Error_404.json',
            title: 'Connection Refused',
            subtitle: 'Pull to refresh or tap retry after connecting your server',
            isDark: isDark,
            button: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: isDark ? Colors.white : AppStyle.primaryColor,
                side: BorderSide(
                  color: isDark
                      ? Colors.grey[600]!
                      : AppStyle.primaryColor.withOpacity(0.3),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                'Retry',
                style: TextStyle(
                  color: isDark ? Colors.white : AppStyle.primaryColor,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          );
        }
      } else {
        return _buildCenteredLottie(
          lottie: 'assets/Error_404.json',
          title: 'Something went wrong',
          subtitle: 'Pull to refresh or tap retry',
          isDark: isDark,
          button: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: isDark ? Colors.white : AppStyle.primaryColor,
              side: BorderSide(
                color: isDark
                    ? Colors.grey[600]!
                    : AppStyle.primaryColor.withOpacity(0.3),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
              'Retry',
              style: TextStyle(
                color: isDark ? Colors.white : AppStyle.primaryColor,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        );
      }

      final groupedList = state.selectedGroupBy != null
          ? _groupAttendance(state.attendance, state.selectedGroupBy!, state)
          : null;

      return ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: groupedList?.length ?? state.attendance.length,
        itemBuilder: (context, index) {
          if (groupedList != null) {
            final group = groupedList[index];
            final groupName = group["group"] as String;
            final groupItems =
                group["attendance"] as List<Map<String, dynamic>>;
            return _buildGroupedSection(
              context,
              groupName,
              groupItems,
              isDark,
              state,
            );
          } else {
            return _buildAttendanceCard(state, state.attendance[index], isDark);
          }
        },
      );
    }

    return _buildCenteredLottie(
      lottie: 'assets/Error_404.json',
      title: 'Something went wrong',
      subtitle: 'Pull to refresh or tap retry',
      isDark: isDark,
      button: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: isDark ? Colors.white : AppStyle.primaryColor,
          side: BorderSide(
            color: isDark
                ? Colors.grey[600]!
                : AppStyle.primaryColor.withOpacity(0.3),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: () async {
          await context.read<CompanyProvider>().initialize();
          ProfileRefreshBus.notifyProfileRefresh();
          CompanyRefreshBus.notify();
        },
        child: tr(
          'Retry',
          style: TextStyle(
            color: isDark ? Colors.white : AppStyle.primaryColor,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
  }

  /// Centered feedback screen with Lottie animation, title, subtitle and optional action button
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

  /// Shimmer placeholder list shown during initial loading
  Widget _buildShimmerList(bool isDark) {
    final baseColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = isDark ? Colors.grey[700]! : Colors.grey[100]!;

    return ListView.builder(
      itemCount: 10,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: baseColor,
        highlightColor: highlightColor,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const CircleAvatar(radius: 28, backgroundColor: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(height: 16, width: 150, color: Colors.white),
                    const SizedBox(height: 8),
                    Container(height: 14, width: 200, color: Colors.white),
                    const SizedBox(height: 6),
                    Container(height: 14, width: 180, color: Colors.white),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Expandable grouped section (used when grouping is active)
  Widget _buildGroupedSection(
    BuildContext blocContext,
    String groupName,
    List<Map<String, dynamic>> items,
    bool isDark,
    AttendanceLoaded state,
  ) {
    final expanded = state.groupExpanded[groupName] ?? true;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.06),
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              blurRadius: 16,
              spreadRadius: 2,
              offset: const Offset(0, 6),
              color: Colors.black.withOpacity(0.08),
            ),
        ],
      ),
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          InkWell(
            onTap: () => blocContext.read<AttendanceListBloc>().add(
              ToggleGroupExpansion(groupName),
            ),
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          groupName,
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${items.length} attendance${items.length != 1 ? 's' : ''}',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            ...items.map((data) => Padding(
              padding: const EdgeInsets.all(8.0),
              child: _buildAttendanceCard(state, data, isDark),
            )),
        ],
      ),
    );
  }

  /// Safely extracts image URL from various possible response formats
  String? _safeImage(dynamic value) {
    if (value == null) return null;
    if (value is bool) return null;
    if (value is String && value.isNotEmpty) return value;
    return null;
  }

  /// Maps Latin digits → locale-specific numeral systems (Arabic, Bengali, Thai, etc.)
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

  /// Converts numbers to locale-appropriate numeral glyphs if supported
  String localeNumber(String input, String locale) {
    final code = locale.split('_').first.toLowerCase();
    final map = _digitMaps[code];
    if (map == null) return input;

    map.forEach((latin, native) {
      input = input.replaceAll(latin, native);
    });
    return input;
  }

  /// Individual attendance record card with employee avatar, name, check-in/out times
  Widget _buildAttendanceCard(
    AttendanceLoaded state,
    Map<String, dynamic> data,
    bool isDark,
  ) {
    final name = data["employee_id"] is List
        ? data["employee_id"][1] ?? "Unknown"
        : "Unknown";
    final imageUrl = _safeImage(data["employee_image"]);

    final rawCheckIn = data["check_in"] is String ? data["check_in"] : null;
    final rawCheckOut = data["check_out"] is String ? data["check_out"] : null;

    final translationService = context.watch<LanguageProvider>();
    final locale = translationService.currentCode;
    final format = DateFormat('dd MMM yyyy, hh:mm a', locale);

    final checkInTime = rawCheckIn != null
        ? DateTime.parse('$rawCheckIn' + 'Z').toLocal()
        : null;
    final checkOutTime = rawCheckOut != null
        ? DateTime.parse('$rawCheckOut' + 'Z').toLocal()
        : null;

    final formattedCheckIn = checkInTime != null
        ? localeNumber(format.format(checkInTime), locale)
        : "--:--";

    final formattedCheckOut = checkOutTime != null
        ? localeNumber(format.format(checkOutTime), locale)
        : "--:--";

    String workingHours = "N/A";

    if (checkInTime != null) {
      final fromTime =
          "${checkInTime.hour.toString().padLeft(2, '0')}:${checkInTime.minute.toString().padLeft(2, '0')}";

      if (checkOutTime == null) {
        workingHours = "From $fromTime";
      } else {
        final duration = checkOutTime.difference(checkInTime);

        if (!duration.isNegative) {
          final hours = duration.inHours;
          final minutes = duration.inMinutes % 60;

          workingHours =
              "${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')} ($fromTime - "
              "${checkOutTime.hour.toString().padLeft(2, '0')}:${checkOutTime.minute.toString().padLeft(2, '0')})";
        } else {
          workingHours = "From $fromTime";
        }
      }
    }
    return Consumer<LanguageProvider>(
      builder: (_, ts, __) {
        return InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AttendanceFormPage(
                  attendanceId: data['id'],
                  workingHours: workingHours,
                ),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[850] : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.grey[850]! : Colors.grey[200]!,
                width: 0.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF000000).withOpacity(0.05),
                  offset: const Offset(0, 6),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(3.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: _buildImage(imageUrl, name),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? Colors.white
                                : AppStyle.primaryColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: "${ts.getCached("Check In")}  ",
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? Colors.white : Colors.green,
                                ),
                              ),
                              TextSpan(
                                text: formattedCheckIn,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: "${ts.getCached('Check Out')}  ",
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? Colors.white : Colors.red,
                                ),
                              ),
                              TextSpan(
                                text: formattedCheckOut,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (state.accessForAction)
                    Builder(
                      builder: (menuContext) {
                        final bloc = Provider.of<AttendanceListBloc>(
                          menuContext,
                          listen: false,
                        );

                        return PopupMenuButton<String>(
                          offset: const Offset(0, 40),
                          color: isDark ? Colors.grey[900] : Colors.grey[50],
                          icon: const Icon(Icons.more_vert, size: 20),
                          onSelected: (value) {
                            if (value == 'delete') {
                              bloc.add(DeleteAttendance(data['id']));
                            }
                          },
                          itemBuilder: (BuildContext context) => [
                            PopupMenuItem<String>(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(
                                    HugeIcons.strokeRoundedDelete02,
                                    color: Colors.red,
                                    size: 20,
                                  ),
                                  SizedBox(width: 12),
                                  tr(
                                    'Delete Attendance',
                                    style: TextStyle(
                                      color: Colors.red[400]!,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Renders avatar — either from base64, remote URL, or placeholder with initials
  Widget _buildImage(String? imgUrl, String name) {
    if (imgUrl == null || imgUrl.isEmpty) return _placeholderAvatar(name);

    if (imgUrl.startsWith("data:image") || imgUrl.length > 500) {
      try {
        final base64String = imgUrl.contains(",")
            ? imgUrl.split(",").last
            : imgUrl;
        return Image.memory(
          base64Decode(base64String),
          width: 56,
          height: 56,
          fit: BoxFit.cover,
        );
      } catch (e) {
        return _placeholderAvatar(name);
      }
    }
    return _placeholderAvatar(name);
  }

  Widget _placeholderAvatar(String name) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : "?";
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return CircleAvatar(
      radius: 28,
      backgroundColor: isDark
          ? Colors.white.withOpacity(0.2)
          : AppStyle.primaryColor.withOpacity(0.2),
      child: Text(
        initial,
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white : AppStyle.primaryColor,
        ),
      ),
    );
  }

  /// Opens bottom sheet with Filter and Group By tabs
  void _openFilterGroupBySheet(BuildContext context) {
    final translationService = context.read<LanguageProvider>();

    final bloc = context.read<AttendanceListBloc>();
    final current = bloc.state is AttendanceLoaded
        ? bloc.state as AttendanceLoaded
        : null;

    List<String> selectedFilters = List<String>.from(
      current?.selectedFilters ?? const [],
    );
    String? selectedGroupBy = current?.selectedGroupBy;
    String? checkInUnit = current?.selectedCheckInUnit;
    String? checkOutUnit = current?.selectedCheckOutUnit;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      builder: (_) => DefaultTabController(
        length: 2,
        child: StatefulBuilder(
          builder: (context, setDialogState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            bool applying = false;

            return Container(
              height: MediaQuery.of(context).size.height * 0.8,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF232323) : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Stack(
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        child: Row(
                          children: [
                            tr(
                              'Filter & Group By',
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black87,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: Icon(
                                Icons.close,
                                color: isDark ? Colors.white : Colors.black54,
                              ),
                              splashRadius: 20,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[800] : Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TabBar(
                          indicator: BoxDecoration(
                            color: isDark
                                ? Color(0xFF2A2A2A)
                                : AppStyle.primaryColor,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: isDark
                                    ? Color(0xFF2A2A2A).withOpacity(0.3)
                                    : AppStyle.primaryColor.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          indicatorPadding: const EdgeInsets.all(4),
                          indicatorSize: TabBarIndicatorSize.tab,
                          dividerColor: Colors.transparent,
                          labelColor: Colors.white,
                          unselectedLabelColor: isDark
                              ? Colors.grey[400]
                              : Colors.grey[600],
                          labelStyle: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          unselectedLabelStyle: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                          tabs: [
                            Tab(
                              height: 48,
                              text: translationService.getCached('Filter'),
                            ),
                            Tab(
                              height: 48,
                              text: translationService.getCached('Group By'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: TabBarView(
                          children: [
                            SingleChildScrollView(
                              padding: const EdgeInsets.all(20),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: filterTechnicalNames.keys.map((
                                  label,
                                ) {
                                  final tech = filterTechnicalNames[label]!;
                                  final selected = selectedFilters.contains(
                                    tech,
                                  );
                                  return FilterChip(
                                    label: tr(
                                      label,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: selected
                                            ? Colors.white
                                            : (isDark
                                                  ? Colors.white70
                                                  : Colors.black87),
                                      ),
                                    ),
                                    selected: selected,
                                    onSelected: (v) {
                                      setDialogState(() {
                                        if (v) {
                                          if (!selectedFilters.contains(tech)) {
                                            selectedFilters.add(tech);
                                          }
                                        } else {
                                          selectedFilters.remove(tech);
                                        }
                                      });
                                    },
                                    selectedColor: isDark
                                        ? Color(0xFF131313)
                                        : AppStyle.primaryColor,
                                    backgroundColor: isDark
                                        ? const Color(0xFF2A2A2A)
                                        : Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    checkmarkColor: Colors.white,
                                  );
                                }).toList(),
                              ),
                            ),

                            ListView(
                              padding: const EdgeInsets.all(20),
                              children: groupTechnicalNames.keys.map((label) {
                                final tech = groupTechnicalNames[label]!;
                                final isSelected = selectedGroupBy == tech;

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        setDialogState(() {
                                          selectedGroupBy = tech;
                                          checkInUnit = tech == "check_in"
                                              ? "day"
                                              : checkInUnit;
                                          checkOutUnit = tech == "check_out"
                                              ? "day"
                                              : checkOutUnit;
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        margin: const EdgeInsets.only(
                                          bottom: 6,
                                          left: 12,
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              isSelected
                                                  ? Icons.radio_button_checked
                                                  : Icons
                                                        .radio_button_unchecked,
                                              color: isSelected
                                                  ? (isDark
                                                        ? Colors.white
                                                        : AppStyle.primaryColor)
                                                  : Colors.grey,
                                              size: 22,
                                            ),
                                            const SizedBox(width: 12),
                                            tr(
                                              label,
                                              style: TextStyle(
                                                color: isDark
                                                    ? Colors.white70
                                                    : Colors.black87,
                                                fontSize: 15,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    if (isSelected &&
                                        (tech == "check_in" ||
                                            tech == "check_out"))
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          left: 40,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: dateUnits.keys.map((
                                            unitLabel,
                                          ) {
                                            final unitTech =
                                                dateUnits[unitLabel]!;
                                            final currentUnit =
                                                tech == "check_in"
                                                ? checkInUnit
                                                : checkOutUnit;
                                            final selected =
                                                currentUnit == unitTech;
                                            return InkWell(
                                              onTap: () {
                                                setDialogState(() {
                                                  if (tech == "check_in") {
                                                    checkInUnit = unitTech;
                                                  } else {
                                                    checkOutUnit = unitTech;
                                                  }
                                                });
                                              },
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 6,
                                                      horizontal: 8,
                                                    ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      selected
                                                          ? Icons
                                                                .radio_button_checked
                                                          : Icons
                                                                .radio_button_unchecked,
                                                      color: selected
                                                          ? (isDark
                                                                ? Colors.white
                                                                : AppStyle
                                                                      .primaryColor)
                                                          : Colors.grey,
                                                      size: 20,
                                                    ),
                                                    const SizedBox(width: 6),
                                                    tr(
                                                      unitLabel,
                                                      style: TextStyle(
                                                        color: isDark
                                                            ? Colors.white70
                                                            : Colors.black87,
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[850] : Colors.grey[50],
                          border: Border(
                            top: BorderSide(
                              color: isDark
                                  ? Colors.grey[700]!
                                  : Colors.grey[200]!,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  setDialogState(() {
                                    selectedFilters.clear();
                                    selectedGroupBy = null;
                                    checkInUnit = null;
                                    checkOutUnit = null;
                                  });
                                  bloc.add(ClearFilters());
                                  Navigator.pop(context);
                                },

                                style: OutlinedButton.styleFrom(
                                  foregroundColor: isDark
                                      ? Colors.white
                                      : Colors.black87,
                                  side: BorderSide(
                                    color: isDark
                                        ? Colors.grey[600]!
                                        : Colors.grey[300]!,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: tr(
                                  'Clear All',
                                  style: TextStyle(
                                    color: isDark ? Colors.white : Colors.black,
                                    fontWeight: FontWeight.normal,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton(
                                onPressed: () {
                                  setDialogState(() => applying = true);
                                  bloc.add(
                                    ApplyFilters(
                                      selectedFilters: selectedFilters,
                                      selectedGroupBy: selectedGroupBy,
                                      selectedCheckInUnit: checkInUnit,
                                      selectedCheckOutUnit: checkOutUnit,
                                      searchText: _searchController.text.trim(),
                                    ),
                                  );
                                  Navigator.pop(context);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isDark
                                      ? Colors.white
                                      : AppStyle.primaryColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: tr(
                                  'Apply',
                                  style: TextStyle(
                                    color: isDark ? Colors.black : Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (applying)
                    Container(
                      color: Colors.black38,
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
