import 'package:equatable/equatable.dart';

import '../../profile/models/profile.dart';

/// Enum representing the current status of an account switch operation.
enum SwitchStatus { idle, switching, completed, failed }

/// Immutable state class for [ConfigurationBloc].
///
/// Holds:
/// - Loading state during profile fetch
/// - List of loaded user profiles (usually 1, but supports multi-account view)
/// - Any error message from profile loading or account switching
/// - Current status of account switching process
///
/// Uses `Equatable` for value-based comparison → prevents unnecessary rebuilds
/// when only transient fields (like `isLoading`) change.
class ConfigurationState extends Equatable {
  final bool isLoading;
  final List<Profile> profiles;
  final String? error;
  final SwitchStatus switchStatus;

  const ConfigurationState({
    this.isLoading = false,
    this.switchStatus = SwitchStatus.idle,
    this.profiles = const [],
    this.error,
  });

  /// Creates a new state instance with updated values.
  ///
  /// All parameters are optional — unspecified fields keep their current value.
  /// Used in event handlers for immutable state updates.
  ConfigurationState copyWith({
    bool? isLoading,
    SwitchStatus? switchStatus,
    List<Profile>? profiles,
    String? error,
  }) {
    return ConfigurationState(
      isLoading: isLoading ?? this.isLoading,
      profiles: profiles ?? this.profiles,
      switchStatus: switchStatus ?? this.switchStatus,
      error: error,
    );
  }

  /// Equatable props — used to determine when state has meaningfully changed
  ///
  /// Includes all fields that should trigger rebuilds when changed.
  @override
  List<Object?> get props => [isLoading, profiles, error,switchStatus];
}
