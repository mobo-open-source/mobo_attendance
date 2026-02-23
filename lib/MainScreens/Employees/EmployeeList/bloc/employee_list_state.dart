part of 'employee_list_bloc.dart';

/// Immutable state class for [EmployeeListBloc].
///
/// Holds:
/// - Loading states (full screen, page change, filter apply)
/// - Paginated employee data (flat list + grouped view)
/// - Pagination metadata (current page, total count, displayed range)
/// - Search term and active filters/group-by settings
/// - Group expansion state (for grouped view)
/// - Permission flag (can archive/delete)
/// - Pre-applied filter context (from deep link/navigation)
/// - One-time error/warning messages + connection/catch error flags
///
/// Uses `copyWith` pattern for immutable updates.
/// Equality is based on meaningful fields (via Equatable or manual override if added).
class EmployeeListState {
  final bool isLoading;
  final bool pageLoading;
  final bool filterLoading;
  final List<Map<String, dynamic>> employees;
  final List<Map<String, dynamic>> groupedEmployees;
  final int currentPage;
  final int totalCount;
  final int displayedCount;
  final String searchQuery;
  final List<String> selectedFilters;
  final String? selectedGroupBy;
  final String? selectedStartDateUnit;
  final Map<String, bool> groupExpanded;
  final bool accessForAction;
  final List<int>? preFilteredEmployeeIds;
  final String? currentFilterTitle;
  final String? errorMessage;
  final String? warningMessage;
  final bool catchError;
  final bool connectionError;

  EmployeeListState({
    this.isLoading = true,
    this.pageLoading = false,
    this.filterLoading = false,
    this.employees = const [],
    this.groupedEmployees = const [],
    this.currentPage = 0,
    this.totalCount = 0,
    this.displayedCount = 0,
    this.searchQuery = '',
    this.selectedFilters = const [],
    this.selectedGroupBy,
    this.selectedStartDateUnit,
    this.groupExpanded = const {},
    this.accessForAction = false,
    this.preFilteredEmployeeIds,
    this.currentFilterTitle,
    this.errorMessage,
    this.warningMessage,
    this.catchError = false,
    this.connectionError = false,
  });

  /// Creates a new state instance with updated values.
  ///
  /// All parameters are optional — unspecified fields keep their current value.
  /// Used extensively in event handlers for immutable state updates.
  EmployeeListState copyWith({
    bool? isLoading,
    bool? pageLoading,
    bool? filterLoading,
    List<Map<String, dynamic>>? employees,
    List<Map<String, dynamic>>? groupedEmployees,
    int? currentPage,
    int? totalCount,
    int? displayedCount,
    String? searchQuery,
    List<String>? selectedFilters,
    String? selectedGroupBy,
    String? selectedStartDateUnit,
    Map<String, bool>? groupExpanded,
    bool? accessForAction,
    List<int>? preFilteredEmployeeIds,
    String? currentFilterTitle,
    String? errorMessage,
    String? warningMessage,
    bool? catchError,
    bool? connectionError,
  }) {
    return EmployeeListState(
      isLoading: isLoading ?? this.isLoading,
      pageLoading: pageLoading ?? this.pageLoading,
      filterLoading: filterLoading ?? this.filterLoading,
      employees: employees ?? this.employees,
      groupedEmployees: groupedEmployees ?? this.groupedEmployees,
      currentPage: currentPage ?? this.currentPage,
      totalCount: totalCount ?? this.totalCount,
      displayedCount: displayedCount ?? this.displayedCount,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedFilters: selectedFilters ?? this.selectedFilters,
      selectedGroupBy: selectedGroupBy ?? this.selectedGroupBy,
      selectedStartDateUnit: selectedStartDateUnit ?? this.selectedStartDateUnit,
      groupExpanded: groupExpanded ?? this.groupExpanded,
      accessForAction: accessForAction ?? this.accessForAction,
      preFilteredEmployeeIds:
      preFilteredEmployeeIds ?? this.preFilteredEmployeeIds,
      currentFilterTitle: currentFilterTitle ?? this.currentFilterTitle,
      errorMessage: errorMessage ?? this.errorMessage,
      warningMessage: warningMessage ?? this.warningMessage,
      catchError: catchError ?? this.catchError,
      connectionError: connectionError ?? this.connectionError,
    );
  }
}