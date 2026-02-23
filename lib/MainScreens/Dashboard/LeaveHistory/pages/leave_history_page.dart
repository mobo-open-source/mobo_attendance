import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:lottie/lottie.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../CommonWidgets/core/language/translate_widget.dart';
import '../../../../CommonWidgets/core/providers/language_provider.dart';
import '../../../../CommonWidgets/globals.dart';
import '../bloc/leave_history_bloc.dart';

/// Entry point widget for the Leave History feature.
///
/// Simply delegates rendering to [LeaveHistoryView].
class LeaveHistoryPage extends StatelessWidget {
  const LeaveHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const LeaveHistoryView();
  }
}

/// Stateful view that displays the employee's leave history.
///
/// Features:
/// - Search by keyword (date, type, etc.)
/// - Filter by approval status (First, Second, Approved, Cancelled)
/// - Group by type / status / start date (with time unit selection)
/// - Pagination with prev/next buttons
/// - Pull-to-refresh
/// - Loading shimmer + empty state with animation
/// - Collapsible grouped sections
class LeaveHistoryView extends StatefulWidget {
  const LeaveHistoryView({super.key});

  @override
  State<LeaveHistoryView> createState() => _LeaveHistoryViewState();
}

class _LeaveHistoryViewState extends State<LeaveHistoryView> {
  final TextEditingController _searchController = TextEditingController();

  /// Maps user-friendly filter labels → technical filter keys used in bloc
  final Map<String, String> filterTechnicalNames = {
    "First Approval": "first_Approval",
    "Second Approval": "second_Approval",
    "Approved": "third_Approval",
    "Cancelled": "cancelled",
  };

  /// Maps user-friendly group labels → technical group keys
  final Map<String, String> groupTechnicalNames = {
    "Type": "type",
    "Status": "status",
    "Start Date": "start_date",
  };

