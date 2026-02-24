part of 'pending_leave_bloc.dart';

/// Base class for all events dispatched to [PendingLeaveBloc].
///
/// All events extend this abstract class to ensure proper equality comparison
/// via [Equatable], which helps prevent unnecessary state emissions when
/// identical events are dispatched.
abstract class PendingLeaveEvent extends Equatable {
  const PendingLeaveEvent();

  @override
  List<Object?> get props => [];
}

/// Triggered when the Pending Leaves screen is first opened.
///
/// Usually dispatched in `initState()` or on navigation to initialize
/// the Odoo RPC client and load the first page of pending leave requests.
class InitializePendingLeave extends PendingLeaveEvent {}

/// Main event to fetch pending leave requests (initial load or pagination).
///
/// - `page == 0`: full refresh (after filter/search/group change)
/// - `isPagination == true`: append next page without resetting UI
class FetchPendingLeaves extends PendingLeaveEvent {
  final int page;
  final bool isPagination;

  const FetchPendingLeaves({required this.page, this.isPagination = false});

  @override
  List<Object?> get props => [page, isPagination];
}

/// Event emitted when the user types in the search field.
///
/// Triggers a refresh (usually from page 0) with the updated search term.
class UpdatePendingSearchQuery extends PendingLeaveEvent {
  final String query;

  const UpdatePendingSearchQuery(this.query);

  @override
  List<Object?> get props => [query];
}

/// Event sent when the user changes approval stage filters.
///
/// Typically triggered by toggling filter chips in the bottom sheet.
class UpdatePendingFilters extends PendingLeaveEvent {
  final List<String> filters;

  const UpdatePendingFilters(this.filters);

  @override
  List<Object?> get props => [filters];
}

/// Event to change grouping criteria for pending leaves.
///
/// Supported values for `groupBy`:
/// - `null` or empty → no grouping
/// - `"type"` → group by leave type
/// - `"status"` → group by approval state
/// - `"start_date"` → group by start date (with `startDateUnit`)
class UpdatePendingGroupBy extends PendingLeaveEvent {
  final String? groupBy;
  final String? startDateUnit;

  const UpdatePendingGroupBy({this.groupBy, this.startDateUnit});

  @override
  List<Object?> get props => [groupBy, startDateUnit];
}

/// Event to reset all filters, search, and grouping settings to defaults.
class ClearAllPendingFiltersAndGroupBy extends PendingLeaveEvent {}

/// Event triggered when a manager approves a pending leave request
/// (first approval stage).
class ApproveLeave extends PendingLeaveEvent {
  final int leaveId;

  const ApproveLeave(this.leaveId);

  @override
  List<Object?> get props => [leaveId];
}

/// Event triggered when a manager validates/fully approves a leave
/// (second/final approval stage).
class ValidateLeave extends PendingLeaveEvent {
  final int leaveId;

  const ValidateLeave(this.leaveId);

  @override
  List<Object?> get props => [leaveId];
}

/// Event triggered when a manager rejects a pending leave request.
class RejectLeave extends PendingLeaveEvent {
  final int leaveId;

  const RejectLeave(this.leaveId);

  @override
  List<Object?> get props => [leaveId];
}

/// Initializes temporary filter/group state when opening the filter bottom sheet.
///
/// Used to allow preview/cancel without immediately applying changes.
class InitializeTempFilters extends PendingLeaveEvent {
  final List<String> filters;
  final String groupBy;
  final String startDateUnit;

  const InitializeTempFilters({
    required this.filters,
    required this.groupBy,
    required this.startDateUnit,
  });

  @override
  List<Object?> get props => [filters, groupBy, startDateUnit];
}

/// Updates temporary filter selection (preview mode in bottom sheet).
class UpdateTempFilters extends PendingLeaveEvent {
  final List<String> filters;
  const UpdateTempFilters(this.filters);
  @override
  List<Object?> get props => [filters];
}

/// Updates temporary grouping selection (preview mode in bottom sheet).
class UpdateTempGroupBy extends PendingLeaveEvent {
  final String groupBy;
  final String? startDateUnit;
  const UpdateTempGroupBy({required this.groupBy, this.startDateUnit});
  @override
  List<Object?> get props => [groupBy, startDateUnit];
}

/// Applies the temporary (preview) filters and grouping to the active state
/// and triggers a data refresh from page 0.
class ApplyFiltersAndGroupBy extends PendingLeaveEvent {}