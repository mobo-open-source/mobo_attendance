/// Defines all login related events used in LoginBloc.
///
/// These events are triggered by user actions like:
/// - Changing protocol
/// - Entering URL
/// - Selecting database
/// - Fetching database list
/// - Moving to next step in login flow
part of 'login_bloc.dart';

/// Base class for all login events.
///
/// Uses Equatable for value comparison.
abstract class LoginEvent extends Equatable {
  const LoginEvent();
  @override
  List<Object?> get props => [];
}

/// Triggered when user changes protocol (HTTP / HTTPS).
class ProtocolChanged extends LoginEvent {
  final String protocol;
  const ProtocolChanged(this.protocol);
  @override
  List<Object?> get props => [protocol];
}

/// Triggered when user changes or types server URL.
class UrlChanged extends LoginEvent {
  final String url;
  const UrlChanged(this.url);
  @override
  List<Object?> get props => [url];
}

/// Triggered when user selects a database from list.
class DatabaseSelected extends LoginEvent {
  final String database;
  const DatabaseSelected(this.database);
  @override
  List<Object?> get props => [database];
}

/// Triggered to fetch database list from server using full URL.
class FetchDatabases extends LoginEvent {
  final String fullUrl;
  const FetchDatabases(this.fullUrl);
  @override
  List<Object?> get props => [fullUrl];
}

/// Triggered when user presses Next button in login flow.
class NextPressed extends LoginEvent {}