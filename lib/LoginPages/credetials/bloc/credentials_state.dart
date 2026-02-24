part of 'credentials_bloc.dart';

/// Represents UI state for login and authentication flow.
///
/// Holds loading status, error messages, password visibility,
/// biometric status, login success flag, and active session data.
class CredentialsState extends Equatable {
  final bool isLoading;
  final String? errorMessage;
  final bool isPasswordVisible;
  final bool biometricEnabled;
  final bool loginSuccess;
  final SessionModel? session;

  const CredentialsState({
    this.isLoading = false,
    this.errorMessage,
    this.isPasswordVisible = false,
    this.biometricEnabled = false,
    this.loginSuccess = false,
    this.session,
  });

  /// Returns default initial state for credentials.
  ///
  /// Used when Bloc is first created or reset.
  factory CredentialsState.initial() => const CredentialsState();

  /// Creates a new state instance with updated values.
  ///
  /// Helps maintain immutability while updating specific fields.
  CredentialsState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool? isPasswordVisible,
    bool? biometricEnabled,
    bool? loginSuccess,
    SessionModel? session,
  }) {
    return CredentialsState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      isPasswordVisible: isPasswordVisible ?? this.isPasswordVisible,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      loginSuccess: loginSuccess ?? this.loginSuccess,
      session: session ?? this.session,
    );
  }

  @override
  List<Object?> get props => [isLoading, errorMessage, isPasswordVisible, biometricEnabled, loginSuccess, session];
}