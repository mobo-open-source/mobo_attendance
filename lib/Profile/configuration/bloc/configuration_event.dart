import 'package:equatable/equatable.dart';

/// Base class for all events dispatched to [ConfigurationBloc].
///
/// All events extend this abstract class and use `Equatable` for value-based
/// equality comparison. This prevents unnecessary state rebuilds when identical
/// events are dispatched (e.g., duplicate `LoadProfileEvent`).
abstract class ConfigurationEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

/// Triggers loading (or reloading) of the current user's profile data.
///
/// Dispatched:
/// - On first build of ConfigurationView
/// - After returning from profile edit
/// - On explicit refresh (e.g. pull-to-refresh or button)
///
/// Results in fetching profile info (name, email, image, etc.) via `ProfileService`
class LoadProfileEvent extends ConfigurationEvent {}

/// Requests switching to a different saved user account.
///
/// Carries the full account map (from secure storage) containing:
/// - sessionId, userId, userName, userLogin, serverVersion, etc.
///
/// On success, updates session, shared preferences, clears cache, and triggers
/// full app reload via UI listener.
class SwitchAccountEvent extends ConfigurationEvent {
  final Map<String, dynamic> user;

  SwitchAccountEvent(this.user);

  @override
  List<Object?> get props => [user];
}

/// Alias/shortcut event that simply dispatches `LoadProfileEvent`.
///
/// Used when the UI wants to refresh profile without creating a new event instance.
class RefreshProfileEvent extends ConfigurationEvent {}
