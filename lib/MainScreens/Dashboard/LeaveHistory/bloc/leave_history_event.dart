part of 'leave_history_bloc.dart';

/// Base class for all events in the [LeaveHistoryBloc].
///
/// All events extend this class to ensure proper equality comparison
/// via [Equatable], which helps prevent unnecessary state rebuilds.
abstract class LeaveHistoryEvent extends Equatable {
  const LeaveHistoryEvent();

  @override
  List<Object?> get props => [];
}

/// Triggered when the Leave History screen is first opened.
///
/// Usually dispatched in `initState()` or when the page is navigated to.
/// It initializes the Odoo RPC client and starts the first data load.
class InitializeLeaveHistory extends LeaveHistoryEvent {}

/// Main event to fetch leave records (initial load or pagination).
///
/// - When `page == 0`: full refresh (usually after filter/search/group change)
/// - When `isPagination == true`: loading next page without full reset
class FetchLeaves extends LeaveHistoryEvent {
  final int page;
  final bool isPagination;

  const FetchLeaves({required this.page, this.isPagination = false});

  @override
  List<Object?> get props => [page, isPagination];
}

/// Event emitted when the user types in the search field.
///
/// Triggers a debounced or immediate refresh with the new search term.
class UpdateSearchQuery extends LeaveHistoryEvent {
  final String query;

  const UpdateSearchQuery(this.query);

  @override
  List<Object?> get props => [query];
}

/// Event sent when the user changes the status/approval filters.
///
/// Typically triggered by toggling chips or checkboxes
/// (e.g. "To Approve", "Approved", "Refused", "Cancelled").
class UpdateFilters extends LeaveHistoryEvent {
  final List<String> filters;

  const UpdateFilters(this.filters);

  @override
  List<Object?> get props => [filters];
}

/// Event to change how leave records are grouped in the UI.
///
/// Supported values for `groupBy`:
/// - `null` or empty → no grouping
/// - `"type"` → group by leave type (holiday_status_id)
/// - `"status"` → group by approval state
/// - `"start_date"` → group by start date (with `startDateUnit`)
class UpdateGroupBy extends LeaveHistoryEvent {
  final String? groupBy;
  final String? startDateUnit;

  const UpdateGroupBy({this.groupBy, this.startDateUnit});

  @override
  List<Object?> get props => [groupBy, startDateUnit];
}

/// Event to reset all filters, search query, and grouping settings.
///
/// Usually triggered by a "Clear All" button.
class ClearAllFiltersAndGroupBy extends LeaveHistoryEvent {}
