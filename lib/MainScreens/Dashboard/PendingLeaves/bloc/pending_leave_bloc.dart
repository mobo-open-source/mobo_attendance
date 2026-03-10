import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobo_attendance/MainScreens/Dashboard/PendingLeaves/services/pending_leave_service.dart';

part 'pending_leave_event.dart';

part 'pending_leave_state.dart';

/// Manages state and business logic for the Pending Leaves screen (HR/Manager view).
///
/// Responsibilities:
/// - Loads paginated list of pending leave requests
/// - Supports keyword search
/// - Filtering by approval stages (first/second approval)
/// - Grouping by type / status / start date (with unit selection)
/// - Approve / Validate / Reject individual leaves
/// - Temporary filter/group state for bottom sheet preview
/// - Loading indicators (full load, pagination, per-leave action)
class PendingLeaveBloc extends Bloc<PendingLeaveEvent, PendingLeaveState> {
  late PendingLeaveService _service;

  PendingLeaveBloc({PendingLeaveService? service})
      : _service = service ?? PendingLeaveService(),
        super(const PendingLeaveState()) {
    on<InitializePendingLeave>(_onInitialize);
    on<FetchPendingLeaves>(_onFetchLeaves);
    on<UpdatePendingSearchQuery>(_onUpdateSearchQuery);
    on<ApproveLeave>(_onApproveLeave);
    on<ValidateLeave>(_onValidateLeave);
    on<RejectLeave>(_onRejectLeave);

    // Temporary states for filter/group bottom sheet (preview before apply)
    on<InitializeTempFilters>((event, emit) {
      emit(
        state.copyWith(
          tempSelectedFilters: List.from(event.filters),
          tempSelectedGroupBy: event.groupBy,
          tempSelectedStartDateUnit: event.startDateUnit,
        ),
      );
    });

    on<UpdateTempFilters>((event, emit) {
      emit(state.copyWith(tempSelectedFilters: event.filters));
    });

    on<UpdateTempGroupBy>((event, emit) {
      emit(
        state.copyWith(
          tempSelectedGroupBy: event.groupBy,
          tempSelectedStartDateUnit:
              event.startDateUnit ?? state.tempSelectedStartDateUnit,
        ),
      );
    });

    // Apply confirmed filters/grouping and refresh data
    on<ApplyFiltersAndGroupBy>((event, emit) async {
      emit(
        state.copyWith(
          selectedFilters: List.from(state.tempSelectedFilters),
          selectedGroupBy: state.tempSelectedGroupBy,
          selectedStartDateUnit: state.tempSelectedStartDateUnit,
          currentPage: 0,
        ),
      );
      add(const FetchPendingLeaves(page: 0, isPagination: true));
    });

    // Reset all filters, grouping and temp states
    on<ClearAllPendingFiltersAndGroupBy>((event, emit) {
      emit(
        state.copyWith(
          selectedFilters: const [],
          selectedGroupBy: '',
          selectedStartDateUnit: 'day',
          tempSelectedFilters: const [],
          tempSelectedGroupBy: '',
          tempSelectedStartDateUnit: 'day',
          currentPage: 0,
        ),
      );
      add(const FetchPendingLeaves(page: 0, isPagination: true));
    });
  }

