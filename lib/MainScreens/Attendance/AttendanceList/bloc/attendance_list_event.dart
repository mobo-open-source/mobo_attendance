part of 'attendance_list_bloc.dart';

/// Base class for all events related to the attendance list.
///
/// Extends [Equatable] to simplify comparison of event instances.
abstract class AttendanceListEvent extends Equatable {
  const AttendanceListEvent();

  @override
  List<Object?> get props => [];
}

/// Event to load attendance records from the service.
///
/// Supports pagination, filtering, searching, and grouping.
///
/// Parameters:
/// - [page]: The page number to fetch (for pagination).
/// - [searchText]: Optional search string to filter attendance.
/// - [selectedFilters]: List of applied filter names (e.g., 'my_attendance', 'errors').
/// - [selectedGroupBy]: Optional field to group results by (e.g., department).
/// - [selectedCheckInUnit]: Optional unit for check-in filtering.
/// - [selectedCheckOutUnit]: Optional unit for check-out filtering.
/// - [myAttendance], [myTeam], [atWork], [errors], [last7days]: Optional boolean flags derived from filters.
class LoadAttendance extends AttendanceListEvent {
  final int page;
  final String? searchText;
  final List<String> selectedFilters;
  final String? selectedGroupBy;
  final String? selectedCheckInUnit;
  final String? selectedCheckOutUnit;
  final bool? myAttendance;
  final bool? myTeam;
  final bool? atWork;
  final bool? errors;
  final bool? last7days;

  const LoadAttendance({
    required this.page,
    this.searchText,
    this.selectedFilters = const [],
    this.selectedGroupBy,
    this.selectedCheckInUnit,
    this.selectedCheckOutUnit,
    this.myAttendance,
    this.myTeam,
    this.atWork,
    this.errors,
    this.last7days,
  });

  @override
  List<Object?> get props => [
    page,
    searchText,
    selectedFilters,
    selectedGroupBy,
    selectedCheckInUnit,
    selectedCheckOutUnit,
    myAttendance,
    myTeam,
    atWork,
    errors,
    last7days,
  ];
}

/// Event to apply filters to the attendance list.
///
/// Triggers a reload of attendance data with the selected filters.
///
/// Parameters:
/// - [selectedFilters]: List of filter names to apply.
/// - [selectedGroupBy]: Optional grouping field.
/// - [selectedCheckInUnit]: Optional unit for check-in filtering.
/// - [selectedCheckOutUnit]: Optional unit for check-out filtering.
/// - [searchText]: Optional search text to filter results.
class ApplyFilters extends AttendanceListEvent {
  final List<String> selectedFilters;
  final String? selectedGroupBy;
  final String? selectedCheckInUnit;
  final String? selectedCheckOutUnit;
  final String searchText;

  const ApplyFilters({
    required this.selectedFilters,
    this.selectedGroupBy,
    this.selectedCheckInUnit,
    this.selectedCheckOutUnit,
    this.searchText = '',
  });

  @override
  List<Object?> get props => [
    selectedFilters,
    selectedGroupBy,
    selectedCheckInUnit,
    selectedCheckOutUnit,
    searchText,
  ];
}

/// Event to clear all filters and reset the attendance list.
class ClearFilters extends AttendanceListEvent {
  const ClearFilters();
}

/// Event to search attendance records using a search string and current filters.
///
/// Parameters:
/// - [searchText]: The text to search in attendance records.
/// - [selectedFilters]: The current list of applied filters.
/// - [selectedGroupBy]: Optional grouping field.
/// - [selectedCheckInUnit]: Optional unit for check-in filtering.
/// - [selectedCheckOutUnit]: Optional unit for check-out filtering.
class SearchAttendance extends AttendanceListEvent {
  final String searchText;
  final List<String> selectedFilters;
  final String? selectedGroupBy;
  final String? selectedCheckInUnit;
  final String? selectedCheckOutUnit;

  const SearchAttendance({
    required this.searchText,
    required this.selectedFilters,
    this.selectedGroupBy,
    this.selectedCheckInUnit,
    this.selectedCheckOutUnit,
  });

  @override
  List<Object?> get props => [
    searchText,
    selectedFilters,
    selectedGroupBy,
    selectedCheckInUnit,
    selectedCheckOutUnit,
  ];
}

/// Event to delete a specific attendance record.
///
/// Parameters:
/// - [id]: The ID of the attendance record to delete.
class DeleteAttendance extends AttendanceListEvent {
  final int id;

  const DeleteAttendance(this.id);

  @override
  List<Object?> get props => [id];
}

/// Event to toggle the expansion state of a group in the attendance list.
///
/// Parameters:
/// - [groupName]: The name of the group to expand or collapse.
class ToggleGroupExpansion extends AttendanceListEvent {
  final String groupName;

  const ToggleGroupExpansion(this.groupName);

  @override
  List<Object?> get props => [groupName];
}