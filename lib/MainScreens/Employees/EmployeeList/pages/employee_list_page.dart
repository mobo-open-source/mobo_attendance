import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../CommonWidgets/core/company/infrastructure/company_refresh_bus.dart';
import '../../../../CommonWidgets/core/company/providers/company_provider.dart';
import '../../../../CommonWidgets/core/language/translate_widget.dart';
import '../../../../CommonWidgets/core/providers/language_provider.dart';
import '../../../../CommonWidgets/core/providers/motion_provider.dart';
import '../../../../CommonWidgets/globals.dart';
import '../../../../CommonWidgets/shared/widgets/snackbar.dart';
import '../../../AppBars/infrastructure/profile_refresh_bus.dart';
import '../../EmployeeCreate/pages/employee_create_page.dart';
import '../../EmployeeForm/Form/pages/employee_form_page.dart';
import '../bloc/employee_list_bloc.dart';

/// Main screen displaying the list of employees with search, filter, group-by, pagination,
/// and quick actions (archive/delete if permitted).
///
/// Features:
/// - Real-time search by name
/// - Filter chips + group-by dropdown (via bottom sheet)
/// - Horizontal pagination controls
/// - Pull-to-refresh with company/profile refresh on error
/// - Grouped or flat list view
/// - Floating action button to create new employee (if permitted)
/// - Error/empty/connection states with Lottie animations
/// - Locale-aware number formatting for Arabic/Persian/etc.
class EmployeeListPage extends StatelessWidget {
  const EmployeeListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmployeeListView();
  }
}

class EmployeeListView extends StatelessWidget {
  const EmployeeListView({super.key});

  static const int itemsPerPage = 40;

  /// Mapping of Latin digits to native script digits for supported locales
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

  /// Converts Latin digits to native script digits based on current locale
  String localeNumber(String input, String locale) {
    final code = locale.split('_').first.toLowerCase();
    final map = _digitMaps[code];
    if (map == null) return input;

    map.forEach((latin, native) {
      input = input.replaceAll(latin, native);
    });
    return input;
  }