  /// Available granularity options when grouping by start date
  final Map<String, String> startDateUnits = {
    "Year": "year",
    "Quarter": "quarter",
    "Month": "month",
    "Week": "week",
    "Day": "day",
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

  /// Converts Latin digits to locale-specific native digits
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
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Pull-to-refresh handler — reloads from page 0
  Future<void> _onRefresh() async {
    context.read<LeaveHistoryBloc>().add(const FetchLeaves(page: 0));
  }

  /// Opens bottom sheet with Filter & Group By tabs
  void _openFilterGroupBySheet(BuildContext context) {
    final blocContext = context;
    final translationService = context.read<LanguageProvider>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return BlocBuilder<LeaveHistoryBloc, LeaveHistoryState>(
          bloc: BlocProvider.of<LeaveHistoryBloc>(blocContext),
          builder: (context, state) {
            return StatefulBuilder(
              builder: (context, setDialogState) {
                final isDark = Theme.of(context).brightness == Brightness.dark;

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
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
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
                              _buildFilterTab(
                                blocContext,
                                setDialogState,
                                state,
                                isDark,
                              ),
                              _buildGroupByTab(
                                blocContext,
                                setDialogState,
                                state,
                                isDark,
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
                                    blocContext.read<LeaveHistoryBloc>().add(
                                      ClearAllFiltersAndGroupBy(),
                                    );
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
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black,
                                      fontWeight: FontWeight.normal,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: ElevatedButton(
                                  onPressed: () async {
                                    blocContext.read<LeaveHistoryBloc>().add(
                                      const FetchLeaves(page: 0),
                                    );
                                    Navigator.pop(blocContext);
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
                                      color: isDark
                                          ? Colors.black
                                          : Colors.white,
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
            );
          },
        );
      },
    );
  }

  /// Builds the "Filter" tab content (status/approval chips)
  Widget _buildFilterTab(
    BuildContext context,
    StateSetter setDialogState,
    LeaveHistoryState state,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: filterTechnicalNames.entries.map((entry) {
          final technical = entry.value;
          final selected = state.selectedFilters.contains(technical);
          return FilterChip(
            label: tr(
              entry.key,
              style: TextStyle(
                fontSize: 13,
                color: selected
                    ? Colors.white
                    : (isDark ? Colors.white70 : Colors.black87),
              ),
            ),
            selected: selected,
            onSelected: (val) {
              setDialogState(() {
                final newFilters = List<String>.from(state.selectedFilters);
                if (val) {
                  newFilters.add(technical);
                } else {
                  newFilters.remove(technical);
                }
                context.read<LeaveHistoryBloc>().add(UpdateFilters(newFilters));
              });
            },

            selectedColor: isDark ? Color(0xFF131313) : AppStyle.primaryColor,
            backgroundColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            checkmarkColor: Colors.white,
          );
        }).toList(),
      ),
    );
  }

  /// Builds the "Group By" tab content (type/status/date options)
  Widget _buildGroupByTab(
    BuildContext context,
    StateSetter setDialogState,
    LeaveHistoryState state,
    bool isDark,
  ) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: groupTechnicalNames.entries.map((entry) {
        final label = entry.key;
        final technical = entry.value;
        final isSelected = state.selectedGroupBy == technical;

        if (label == "Start Date") {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _groupByItem(
                context,
                setDialogState,
                label,
                technical,
                isSelected,
                isDark,
              ),
              if (isSelected)
                ...startDateUnits.entries.map((unitEntry) {
                  final unitLabel = unitEntry.key;
                  final unitTech = unitEntry.value;
                  final unitSelected = state.selectedStartDateUnit == unitTech;
                  return Padding(
                    padding: const EdgeInsets.only(left: 40),
                    child: _groupByItem(
                      context,
                      setDialogState,
                      unitLabel,
                      unitTech,
                      unitSelected,
                      isDark,
                      isSubItem: true,
                      onTap: () {
                        context.read<LeaveHistoryBloc>().add(
                          UpdateGroupBy(
                            groupBy: 'start_date',
                            startDateUnit: unitTech,
                          ),
                        );
                      },
                    ),
                  );
                }),
            ],
          );
        }

        return _groupByItem(
          context,
          setDialogState,
          label,
          technical,
          isSelected,
          isDark,
          onTap: () {
            context.read<LeaveHistoryBloc>().add(
              UpdateGroupBy(groupBy: technical),
            );
          },
        );
      }).toList(),
    );
  }

  /// Reusable selectable item for group-by options
  Widget _groupByItem(
    BuildContext context,
    StateSetter setDialogState,
    String label,
    String technical,
    bool isSelected,
    bool isDark, {
    bool isSubItem = false,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap:
          onTap ??
          () {
            setDialogState(() {
              context.read<LeaveHistoryBloc>().add(
                UpdateGroupBy(groupBy: technical),
              );
            });
          },
      child: Container(
        padding: isSubItem
            ? const EdgeInsets.symmetric(vertical: 6, horizontal: 8)
            : const EdgeInsets.symmetric(vertical: 12),
        margin: const EdgeInsets.only(bottom: 6, left: 12),

        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: isSelected
                  ? (isDark ? Colors.white : AppStyle.primaryColor)
                  : Colors.grey,
              size: 22,
            ),
            const SizedBox(width: 10),
            tr(
              label,
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black87,
                fontSize: isSubItem ? 14 : 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final translationService = context.read<LanguageProvider>();
    final locale = translationService.currentCode;

    return Scaffold(
      backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
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
          "Leave History",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            )
        ),
      ),
      body: BlocBuilder<LeaveHistoryBloc, LeaveHistoryState>(
        builder: (context, state) {
          return Stack(
            children: [
              Column(
                children: [
                  // Search field + filter/group button
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 17,
                      vertical: 10,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                        border: Border.all(color: Colors.transparent, width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 6,
                            spreadRadius: 1,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          hintText: translationService.getCached(
                            'Search by Date and Time-off type',
                          ),
                          hintStyle: TextStyle(
                            color: isDark ? Colors.white : Color(0xff1E1E1E),
                            fontFamily: TextStyle().fontFamily,
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
                            onPressed: () => _openFilterGroupBySheet(context),
                          ),
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
                          context.read<LeaveHistoryBloc>().add(
                            UpdateSearchQuery(value),
                          );
                        },
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 20),
                        child: Row(
                          children: [
                            if (state.selectedFilters.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black,
                                    borderRadius: BorderRadius.circular(12),
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
                                      const SizedBox(width: 6),
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
                              ),

                            if (state.selectedGroupBy.isNotEmpty)
                              Builder(
                                builder: (context) {
                                  String displayName = "Unknown";

                                  final groupDisplayMap = {
                                    "type": "Type",
                                    "status": "Status",
                                    "start_date": "Start Date",
                                  };

                                  displayName =
                                      groupDisplayMap[state.selectedGroupBy] ??
                                      state.selectedGroupBy.replaceAll(
                                        '_',
                                        ' ',
                                      );

                                  if (state.selectedGroupBy == "start_date" &&
                                      state.selectedStartDateUnit.isNotEmpty) {
                                    final unitMap = {
                                      "year": "Year",
                                      "quarter": "Quarter",
                                      "month": "Month",
                                      "week": "Week",
                                      "day": "Day",
                                    };

                                    final unitDisplay =
                                        unitMap[state.selectedStartDateUnit] ??
                                        state.selectedStartDateUnit;

                                    displayName = "Start Date ($unitDisplay)";
                                  }

                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.black,
                                      borderRadius: BorderRadius.circular(12),
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
                                          displayName,
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
                                  );
                                },
                              ),

                            if (state.selectedFilters.isEmpty &&
                                state.selectedGroupBy.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 2,
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
                              ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white10
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              "${localeNumber(state.pageRange.toString(), locale)} / ${localeNumber(state.totalCount.toString(), locale)}",
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              HugeIcons.strokeRoundedArrowLeft01,
                              color: state.currentPage > 0
                                  ? (isDark ? Colors.white70 : Colors.black87)
                                  : (isDark
                                        ? Colors.grey[800]
                                        : Colors.grey.withOpacity(0.7)),
                            ),
                            onPressed: state.currentPage > 0
                                ? () => context.read<LeaveHistoryBloc>().add(
                                    FetchLeaves(
                                      page: state.currentPage - 1,
                                      isPagination: true,
                                    ),
                                  )
                                : null,
                          ),
                          IconButton(
                            icon: Icon(
                              HugeIcons.strokeRoundedArrowRight01,
                              color:
                                  (state.currentPage + 1) * state.itemsPerPage <
                                      state.totalCount
                                  ? (isDark ? Colors.white70 : Colors.black87)
                                  : (isDark
                                        ? Colors.grey[800]
                                        : Colors.grey.withOpacity(0.7)),
                            ),
                            onPressed:
                                (state.currentPage + 1) * state.itemsPerPage <
                                    state.totalCount
                                ? () => context.read<LeaveHistoryBloc>().add(
                                    FetchLeaves(
                                      page: state.currentPage + 1,
                                      isPagination: true,
                                    ),
                                  )
                                : null,
                          ),
                        ],
                      ),
                    ],
                  ),
                  Expanded(
                    child: state.isLoading
                        ? _buildShimmerList(isDark)
                        : state.leaves.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Lottie.asset(
                                  'assets/empty_ghost.json',
                                  width: 300,
                                  height: 300,
                                  fit: BoxFit.contain,
                                  repeat: true,
                                  animate: true,
                                ),
                                tr(
                                  'No leaves found',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF1A1A1A),
                                  ),
                                ),
                                if (state.selectedFilters.isNotEmpty ||
                                    (state.selectedGroupBy?.isNotEmpty ??
                                        false)) ...[
                                  const SizedBox(height: 8),
                                  tr(
                                    'Try adjusting your filter',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.normal,
                                      color: isDark
                                          ? Colors.white60
                                          : Colors.black54,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  OutlinedButton(
                                    onPressed: () {
                                      context.read<LeaveHistoryBloc>().add(
                                        ClearAllFiltersAndGroupBy(),
                                      );
                                    },
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: isDark
                                          ? Colors.white
                                          : AppStyle.primaryColor,
                                      side: BorderSide(
                                        color: isDark
                                            ? Colors.grey[600]!
                                            : AppStyle.primaryColor.withOpacity(
                                                0.3,
                                              ),
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
                                      'Clear All Filters',
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.white
                                            : AppStyle.primaryColor,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          )
                        : _buildLeavesList(context, state, isDark),
                  ),
                ],
              ),
              // Overlay loading indicator during pagination
              if (state.isPageLoading)
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
    );
  }

  /// Shimmer placeholder for leave list while loading
  Widget _buildShimmerList(bool isDark) {
    final baseColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = isDark ? Colors.grey[700]! : Colors.grey[100]!;

    return ListView.builder(
      itemCount: 10,
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: baseColor,
        highlightColor: highlightColor,
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ListTile(
            title: Container(height: 16, color: Colors.white),
            subtitle: Container(
              height: 14,
              margin: EdgeInsets.only(top: 8),
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  /// Main list builder — either flat list or grouped collapsible sections
  Widget _buildLeavesList(
    BuildContext context,
    LeaveHistoryState state,
    bool isDark,
  ) {
    if (state.selectedGroupBy.isEmpty) {
      return RefreshIndicator(
        onRefresh: _onRefresh,
        color: AppStyle.primaryColor,
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: state.leaves.length,
          itemBuilder: (_, index) => _leaveCard(state.leaves[index], isDark),
        ),
      );
    }
    final grouped = state.groupedLeaves;
    if (grouped.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset(
              'assets/empty_ghost.json',
              width: 300,
              height: 300,
              fit: BoxFit.contain,
              repeat: true,
              animate: true,
            ),
            tr(
              'No leaves found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF1A1A1A),
              ),
            ),
            if (state.selectedFilters.isNotEmpty ||
                (state.selectedGroupBy?.isNotEmpty ?? false)) ...[
              const SizedBox(height: 8),
              tr(
                'Try adjusting your filter',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.normal,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () {
                  context.read<LeaveHistoryBloc>().add(
                    ClearAllFiltersAndGroupBy(),
                  );
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
                  'Clear All Filters',
                  style: TextStyle(
                    color: isDark ? Colors.white : AppStyle.primaryColor,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: AppStyle.primaryColor,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: grouped.length,
        itemBuilder: (_, index) {
          final group = grouped[index];
          final groupName = group["group"] as String;
          final leaves = group["leave"] as List<Map<String, dynamic>>;
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () {
                    final newMap = Map<String, bool>.from(state.groupExpanded);
                    newMap[groupName] = !expanded;
                    context.read<LeaveHistoryBloc>().emit(
                      state.copyWith(groupExpanded: newMap),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            groupName,
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
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
                if (expanded) ...leaves.map((leave) => Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: _leaveCard(leave, isDark),
                )),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Renders a single leave request card
  Widget _leaveCard(Map<String, dynamic> leave, bool isDark) {
    final translationService = context.read<LanguageProvider>();

    final String status = leave["state"] is String ? leave["state"] : "unknown";

    final String name = leave["display_name"] is String
        ? leave["display_name"]
        : "Unknown";

    final String description = leave["name"] is String ? leave["name"] : "";

    final String type =
        (leave["holiday_status_id"] is List &&
            leave["holiday_status_id"].length > 1 &&
            leave["holiday_status_id"][1] is String)
        ? leave["holiday_status_id"][1]
        : "Unknown";

    final double days =
        (leave["number_of_days_display"] as num?)?.toDouble() ?? 0.0;

    final String startDate = leave["request_date_from"] is String
        ? leave["request_date_from"]
        : "-";

    final String endDate = leave["request_date_to"] is String
        ? leave["request_date_to"]
        : "-";

    Color statusColor = _getStatusColor(status);
    String statusLabel = _getStatusLabel(status);

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
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: isDark ? Colors.white : AppStyle.primaryColor,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.15)
                        : statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: tr(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              type,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white60 : Colors.black54,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
            ],
            const SizedBox(height: 3),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      "$startDate → $endDate",
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
                Text(
                  "$days ${translationService.getCached('days')}",
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Maps internal status code to user-friendly label
  String _getStatusLabel(String status) {
    switch (status) {
      case "draft":
        return "To Submit";
      case "confirm":
        return "To Approve";
      case "refuse":
        return "Refused";
      case "validate1":
        return "Second Approval";
      case "validate":
        return "Approved";
      default:
        return status;
    }
  }

  /// Returns color associated with each leave status
  Color _getStatusColor(String status) {
    switch (status) {
      case "draft":
        return Colors.orange;
      case "confirm":
        return Colors.blue;
      case "refuse":
        return Colors.red;
      case "validate1":
        return Colors.purple;
      case "validate":
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}
