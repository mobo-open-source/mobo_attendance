import 'package:equatable/equatable.dart';

/// Immutable state class for the Reports screen (attendance analytics)
/// managed by [ReportBloc].
///
/// Holds:
/// - Loading indicators (full load vs filter-specific)
/// - Paginated graph/report data
/// - Pagination metadata (current page, total count, items per page)
/// - Search term
/// - Active filters (list of string identifiers)
/// - Grouping settings (check_in / check_out + time units)
/// - Selected measure/metric (e.g. "Worked Hours", "Late Count")
/// - Selected visualization mode (e.g. "line", "bar  ")
/// - Last error message (if data fetch fails)
class ReportState extends Equatable {
  final bool isLoading;
  final bool filterLoading;
  final List<Map<String, dynamic>> graphData;
  final int totalCount;
  final int currentPage;
  final int itemsPerPage;
  final String searchText;
  final List<String> selectedFilters;
  final List<String> selectedGroupByOptions;
  final List<String> selectedCheckInUnits;
  final List<String> selectedCheckOutUnits;
  final String selectedMeasure;
  final String selectedView;
  final String? errorMessage;

  const ReportState({
    this.isLoading = false,
    this.filterLoading = false,
    this.graphData = const [],
    this.totalCount = 0,
    this.currentPage = 0,
    this.itemsPerPage = 40,
    this.searchText = '',
    this.selectedFilters = const [],
    this.selectedGroupByOptions = const [],
    this.selectedCheckInUnits = const [],
    this.selectedCheckOutUnits = const [],
    this.selectedMeasure = 'Worked Hours',
    this.selectedView = 'line',
    this.errorMessage,
  });

  /// Computed property: number of items currently displayed
  /// (useful for "Showing X of Y" text)
  int get displayedCount {
    final previous = currentPage * itemsPerPage;
    return (previous + graphData.length).clamp(0, totalCount);
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

  /// Creates a new state instance by copying the current one and overriding
  /// only the provided fields.
  ///
  /// Note: `itemsPerPage` is immutable and cannot be overridden.
  ReportState copyWith({
    bool? isLoading,
    bool? filterLoading,
    List<Map<String, dynamic>>? graphData,
    int? totalCount,
    int? currentPage,
    String? searchText,
    List<String>? selectedFilters,
    List<String>? selectedGroupByOptions,
    List<String>? selectedCheckInUnits,
    List<String>? selectedCheckOutUnits,
    String? selectedMeasure,
    String? selectedView,
    String? errorMessage,
  }) {
    return ReportState(
      isLoading: isLoading ?? this.isLoading,
      filterLoading: filterLoading ?? this.filterLoading,
      graphData: graphData ?? this.graphData,
      totalCount: totalCount ?? this.totalCount,
      currentPage: currentPage ?? this.currentPage,
      searchText: searchText ?? this.searchText,
      selectedFilters: selectedFilters ?? this.selectedFilters,
      selectedGroupByOptions:
          selectedGroupByOptions ?? this.selectedGroupByOptions,
      selectedCheckInUnits: selectedCheckInUnits ?? this.selectedCheckInUnits,
      selectedCheckOutUnits:
          selectedCheckOutUnits ?? this.selectedCheckOutUnits,
      selectedMeasure: selectedMeasure ?? this.selectedMeasure,
      selectedView: selectedView ?? this.selectedView,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    isLoading,
    filterLoading,
    graphData,
    totalCount,
    currentPage,
    searchText,
    selectedFilters,
    selectedGroupByOptions,
    selectedCheckInUnits,
    selectedCheckOutUnits,
    selectedMeasure,
    selectedView,
    errorMessage,
  ];
}