  /// Initializes the bloc: sets up service client and loads first page
  Future<void> _onInitialize(
    InitializePendingLeave event,
    Emitter<PendingLeaveState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));
    await _service.initializeClient();
    add(const FetchPendingLeaves(page: 0));
  }

  /// Core fetch handler: loads pending leaves with current filters/search/grouping
  Future<void> _onFetchLeaves(
    FetchPendingLeaves event,
    Emitter<PendingLeaveState> emit,
  ) async {
    emit(state.copyWith(isPageLoading: event.isPagination));

    final firstApproval = state.selectedFilters.contains("first_Approval");
    final secondApproval = state.selectedFilters.contains("second_Approval");

    final leaves = await _service.loadPendingLeaves(
      event.page,
      state.itemsPerPage,
      searchQuery: state.searchQuery.isEmpty ? null : state.searchQuery,
      firstApproval: firstApproval,
      secondApproval: secondApproval,
    );

    final totalCount = await _service.pendingLeaveCount(
      searchQuery: state.searchQuery.isEmpty ? null : state.searchQuery,
      firstApproval: firstApproval,
      secondApproval: secondApproval,
    );

    List<Map<String, dynamic>> grouped = [];
    Map<String, bool> newExpanded = {};

    if (state.selectedGroupBy.isNotEmpty) {
      grouped = _groupLeaves(
        leaves,
        state.selectedGroupBy,
        state.selectedStartDateUnit,
      );

      for (var g in grouped) {
        newExpanded[g["group"] as String] = true;
      }
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

  /// Updates search query and triggers refresh from page 0
  void _onUpdateSearchQuery(
    UpdatePendingSearchQuery e,
    Emitter<PendingLeaveState> emit,
  ) {
    emit(state.copyWith(searchQuery: e.query));
    add(const FetchPendingLeaves(page: 0));
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
        String? dateStr = data["request_date_from"] is String
            ? data["request_date_from"]
            : (data["request_date_from"] is List &&
                      data["request_date_from"].length > 1
                  ? data["request_date_from"][1]
                  : null);

        String dateKey = "No Date";
        if (dateStr != null && dateStr.isNotEmpty) {
          final date = DateTime.parse(dateStr);
          switch (unit) {
            case "year":
              dateKey = "${date.year}";
              break;
            case "quarter":
              final q = ((date.month - 1) ~/ 3) + 1;
              dateKey = "Q$q ${date.year}";
              break;
            case "month":
              dateKey = "${date.month}-${date.year}";
              break;
            case "week":
              final w =
                  ((date.day +
                          DateTime(date.year, date.month, 1).weekday -
                          1) ~/
                      7) +
                  1;
              dateKey = "Week $w ${date.year}";
              break;
            default:
              dateKey = "${date.day}-${date.month}-${date.year}";
          }
        }
        key = dateKey;
      }

      grouped.putIfAbsent(key, () => []).add(data);
    }

    return grouped.entries
        .map((e) => {"group": e.key, "leave": e.value})
        .toList();
  }

  /// Maps internal Odoo leave state to user-friendly display label
  String _mapStatusLabel(String state) {
    switch (state) {
      case "confirm":
        return "To Approve";
      case "validate1":
        return "Second Approval";
      case "validate":
        return "Approved";
      default:
        return "Unknown";
    }
  }

  // ---------------------------------------------------------------------------
  //  Leave Action Handlers
  // ---------------------------------------------------------------------------

  /// Approves a pending leave request (first approval stage)
  Future<void> _onApproveLeave(
    ApproveLeave event,
    Emitter<PendingLeaveState> emit,
  ) async {
    emit(
      state.copyWith(
        leaveLoading: {...state.leaveLoading, event.leaveId: true},
        errorMessage: null,
      ),
    );

    final errorMessage = await _service.approveLeave(event.leaveId);

    emit(
      state.copyWith(
        leaveLoading: {...state.leaveLoading, event.leaveId: false},
        errorMessage: errorMessage,
      ),
    );
    emit(ShowRatingDialog());

    if (errorMessage == null) {
      add(const FetchPendingLeaves(page: 0));
    }
  }

  /// Validates a leave (second/final approval stage)
  Future<void> _onValidateLeave(
    ValidateLeave event,
    Emitter<PendingLeaveState> emit,
  ) async {
    emit(
      state.copyWith(
        leaveLoading: {...state.leaveLoading, event.leaveId: true},
        errorMessage: null,
      ),
    );

    final errorMessage = await _service.validateLeave(event.leaveId);

    emit(
      state.copyWith(
        leaveLoading: {...state.leaveLoading, event.leaveId: false},
        errorMessage: errorMessage,
      ),
    );
    emit(ShowRatingDialog());

    if (errorMessage == null) {
      add(const FetchPendingLeaves(page: 0));
    }
  }

  /// Rejects a pending leave request
  Future<void> _onRejectLeave(
    RejectLeave event,
    Emitter<PendingLeaveState> emit,
  ) async {
    emit(
      state.copyWith(
        leaveLoading: {...state.leaveLoading, event.leaveId: true},
        errorMessage: null,
      ),
    );

    final errorMessage = await _service.rejectLeave(event.leaveId);

    emit(
      state.copyWith(
        leaveLoading: {...state.leaveLoading, event.leaveId: false},
        errorMessage: errorMessage,
      ),
    );
    emit(ShowRatingDialog());

    if (errorMessage == null) {
      add(const FetchPendingLeaves(page: 0));
    }
  }
}