  @override
  Widget build(BuildContext context) {
    final motionProvider = Provider.of<MotionProvider>(context, listen: false);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final translationService = context.watch<LanguageProvider>();
    final locale = translationService.currentCode;

    return BlocConsumer<EmployeeListBloc, EmployeeListState>(
      listener: (context, state) {
        if (state.errorMessage != null) {
          CustomSnackbar.showError(context, state.errorMessage!);
        }
        if (state.warningMessage != null) {
          CustomSnackbar.showWarning(context, state.warningMessage!);
        }
      },
      builder: (context, state) {
        final bloc = context.read<EmployeeListBloc>();
        final isPreFiltered = state.preFilteredEmployeeIds != null;

        return Scaffold(
          backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
          // AppBar only shown when coming from filtered view
          appBar: isPreFiltered
              ? AppBar(
                  backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
                  elevation: 0,
                  leading: IconButton(
                    icon: Icon(
                      HugeIcons.strokeRoundedArrowLeft01,
                      color: isDark ? Colors.white : Colors.black,
                      size: 28,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  title: tr(
                    state.currentFilterTitle ?? "Filtered Employees",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                )
              : null,
          body: Stack(
            children: [
              RefreshIndicator(
                color: isDark ? Colors.white : AppStyle.primaryColor,
                onRefresh: () async {
                  final bloc = context.read<EmployeeListBloc>();
                  final currentState = bloc.state;

                  if (currentState.catchError) {
                    await context.read<CompanyProvider>().initialize();
                    ProfileRefreshBus.notifyProfileRefresh();
                    CompanyRefreshBus.notify();
                  } else {
                    bloc.add(
                      FetchEmployees(
                        page: 0,
                        searchQuery: currentState.searchQuery,
                        isUserPagination: true,
                      ),
                    );
                  }
                },
                child: Column(
                  children: [
                    // Search + filter bar
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
                        child: TextField(
                          style: TextStyle(
                            color: isDark ? Colors.white : Color(0xff1E1E1E),
                            fontWeight: FontWeight.w400,
                            fontStyle: FontStyle.normal,
                            fontSize: 15,
                            height: 1.0,
                            letterSpacing: 0.0,
                          ),
                          onChanged: (value) {
                            bloc.add(
                              FetchEmployees(
                                page: 0,
                                searchQuery: value,
                                isUserPagination: true,
                              ),
                            );
                          },
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            isDense: true,
                            alignLabelWithHint: true,
                            hintText:
                                translationService.getCached(
                                  'Search by name',
                                ) ??
                                'Search by name',
                            hintStyle: TextStyle(
                              color: isDark ? Colors.white : Color(0xff1E1E1E),
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
                              tooltip: translationService.getCached(
                                'Filter & Group By',
                              ),
                              splashRadius: 20,
                              padding: EdgeInsets.zero,
                              constraints: BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                              onPressed: () => _openFilterGroupBySheet(context),
                            ),
                            filled: true,
                            fillColor: isDark ? Colors.grey[850] : Colors.white,
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
                        ),
                      ),
                    ),

                    // Filter/Group chips + pagination controls
                    if (!state.catchError)
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minWidth: MediaQuery.of(context).size.width - 32,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Builder(
                                  builder: (context) {
                                    final hasFilters =
                                        state.selectedFilters.isNotEmpty;
                                    final hasGroupBy =
                                        (state.selectedGroupBy?.isNotEmpty ??
                                        false);

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
                                      final groupMap = state.accessForAction
                                          ? {
                                              "Manager": "manager",
                                              "Department": "department",
                                              "Job": "job",
                                              "Skills": "skills",
                                              "Tags": "tags",
                                              "Start Date": "start_date",
                                            }
                                          : {
                                              "Manager": "manager",
                                              "Department": "department",
                                              "Job": "job",
                                              "Start Date": "start_date",
                                            };

                                      groupDisplayName = groupMap.keys
                                          .firstWhere(
                                            (key) =>
                                                groupMap[key] ==
                                                state.selectedGroupBy,
                                            orElse: () => state.selectedGroupBy!
                                                .replaceAll('_', ' '),
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
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            localeNumber(
                                              _getPageRange(
                                                state.currentPage,
                                                itemsPerPage,
                                                state.totalCount,
                                              ),
                                              locale,
                                            ),
                                            style: TextStyle(
                                              color: isDark
                                                  ? Colors.white70
                                                  : Colors.black87,
                                              fontSize: 14,
                                              fontWeight: FontWeight.normal,
                                            ),
                                          ),
                                          Text(
                                            ' / ',
                                            style: TextStyle(
                                              color: isDark
                                                  ? Colors.white70
                                                  : Colors.black87,
                                              fontSize: 14,
                                              fontWeight: FontWeight.normal,
                                            ),
                                          ),
                                          Text(
                                            '${localeNumber(state.totalCount.toString(), locale)}',
                                            style: TextStyle(
                                              color: isDark
                                                  ? Colors.white70
                                                  : Colors.black87,
                                              fontSize: 14,
                                              fontWeight: FontWeight.normal,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    Container(
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 4.0,
                                      ),
                                      child: InkWell(
                                        onTap: state.currentPage > 0
                                            ? () => bloc.add(
                                                FetchEmployees(
                                                  page: state.currentPage - 1,
                                                  searchQuery:
                                                      state.searchQuery,
                                                  isUserPagination: true,
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
                                            (state.currentPage + 1) *
                                                    itemsPerPage <
                                                state.totalCount
                                            ? () => bloc.add(
                                                FetchEmployees(
                                                  page: state.currentPage + 1,
                                                  searchQuery:
                                                      state.searchQuery,
                                                  isUserPagination: true,
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

                    // Main content area
                    Expanded(
                      child: state.isLoading
                          ? _buildShimmerList(isDark)
                          : state.catchError
                          ? _buildErrorState(isDark, context)
                          : state.connectionError
                          ? _buildConnectionErrorState(isDark, context)
                          : state.employees.isEmpty
                          ? _buildEmptyState(
                              isDark,
                              state.selectedFilters.isNotEmpty ||
                                  (state.selectedGroupBy?.isNotEmpty ?? false),
                              context,
                            )
                          : _buildEmployeeList(context, state, isDark),
                    ),
                  ],
                ),
              ),

              // Overlay loading during page/filter changes
              if (state.pageLoading || state.filterLoading)
                Center(
                  child: LoadingAnimationWidget.staggeredDotsWave(
                    color: AppStyle.primaryColor,
                    size: 50,
                  ),
                ),
            ],
          ),

          // FAB to create new employee (only if permitted and not in filtered view)
          floatingActionButton: state.accessForAction && !isPreFiltered
              ? FloatingActionButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (_, __, ___) => EmployeeCreatePage(),
                        transitionDuration: motionProvider.reduceMotion
                            ? Duration.zero
                            : const Duration(milliseconds: 300),
                        reverseTransitionDuration: motionProvider.reduceMotion
                            ? Duration.zero
                            : const Duration(milliseconds: 300),
                        transitionsBuilder: (_, animation, _, child) {
                          if (motionProvider.reduceMotion) return child;
                          return FadeTransition(
                            opacity: animation,
                            child: child,
                          );
                        },
                      ),
                    ).then((_) => bloc.add(ReloadEmployeeList()));
                  },
                  backgroundColor: isDark
                      ? Colors.white
                      : AppStyle.primaryColor,
                  child: Icon(
                    HugeIcons.strokeRoundedAdd01,
                    size: 25,
                    color: isDark ? Colors.black : Colors.white,
                  ),
                  tooltip: translationService.getCached('Add Employee'),
                )
              : null,
        );
      },
    );
  }

  /// Returns formatted page range string (e.g. "1-40")
  String _getPageRange(int currentPage, int itemsPerPage, int totalCount) {
    if (totalCount == 0) return '0-0';
    final start = currentPage * itemsPerPage + 1;
    final end = (start + itemsPerPage - 1).clamp(start, totalCount);
    return '$start-$end';
  }

  /// Shimmer loading placeholder for employee list
  Widget _buildShimmerList(bool isDark) {
    final baseColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = isDark ? Colors.grey[700]! : Colors.grey[100]!;

    return ListView.builder(
      itemCount: 10,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: baseColor,
          highlightColor: highlightColor,
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              title: Container(height: 16, width: 100, color: Colors.white),
              subtitle: Container(
                margin: const EdgeInsets.only(top: 8),
                height: 14,
                width: 150,
                color: Colors.white,
              ),
              trailing: Container(height: 20, width: 60, color: Colors.white),
            ),
          ),
        );
      },
    );
  }

  /// Empty state UI with optional "Clear Filters" button
  Widget _buildEmptyState(bool isDark, hasFilters, BuildContext context) {
    return _buildCenteredLottie(
      lottie: 'assets/empty_ghost.json',
      title: 'No Employees found',
      subtitle: hasFilters ? 'Try adjusting your filter' : null,
      isDark: isDark,
      button: hasFilters
          ? OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: isDark ? Colors.white : AppStyle.primaryColor,
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
                context.read<EmployeeListBloc>().add(ClearFilters());
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

  /// Centered Lottie animation + title/subtitle/button helper
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

  /// Error state with retry button
  Widget _buildErrorState(bool isDark, BuildContext context) {
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

  /// Connection error state with retry button
  Widget _buildConnectionErrorState(bool isDark, BuildContext context) {
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

  /// Builds the main employee list (grouped or flat)
  Widget _buildEmployeeList(
    BuildContext context,
    EmployeeListState state,
    bool isDark,
  ) {
    final bloc = context.read<EmployeeListBloc>();

    // Grouped view
    if (state.selectedGroupBy != null &&
        state.selectedGroupBy!.isNotEmpty &&
        state.groupedEmployees.isNotEmpty) {
      return ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: state.groupedEmployees.length,
        itemBuilder: (context, index) {
          final group = state.groupedEmployees[index];
          final groupName = group["group"] as String;
          final groupEmployees =
              group["employees"] as List<Map<String, dynamic>>;
          final isExpanded = state.groupExpanded[groupName] ?? true;

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
                  onTap: () => bloc.add(ToggleGroupExpanded(groupName)),
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
                                '${groupEmployees.length} employee${groupEmployees.length != 1 ? 's' : ''}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          isExpanded
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ],
                    ),
                  ),
                ),
                if (isExpanded)
                  ...groupEmployees.map(
                    (emp) => InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EmployeeFormPage(
                              employeeId: emp['id'],
                              employeeName: emp['name'],
                              preAppliedEmployeeIds:
                                  state.preFilteredEmployeeIds,
                              preAppliedFilterName: state.currentFilterTitle,
                            ),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: _employeeCard(
                          context,
                          emp,
                          state.accessForAction,
                          bloc,
                          isDark,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      );
    }

    // Flat list view
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: state.employees.length,
      itemBuilder: (context, index) {
        final emp = state.employees[index];
        return InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => EmployeeFormPage(
                  employeeId: emp['id'],
                  employeeName: emp['name'],
                  preAppliedEmployeeIds: state.preFilteredEmployeeIds,
                  preAppliedFilterName: state.currentFilterTitle,
                ),
              ),
            );
          },
          child: _employeeCard(
            context,
            emp,
            state.accessForAction,
            bloc,
            isDark,
          ),
        );
      },
    );
  }

  /// Renders a single employee card (avatar + name + job + dept + contact)
  Widget _employeeCard(
    BuildContext context,
    Map<String, dynamic> emp,
    bool accessForAction,
    EmployeeListBloc bloc,
    bool isDark,
  ) {
    final name = emp["name"] ?? "Unknown";
    final job = (emp["job_id"] is List && emp["job_id"].length > 1)
        ? emp["job_id"][1]
        : null;
    final dept =
        (emp["department_id"] is List && emp["department_id"].length > 1)
        ? emp["department_id"][1]
        : null;
    final phone =
        (emp["work_phone"] is String && emp["work_phone"].toString().isNotEmpty)
        ? emp["work_phone"]
        : (emp["mobile"] is String && emp["mobile"].toString().isNotEmpty)
        ? emp["mobile"]
        : null;
    final email =
        (emp["work_email"] is String && emp["work_email"].toString().isNotEmpty)
        ? emp["work_email"]
        : null;
    final imageUrl = emp["image_1920"] is String ? emp["image_1920"] : null;

    return Container(
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
              padding: const EdgeInsets.all(5.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _buildImage(imageUrl, name: name),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: isDark
                                    ? Colors.white
                                    : AppStyle.primaryColor,
                              ),
                            ),
                            const SizedBox(height: 5),
                            if (job != null)
                              Text(
                                job,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark
                                      ? Colors.white60
                                      : Colors.black54,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (accessForAction)
                        PopupMenuButton<String>(
                          position: PopupMenuPosition.under,
                          icon: Icon(
                            Icons.more_vert,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                            size: 20,
                          ),
                          color: isDark ? Colors.grey[900] : Colors.white,
                          elevation: 8,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          onSelected: (value) async {
                            if (value == 'archive') {
                              _showLoader(context, 'Archiving employee...');
                              bloc.add(ArchiveEmployee(emp['id']));
                              Navigator.pop(context);
                              if (bloc.state.errorMessage == null &&
                                  bloc.state.warningMessage == null) {
                                CustomSnackbar.showSuccess(
                                  context,
                                  'Employee archived successfully',
                                );
                              }
                            } else if (value == 'delete') {
                              _showLoader(context, 'Deleting employee...');
                              bloc.add(DeleteEmployee(emp['id']));
                              Navigator.pop(context);
                              if (bloc.state.errorMessage == null &&
                                  bloc.state.warningMessage == null) {
                                CustomSnackbar.showSuccess(
                                  context,
                                  'Employee deleted successfully',
                                );
                              }
                            }
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              value: 'archive',
                              child: Row(
                                children: [
                                  Icon(
                                    HugeIcons.strokeRoundedArchive03,
                                    color: isDark
                                        ? Colors.grey[300]
                                        : Colors.grey[800],
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  tr(
                                    'Archive Employee',
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(
                                    HugeIcons.strokeRoundedDelete02,
                                    color: Colors.red[400],
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  tr(
                                    'Delete Employee',
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
                        ),
                    ],
                  ),
                  if (dept != null)
                    Text(
                      dept,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  if (phone != null)
                    Text(
                      phone,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  if (email != null)
                    Text(
                      email,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white60 : Colors.black54,
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

  /// Renders employee avatar — supports base64, network URL, or fallback placeholder
  Widget _buildImage(String? img, {String? name}) {
    if (img == null || img.isEmpty) return _placeholder(name);

    final bool isBase64 = img.startsWith("data:image") || img.length > 500;
    if (isBase64) {
      try {
        final base64String = img.contains(",") ? img.split(",").last : img;
        final bytes = base64Decode(base64String);
        return Image.memory(
          bytes,
          height: 55,
          width: 55,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _placeholder(name),
        );
      } catch (e) {
        return _placeholder(name);
      }
    }
    return Image.network(
      img,
      height: 55,
      width: 55,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _placeholder(name),
    );
  }

  /// Fallback circular avatar with first letter or person icon
  Widget _placeholder(String? name) {
    final firstLetter = name?.isNotEmpty == true ? name![0].toUpperCase() : "";
    return Container(
      height: 55,
      width: 55,
      decoration: BoxDecoration(
        color:
            ThemeData.estimateBrightnessForColor(AppStyle.primaryColor) ==
                Brightness.dark
            ? Colors.white.withOpacity(0.2)
            : AppStyle.primaryColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(27.5),
      ),
      alignment: Alignment.center,
      child: firstLetter.isNotEmpty
          ? Text(
              firstLetter,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppStyle.primaryColor,
              ),
            )
          : const Icon(Icons.person, size: 30, color: AppStyle.primaryColor),
    );
  }

  /// Shows a non-dismissible loading dialog
  void _showLoader(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[900]
            : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 16),
              tr(message),
            ],
          ),
        ),
      ),
    );
  }

  /// Opens bottom sheet for filter & group-by selection
  void _openFilterGroupBySheet(BuildContext context) {
    final translationService = context.read<LanguageProvider>();
    final bloc = context.read<EmployeeListBloc>();
    final currentState = bloc.state;

    List<String> tempFilters = List.from(currentState.selectedFilters);
    String? tempGroupBy = currentState.selectedGroupBy;
    String? tempStartDateUnit = currentState.selectedStartDateUnit;

    final Map<String, String> filterTechnicalNames = {
      "My Team": "my_team",
      "My Department": "my_department",
      "Newly Hired": "newly_hired",
      "Archived": "archived",
    };

    final Map<String, String> groupTechnicalNamesForEmployee = {
      "Manager": "manager",
      "Department": "department",
      "Job": "job",
      "Start Date": "start_date",
    };

    final Map<String, String> groupTechnicalNamesForManagers = {
      "Manager": "manager",
      "Department": "department",
      "Job": "job",
      "Skills": "skills",
      "Tags": "tags",
      "Start Date": "start_date",
    };

    final Map<String, String> startDateUnits = {
      "Year": "year",
      "Quarter": "quarter",
      "Month": "month",
      "Week": "week",
      "Day": "day",
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final groupMap = currentState.accessForAction
              ? groupTechnicalNamesForManagers
              : groupTechnicalNamesForEmployee;

          return Container(
            height: MediaQuery.of(context).size.height * 0.8,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF232323) : Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: tr(
                            'Filter & Group By',
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
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
                          text:
                              translationService.getCached('Filter') ??
                              "Filter",
                        ),
                        Tab(
                          height: 48,
                          text:
                              translationService.getCached('Group By') ??
                              "Group By",
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  Expanded(
                    child: TabBarView(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: filterTechnicalNames.keys.map((label) {
                              final tech = filterTechnicalNames[label]!;
                              final selected = tempFilters.contains(tech);

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
                                onSelected: (val) {
                                  setDialogState(() {
                                    if (val) {
                                      tempFilters.add(tech);
                                    } else {
                                      tempFilters.remove(tech);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        ),

                        ListView(
                          padding: const EdgeInsets.all(20),
                          children: groupMap.keys.map((label) {
                            final tech = groupMap[label]!;
                            final isSelected = tempGroupBy == tech;
                            final isStartDate = label == "Start Date";

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    setDialogState(() {
                                      tempGroupBy = tech;
                                      if (isStartDate) {
                                        tempStartDateUnit ??= "day";
                                      } else {
                                        tempStartDateUnit = null;
                                      }
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
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
                                              : Icons.radio_button_unchecked,
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
                                if (isStartDate && isSelected)
                                  ...startDateUnits.keys.map((unitLabel) {
                                    final unitTech = startDateUnits[unitLabel]!;
                                    final unitSelected =
                                        tempStartDateUnit == unitTech;

                                    return Padding(
                                      padding: const EdgeInsets.only(left: 40),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          InkWell(
                                            onTap: () {
                                              setDialogState(() {
                                                tempStartDateUnit = unitTech;
                                              });
                                            },
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 6,
                                                    horizontal: 8,
                                                  ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    unitSelected
                                                        ? Icons
                                                              .radio_button_checked
                                                        : Icons
                                                              .radio_button_unchecked,
                                                    color: unitSelected
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
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                              ],
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),

                  // Bottom action buttons
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[850] : Colors.grey[50],
                      border: Border(
                        top: BorderSide(
                          color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              bloc.add(ClearFilters());
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
                              padding: const EdgeInsets.symmetric(vertical: 12),
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
                              bloc.add(
                                ApplyFiltersAndGroupBy(
                                  filters: tempFilters,
                                  groupBy: tempGroupBy,
                                  startDateUnit: tempStartDateUnit,
                                ),
                              );
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark
                                  ? Colors.white
                                  : AppStyle.primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
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
            ),
          );
        },
      ),
    );
  }
}
