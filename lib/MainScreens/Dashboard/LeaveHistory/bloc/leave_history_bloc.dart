import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../services/leave_history_service.dart';

part 'leave_history_event.dart';

part 'leave_history_state.dart';

/// Manages the state and business logic for the Leave History screen.
///
/// Features:
/// - Loads paginated leave requests for the current employee
/// - Supports search by keyword
/// - Filtering by approval status (first, second, third, cancelled)
/// - Grouping leaves by type / status / start date (with unit selection: year/quarter/month/week/day)
/// - Handles loading states separately for initial load vs pagination
class LeaveHistoryBloc extends Bloc<LeaveHistoryEvent, LeaveHistoryState> {
  final LeaveHistoryService _service = LeaveHistoryService();

  LeaveHistoryBloc() : super(const LeaveHistoryState()) {
    on<InitializeLeaveHistory>(_onInitialize);
    on<FetchLeaves>(_onFetchLeaves);
    on<UpdateSearchQuery>(_onUpdateSearchQuery);
    on<UpdateFilters>(_onUpdateFilters);
    on<UpdateGroupBy>(_onUpdateGroupBy);
    on<ClearAllFiltersAndGroupBy>(_onClearAll);
  }

  /// Called once when the screen is first opened.
  /// Initializes the Odoo RPC client and triggers the first data fetch.
  Future<void> _onInitialize(
    InitializeLeaveHistory event,
    Emitter<LeaveHistoryState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));
    await _service.initializeClient();
    add(const FetchLeaves(page: 0));
  }

  /// Main data fetching handler.
  /// Loads leaves with current filters/search/grouping and updates pagination info.
  Future<void> _onFetchLeaves(
    FetchLeaves event,
    Emitter<LeaveHistoryState> emit,
  ) async {
    emit(
      state.copyWith(
        isPageLoading: event.isPagination,
        isLoading: !event.isPagination,
      ),
    );

    // Convert filter list to individual booleans expected by service
    final firstApproval = state.selectedFilters.contains("first_Approval");
    final secondApproval = state.selectedFilters.contains("second_Approval");
    final thirdApproval = state.selectedFilters.contains("third_Approval");
    final cancelledLeave = state.selectedFilters.contains("cancelled");

    // Fetch paginated leaves
    final leaves = await _service.loadCurrentEmployeeLeaves(
      event.page,
      state.itemsPerPage,
      searchQuery: state.searchQuery.isEmpty ? null : state.searchQuery,
      firstApproval: firstApproval,
      secondApproval: secondApproval,
      thirdApproval: thirdApproval,
      cancelledLeave: cancelledLeave,
    );

    // Get total count for pagination
    final totalCount = await _service.LeaveCount(
      searchText: state.searchQuery.isEmpty ? null : state.searchQuery,
      firstApproval: firstApproval,
      secondApproval: secondApproval,
      thirdApproval: thirdApproval,
      cancelledLeave: cancelledLeave,
    );

    // Apply grouping if enabled
    List<Map<String, dynamic>> grouped = [];
    Map<String, bool> newExpanded = {};

    if (state.selectedGroupBy.isNotEmpty) {
      grouped = _groupLeaves(
        leaves,
        state.selectedGroupBy,
        state.selectedStartDateUnit,
      );

      // Auto-expand all groups by default
      for (var group in grouped) {
        newExpanded[group["group"] as String] = true;
      }
    } else {
      grouped = [];
    }

    emit(
      state.copyWith(
        leaves: leaves,
        groupedLeaves: grouped,
        totalCount: totalCount,
        currentPage: event.page,
        isLoading: false,
        isPageLoading: false,
        groupExpanded: newExpanded,
      ),
    );
  }

  /// Updates search query and resets pagination to page 0
  void _onUpdateSearchQuery(
    UpdateSearchQuery event,
    Emitter<LeaveHistoryState> emit,
  ) {
    emit(state.copyWith(searchQuery: event.query));
    add(const FetchLeaves(page: 0));
  }

  /// Updates active status filters and refreshes data from page 0
  void _onUpdateFilters(UpdateFilters event, Emitter<LeaveHistoryState> emit) {
    emit(state.copyWith(selectedFilters: event.filters));
    add(const FetchLeaves(page: 0));
  }

  /// Changes grouping criteria (type/status/start_date) and refreshes data
  void _onUpdateGroupBy(UpdateGroupBy event, Emitter<LeaveHistoryState> emit) {
    final newGroupBy = event.groupBy;
    final newUnit = event.startDateUnit ?? state.selectedStartDateUnit;

    emit(
      state.copyWith(
        selectedGroupBy: newGroupBy,
        selectedStartDateUnit: newGroupBy == 'start_date' ? newUnit : 'day',
      ),
    );
    add(const FetchLeaves(page: 0));
  }

  /// Resets all filters, search, grouping and reloads data
  void _onClearAll(
    ClearAllFiltersAndGroupBy event,
    Emitter<LeaveHistoryState> emit,
  ) {
    emit(
      state.copyWith(
        selectedFilters: [],
        selectedGroupBy: '',
        selectedStartDateUnit: 'day',
        searchQuery: state.searchQuery,
        groupExpanded: {},
      ),
    );
    add(const FetchLeaves(page: 0));
  }

  // ---------------------------------------------------------------------------
  //  Grouping Logic
  // ---------------------------------------------------------------------------

  /// Groups leave records by the selected criteria (type, status, or start date)
  List<Map<String, dynamic>> _groupLeaves(
    List<Map<String, dynamic>> leaves,
    String groupBy,
    String unit,
  ) {
    final Map<String, List<Map<String, dynamic>>> grouped = {};

    for (var data in leaves) {
      String key = "Unknown";

      if (groupBy == "type") {
        key =
            (data["holiday_status_id"] is List &&
                data["holiday_status_id"].isNotEmpty)
            ? data["holiday_status_id"][1]
            : "None";
      } else if (groupBy == "status") {
        key = _mapStatusLabel(data["state"] ?? "None");
      } else if (groupBy == "start_date") {
        String? dateStr;
        if (data["request_date_from"] is String) {
          dateStr = data["request_date_from"];
        } else if (data["request_date_from"] is List &&
            data["request_date_from"].length > 1) {
          dateStr = data["request_date_from"][1];
        }

        String dateKey = "No Date";
        if (dateStr != null && dateStr.isNotEmpty) {
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
              dateKey = "${date.month}-${date.year}";
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
              dateKey = "${date.day}-${date.month}-${date.year}";
              break;
          }
        }
        key = dateKey;
      }

      grouped.putIfAbsent(key, () => []).add(data);
    }

    // Convert map to sorted list of group objects
    return grouped.entries
        .map((e) => {"group": e.key, "leave": e.value})
        .toList();
  }

  /// Maps internal Odoo leave state values to user-friendly labels
  String _mapStatusLabel(String state) {
    switch (state) {
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
        return "Unknown";
    }
  }
}
