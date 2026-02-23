import 'package:equatable/equatable.dart';

/// Base class for all events dispatched to [ReportBloc].
///
/// All events extend this abstract class to ensure proper value-based equality
/// comparison via [Equatable], which helps prevent unnecessary state rebuilds
/// when identical events are dispatched.
abstract class ReportEvent extends Equatable {
  const ReportEvent();

  @override
  List<Object?> get props => [];
}

/// Triggered when the Reports screen is first opened or initialized.
///
/// Usually dispatched in `initState()` or on navigation to the page.
/// It starts the initial data load for the attendance graph/report.
class InitializeReport extends ReportEvent {}

/// Main event to load paginated graph/report data.
///
/// Dispatched on initial load, after filter/search/measure/view changes,
/// or when loading the next page.
class LoadGraphData extends ReportEvent {
  final int page;

  const LoadGraphData({required this.page});

  @override
  List<Object> get props => [page];
}

/// Event emitted when the user types in the search field.
///
/// Triggers a data refresh (usually from page 0) with the updated search term.
class UpdateSearchText extends ReportEvent {
  final String text;

  const UpdateSearchText(this.text);

  @override
  List<Object> get props => [text];
}

/// Event sent when the user changes or applies report filters.
///
/// Typically triggered by toggling filter chips or selecting options
/// in a filter bottom sheet.
class UpdateFilters extends ReportEvent {
  final List<String> filters;

  const UpdateFilters(this.filters);

  @override
  List<Object> get props => [filters];
}

/// Event to change the grouping criteria for the attendance data visualization.
///
/// Supported values for `groupBy`:
/// - `"check_in"`  → group by check-in date/time
/// - `"check_out"` → group by check-out date/time
///
/// When grouping by date, `unit` specifies the time granularity.
class UpdateGroupBy extends ReportEvent {
  final String groupBy;
  final String? unit;

  const UpdateGroupBy({required this.groupBy, this.unit});

  @override
  List<Object?> get props => [groupBy, unit];
}

/// Event to reset all filters, search text, grouping, and reload data from page 0.
///
/// Usually triggered by a "Clear All" or "Reset Filters" button.
class ClearAllFiltersAndGroupBy extends ReportEvent {}

/// Event to change the metric/measure displayed in the report graph.
///
/// Examples: `"count"`, `"total_hours"`, `"average_hours"`, `"late_count"`, etc.
class UpdateMeasure extends ReportEvent {
  final String measure;

  const UpdateMeasure(this.measure);

  @override
  List<Object> get props => [measure];
}

/// Event to switch the visualization mode or view type.
///
/// Examples: `"bar_chart"` and `"line_chart"`.
class UpdateView extends ReportEvent {
  final String view;

  const UpdateView(this.view);

  @override
  List<Object> get props => [view];
}
