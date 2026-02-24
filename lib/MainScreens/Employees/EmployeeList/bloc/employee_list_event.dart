part of 'employee_list_bloc.dart';

/// Base class for all events dispatched to [EmployeeListBloc].
///
/// All events extend this abstract class to ensure proper value-based equality
/// comparison (via Equatable or similar in the bloc implementation), which helps
/// prevent unnecessary state rebuilds when identical events are dispatched.
abstract class EmployeeListEvent {}

/// Initializes the employee list screen (usually on first build or company refresh).
///
/// Triggers permission check (can see images?) and initial data fetch.
/// Can be silent (no loading indicator) when refreshing in background.
class InitializeEmployeeList extends EmployeeListEvent {
  final List<int>? preAppliedEmployeeIds;
  final String? preAppliedFilterName;
  final bool? preApplied;
  final bool silent;

  InitializeEmployeeList({
    this.preAppliedEmployeeIds,
    this.preAppliedFilterName,
    this.preApplied,
    this.silent = false
  });
}

/// Fetches a page of employees (or refreshes current page).
///
/// Main fetch event — supports pagination, search, and filter application.
class FetchEmployees extends EmployeeListEvent {
  final int page;
  final String searchQuery;
  final bool isUserPagination;

  FetchEmployees({
    required this.page,
    this.searchQuery = '',
    this.isUserPagination = false,
  });
}

/// Applies new filters and/or grouping, then triggers a full refresh from page 0.
class ApplyFiltersAndGroupBy extends EmployeeListEvent {
  final List<String> filters;
  final String?
  groupBy;
  final String? startDateUnit;

  ApplyFiltersAndGroupBy({
    required this.filters,
    this.groupBy,
    this.startDateUnit,
  });
}

/// Clears all filters, grouping, and start-date unit — resets to default view.
class ClearFilters extends EmployeeListEvent {}

/// Reloads the entire list from scratch (clears filters, search, grouping).
///
/// Usually triggered after returning from create/edit or company refresh.
class ReloadEmployeeList extends EmployeeListEvent {}

/// Toggles expanded/collapsed state of one group in grouped view.
class ToggleGroupExpanded extends EmployeeListEvent {
  final String groupName;

  ToggleGroupExpanded(this.groupName);
}

/// Archives (deactivates) the selected employee.
class ArchiveEmployee extends EmployeeListEvent {
  final int employeeId;

  ArchiveEmployee(this.employeeId);
}

/// Permanently deletes the selected employee.
class DeleteEmployee extends EmployeeListEvent {
  final int employeeId;

  DeleteEmployee(this.employeeId);
}
