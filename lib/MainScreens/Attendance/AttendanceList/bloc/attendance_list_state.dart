part of 'attendance_list_bloc.dart';

/// Base class for all states of the attendance list.
///
/// Extends [Equatable] for value comparison of state instances.
abstract class AttendanceListState extends Equatable {
  const AttendanceListState();

  @override
  List<Object?> get props => [];
}

/// State representing the initial state of the attendance list.
class AttendanceInitial extends AttendanceListState {}

/// State representing that attendance data is currently being loaded.
class AttendanceLoading extends AttendanceListState {}

/// State representing that attendance data has been successfully loaded.
///
/// Contains pagination information, applied filters, search text, and
/// group expansion states.
///
/// Parameters:
/// - [attendance]: The list of attendance records as maps.
/// - [totalCount]: Total number of attendance records available.
/// - [currentPage]: Current page number for pagination.
/// - [selectedFilters]: List of applied filter names.
/// - [selectedGroupBy]: Optional grouping field.
/// - [selectedCheckInUnit]: Optional check-in unit filter.
/// - [selectedCheckOutUnit]: Optional check-out unit filter.
/// - [searchText]: Current search string.
/// - [groupExpanded]: Map of group names to their expansion state.
/// - [errorMessage]: Optional error message if a specific operation failed.
/// - [isPaging]: True if additional pages are being loaded.
/// - [catchError]: True if an error occurred during data fetch.
/// - [accessForAction]: True if the current user has permission to perform actions.
/// - [connectionError]: True if a network error occurred.
class AttendanceLoaded extends AttendanceListState {
  final List<Map<String, dynamic>> attendance;
  final int totalCount;
  final int currentPage;
  final List<String> selectedFilters;
  final String? selectedGroupBy;
  final String? selectedCheckInUnit;
  final String? selectedCheckOutUnit;
  final String searchText;
  final Map<String, bool> groupExpanded;
  final String? errorMessage;
  final bool isPaging;
  final bool catchError;
  final bool accessForAction;
  final bool connectionError;

  const AttendanceLoaded({
    required this.attendance,
    required this.totalCount,
    required this.currentPage,
    this.selectedFilters = const [],
    this.selectedGroupBy,
    this.selectedCheckInUnit,
    this.selectedCheckOutUnit,
    this.searchText = '',
    this.groupExpanded = const {},
    this.errorMessage,
    this.isPaging = false,
    this.catchError = false,
    this.accessForAction = false,
    this.connectionError = false,
  });

  /// Returns the total number of displayed attendance records across all loaded pages.
  int get displayedCount => attendance.length + (currentPage * 40);

  /// Returns a string showing the range of records currently displayed, e.g., "41-80".
  String get pageRange {
    if (totalCount == 0) return '0-0';
    final start = currentPage * 40 + 1;
    final end = (start + attendance.length - 1).clamp(start, totalCount);
    return '$start-$end';
  }

  /// Returns a copy of the current state with updated fields.
  ///
  /// Useful for partial updates while keeping the rest of the state intact.
  AttendanceLoaded copyWith({
    List<Map<String, dynamic>>? attendance,
    int? totalCount,
    int? currentPage,
    List<String>? selectedFilters,
    String? selectedGroupBy,
    String? selectedCheckInUnit,
    String? selectedCheckOutUnit,
    String? searchText,
    Map<String, bool>? groupExpanded,
    String? errorMessage,
    bool? isPaging,
    bool? catchError,
    bool? accessForAction,
    bool? connectionError,
  }) {
    return AttendanceLoaded(
      attendance: attendance ?? this.attendance,
      totalCount: totalCount ?? this.totalCount,
      currentPage: currentPage ?? this.currentPage,
      selectedFilters: selectedFilters ?? this.selectedFilters,
      selectedGroupBy: selectedGroupBy ?? this.selectedGroupBy,
      selectedCheckInUnit: selectedCheckInUnit ?? this.selectedCheckInUnit,
      selectedCheckOutUnit: selectedCheckOutUnit ?? this.selectedCheckOutUnit,
      searchText: searchText ?? this.searchText,
      groupExpanded: groupExpanded ?? this.groupExpanded,
      errorMessage: errorMessage,
      isPaging: isPaging ?? this.isPaging,
      catchError: catchError ?? this.catchError,
      accessForAction: accessForAction ?? this.accessForAction,
      connectionError: connectionError ?? this.connectionError,
    );
  }

  @override
  List<Object?> get props => [
    attendance,
    totalCount,
    currentPage,
    selectedFilters,
    selectedGroupBy,
    selectedCheckInUnit,
    selectedCheckOutUnit,
    searchText,
    groupExpanded,
    errorMessage,
    isPaging,
    catchError,
    accessForAction,
    connectionError,
  ];
}

/// State representing that an attendance record was successfully deleted.
class AttendanceDeletedSuccess extends AttendanceListState {}

/// State representing a generic error in the attendance list.
///
/// Parameters:
/// - [message]: The error message to display.
class AttendanceError extends AttendanceListState {
  final String message;

  const AttendanceError(this.message);

  @override
  List<Object> get props => [message];
}
