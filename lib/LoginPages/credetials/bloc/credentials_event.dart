part of 'credentials_bloc.dart';

/// Base class for all credential related events.
///
/// Uses Equatable to optimize Bloc state comparison
/// and prevent unnecessary UI rebuilds.
abstract class CredentialsEvent extends Equatable {
  const CredentialsEvent();
  @override
  List<Object?> get props => [];
}

/// Event triggered when user taps password visibility toggle.
///
/// Updates UI state to show or hide password text field value.
class TogglePasswordVisibility extends CredentialsEvent {}

/// Event triggered when user submits login form.
///
/// Contains all required login parameters:
/// • server protocol (http / https)
/// • server URL
/// • database name
/// • username
/// • password
/// • BuildContext (used for navigation like TOTP flow)
///
/// This event starts authentication process in CredentialsBloc.
class SubmitLogin extends CredentialsEvent {
  final BuildContext context;
  final String protocol;
  final String url;
  final String database;
  final String username;
  final String password;

  const SubmitLogin({
    required this.context,
    required this.protocol,
    required this.url,
    required this.database,
    required this.username,
    required this.password,
  });

  @override
  List<Object?> get props => [context, protocol, url, database, username, password];
}

/// Event used to clear existing error message from state.
///
/// Typically triggered when:
/// • User edits input fields
/// • User retries login
/// • UI needs to reset error state
class ClearErrorMessage extends CredentialsEvent {}