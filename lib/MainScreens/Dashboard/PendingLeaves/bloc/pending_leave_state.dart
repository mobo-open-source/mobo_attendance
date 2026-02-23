part of 'pending_leave_bloc.dart';

/// Immutable state class for the Pending Leaves screen (HR/Manager approval view)
/// managed by [PendingLeaveBloc].
///
/// Holds:
/// - Paginated list of pending leave requests
/// - Grouped version of leaves (when grouping is active)
/// - Pagination metadata (current page, total count, items per page)
/// - Loading indicators (full load, pagination, per-leave action)
/// - Search term
/// - Active approval stage filters (first/second)
/// - Grouping settings (type/status/start_date + date unit)
/// - Expanded/collapsed state of each group
/// - Per-leave loading state (approve/validate/reject actions)
/// - Last error message (e.g. from approval/rejection failure)
/// - Temporary filter/group settings (preview in bottom sheet)
class PendingLeaveState extends Equatable {
  final List<Map<String, dynamic>> leaves;
  final List<Map<String, dynamic>> groupedLeaves;
  final int totalCount;
  final int currentPage;
  final int itemsPerPage;
  final bool isLoading;
  final bool isPageLoading;
  final String searchQuery;

  /// Active filter identifiers
  /// Typical values: `["first_Approval", "second_Approval"]`
  final List<String> selectedFilters;

  /// Current grouping criteria
  /// - empty → no grouping
  /// - "type" → by leave type
  /// - "status" → by approval state
  /// - "start_date" → by request start date
  final String selectedGroupBy;

  /// Granularity when grouping by start date
  /// Values: "year", "quarter", "month", "week", "day"
  final String selectedStartDateUnit;

  /// Tracks which groups are expanded in the UI
  /// Key = group name, Value = true (expanded) / false (collapsed)
  final Map<String, bool> groupExpanded;

  /// Per-leave loading state for approve/validate/reject actions
  /// Key = leave ID, Value = true (in progress) / false (idle)
  final Map<int, bool> leaveLoading;

  /// Last error message from an approval/validation/rejection action
  /// (null if no error)
  final String? errorMessage;

  // ── Temporary states (used in filter/group bottom sheet preview) ─────────

  /// Preview of selected filters before user presses "Apply"
  final List<String> tempSelectedFilters;

  /// Preview of selected grouping criteria before apply
  final String tempSelectedGroupBy;

  /// Preview of date grouping unit before apply
  final String tempSelectedStartDateUnit;

  const PendingLeaveState({
    this.leaves = const [],
    this.groupedLeaves = const [],
    this.totalCount = 0,
    this.currentPage = 0,
    this.itemsPerPage = 40,
    this.isLoading = false,
    this.isPageLoading = false,
    this.searchQuery = '',
    this.selectedFilters = const [],
    this.selectedGroupBy = '',
    this.selectedStartDateUnit = 'day',
    this.groupExpanded = const {},
    this.leaveLoading = const {},
    this.errorMessage,
    this.tempSelectedFilters = const [],
    this.tempSelectedGroupBy = '',
    this.tempSelectedStartDateUnit = 'day',
  });

  /// Creates a new state by copying the current one and overriding
  /// only the provided fields.
  ///
  /// Note: `itemsPerPage` is immutable and cannot be changed.
  PendingLeaveState copyWith({
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
    Map<int, bool>? leaveLoading,
    String? errorMessage,
    List<String>? tempSelectedFilters,
    String? tempSelectedGroupBy,
    String? tempSelectedStartDateUnit,
  }) {
    return PendingLeaveState(
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
      selectedStartDateUnit: selectedStartDateUnit ?? this.selectedStartDateUnit,
      groupExpanded: groupExpanded ?? this.groupExpanded,
      leaveLoading: leaveLoading ?? this.leaveLoading,
      errorMessage: errorMessage,
      tempSelectedFilters: tempSelectedFilters ?? this.tempSelectedFilters,
      tempSelectedGroupBy: tempSelectedGroupBy ?? this.tempSelectedGroupBy,
      tempSelectedStartDateUnit: tempSelectedStartDateUnit ?? this.tempSelectedStartDateUnit,
    );
  }

  /// Computed property returning the current visible item range in "start-end"
  /// format (1-based indexing).
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
    leaveLoading,
    errorMessage,
    tempSelectedFilters,
    tempSelectedGroupBy,
    tempSelectedStartDateUnit,
  ];
}
