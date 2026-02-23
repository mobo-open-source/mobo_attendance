/// Represents authentication result status.
enum AuthenticationResult {
  success,
  failure,
  error,
  unavailable,
}

/// Stores authentication state and result.
///
/// Used to track:
/// - Login status
/// - Whether local authentication (biometric / PIN) is enabled
/// - Result of last authentication attempt
class AuthModel {
  final bool isLoggedIn;
  final bool useLocalAuth;
  final AuthenticationResult? authResult;

  /// Creates AuthModel with default values.
  AuthModel({
    this.isLoggedIn = false,
    this.useLocalAuth = false,
    this.authResult,
  });

  /// Creates a new AuthModel with updated values.
  ///
  /// Only provided values will be replaced.
  AuthModel copyWith({
    bool? isLoggedIn,
    bool? useLocalAuth,
    AuthenticationResult? authResult,
  }) {
    return AuthModel(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      useLocalAuth: useLocalAuth ?? this.useLocalAuth,
      authResult: authResult ?? this.authResult,
    );
  }
}