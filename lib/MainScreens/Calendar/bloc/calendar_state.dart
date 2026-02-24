import 'package:equatable/equatable.dart';

/// Base class for all states in the Calendar BLoC.
///
/// All calendar states extend this class to enable proper equality comparison
/// (via Equatable), which helps Flutter rebuild the UI only when actual data changes.
abstract class CalendarState extends Equatable {
  const CalendarState();

  @override
  List<Object?> get props => [];
}

/// Initial / idle state before any data has been requested or loaded.
class CalendarInitial extends CalendarState {}

/// Transient loading state shown while fetching attendance and schedule data.
class CalendarLoading extends CalendarState {}

/// Main success/error state containing calendar data or error flags.
///
/// This state is used for **both** successful loads and handled error cases.
/// When data is successfully loaded → `attendanceData` and `workSchedule` are populated.
/// When an error occurs → data is empty and one of the boolean flags is `true`.
///
/// Flags (mutually exclusive in practice):
///   - [catchError]           → generic failure (RPC error, parsing issue, etc.)
///   - [connectionError]      → network/server unreachable (SocketException)
///   - [isAppNotInstalled]    → required Odoo module (attendance/leave) not installed
class CalendarLoaded extends CalendarState {
  final List<Map<String, dynamic>> attendanceData;
  final Map<int, Map<String, String>> workSchedule;
  final bool catchError;
  final bool connectionError;
  final bool isAppNotInstalled;

  const CalendarLoaded({
    required this.attendanceData,
    required this.workSchedule,
    this.catchError = false,
    this.connectionError = false,
    this.isAppNotInstalled = false,
  });

  /// All fields included in equality check to prevent unnecessary rebuilds
  @override
  List<Object?> get props => [
    attendanceData,
    workSchedule,
    catchError,
    connectionError,
    isAppNotInstalled,
  ];
}

/// Dedicated error state for unhandled / critical failures.
///
/// Currently unused in the provided BLoC logic (which prefers `CalendarLoaded` with flags),
/// but kept for future expansion or cleaner separation of concerns.
class CalendarError extends CalendarState {
  final String message;

  const CalendarError(this.message);

  @override
  List<Object?> get props => [message];
}
