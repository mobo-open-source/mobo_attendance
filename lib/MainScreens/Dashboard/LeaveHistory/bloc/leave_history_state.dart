part of 'leave_history_bloc.dart';

/// Immutable state class for the Leave History screen managed by [LeaveHistoryBloc].
///
/// Holds:
/// - Paginated list of leave requests
/// - Grouped version of leaves (when grouping is active)
/// - Pagination metadata (current page, total count, items per page)
/// - Loading indicators (full load vs pagination load)
/// - Current search term
/// - Active status/approval filters
/// - Grouping settings (by type/status/start_date + date unit)
/// - Expanded/collapsed state of each group
class LeaveHistoryState extends Equatable {
  final List<Map<String, dynamic>> leaves;
  final List<Map<String, dynamic>> groupedLeaves;
  final int totalCount;
  final int currentPage;
  final int itemsPerPage;
  final bool isLoading;
  final bool isPageLoading;

  /// Current search keyword (usually applied to employee name or leave description)
  final String searchQuery;

  /// Active filter identifiers
  /// Example values: `["first_Approval", "second_Approval", "third_Approval", "cancelled"]
  final List<String> selectedFilters;

  /// Current grouping criteria
  /// - empty string → no grouping
  /// - "type" → group by leave type
  /// - "status" → group by approval state
  /// - "start_date" → group by request start date
  final String selectedGroupBy;

  /// Granularity when grouping by start date
  /// Values: "year", "quarter", "month", "week", "day"
  final String selectedStartDateUnit;

  /// Tracks which groups are currently expanded in the UI
  /// Key = group name (from `groupedLeaves`), Value = expanded (true) / collapsed (false)
  final Map<String, bool> groupExpanded;

  const LeaveHistoryState({
    this.leaves = const [],
    this.groupedLeaves = const [],
    this.totalCount = 0,
    this.currentPage = 0,
    this.itemsPerPage = 40,
    this.isLoading = true,
    this.isPageLoading = false,
    this.searchQuery = '',
    this.selectedFilters = const [],
    this.selectedGroupBy = '',
    this.selectedStartDateUnit = 'day',
    this.groupExpanded = const {},
  });

  LeaveHistoryState copyWith({
    List<Map<String, dynamic>>? leaves,
    List<Map<String, dynamic>>? groupedLeaves,
    int? totalCount,
    int? currentPage,
    bool? isLoading,
    bool? isPageLoading,
    String? searchQuery,
    List<String>? selectedFilters,
    String? selectedGroupBy,
    String? selectedStartDateUnit,
    Map<String, bool>? groupExpanded,
  }) {
    return LeaveHistoryState(
      leaves: leaves ?? this.leaves,
      groupedLeaves: groupedLeaves ?? this.groupedLeaves,
      totalCount: totalCount ?? this.totalCount,
      currentPage: currentPage ?? this.currentPage,
      itemsPerPage: itemsPerPage,
      isLoading: isLoading ?? this.isLoading,
      isPageLoading: isPageLoading ?? this.isPageLoading,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedFilters: selectedFilters ?? this.selectedFilters,
      selectedGroupBy: selectedGroupBy ?? this.selectedGroupBy,
      selectedStartDateUnit:
          selectedStartDateUnit ?? this.selectedStartDateUnit,
      groupExpanded: groupExpanded ?? this.groupExpanded,
    );
  }

  /// Computed property that returns the current visible range of items
  /// in "start-end" format (1-based indexing)
  ///
  /// Examples:
  /// - "1-40" (first page)
  /// - "41-80" (second page)
  /// - "0-0" when no records
  String get pageRange {
    if (totalCount == 0) return '0-0';
    final start = currentPage * itemsPerPage + 1;
    final end = (start + itemsPerPage - 1).clamp(start, totalCount);
    return '$start-$end';
  }

  @override
  List<Object?> get props => [
    leaves,
    groupedLeaves,
    totalCount,
    currentPage,
    isLoading,
    isPageLoading,
    searchQuery,
    selectedFilters,
    selectedGroupBy,
    selectedStartDateUnit,
    groupExpanded,
  ];
}
