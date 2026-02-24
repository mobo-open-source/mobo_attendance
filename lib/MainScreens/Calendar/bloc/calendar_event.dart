import 'package:equatable/equatable.dart';

/// Base class for all events in the Calendar BLoC.
///
/// All calendar-related events must extend this class to ensure proper
/// equality comparison (via Equatable) which helps prevent unnecessary
/// state rebuilds in the BLoC pattern.
abstract class CalendarEvent extends Equatable {
  const CalendarEvent();

  @override
  List<Object> get props => [];
}

/// Event triggered when the calendar needs to load or reload data for a specific month/year.
///
/// This is the primary (and currently only) event used by the CalendarBloc.
/// It carries the target month (as string "1"–"12") and year.
///
/// Usage examples:
///   - Initial load: LoadCalendarData(month: "4", year: 2025)
///   - Month change: LoadCalendarData(month: "5", year: 2025)
///   - Refresh after company/session change
class LoadCalendarData extends CalendarEvent {
  final String month;
  final int year;

  const LoadCalendarData({required this.month, required this.year});

  @override
  List<Object> get props => [month, year];
}
