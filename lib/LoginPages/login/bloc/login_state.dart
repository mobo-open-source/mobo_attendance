/// Represents the current state of LoginBloc.
///
/// Stores:
/// - Selected protocol
/// - Server URL
/// - Available database list
/// - Selected database
/// - Loading status
/// - Error messages
/// - URL suggestions and history
/// - Manual database input visibility
part of 'login_bloc.dart';

/// Holds login screen state data.
///
/// Uses Equatable for state comparison in BLoC.
class LoginState extends Equatable {
  final String protocol;
  final String url;
  final List<String> databases;
  final String? selectedDatabase;
  final bool isLoading;
  final String? errorMessage;
  final List<String> urlSuggestions;
  final Map<String, Map<String, String>> urlHistory;
  final bool showManualDbInput;

  /// Creates LoginState with default values.
  const LoginState({
    this.protocol = 'https://',
    this.url = '',
    this.databases = const [],
    this.selectedDatabase,
    this.isLoading = false,
    this.errorMessage,
    this.urlSuggestions = const [],
    this.urlHistory = const {},
    this.showManualDbInput = false,
  });

  /// Creates a new LoginState by updating only provided values.
  LoginState copyWith({
    String? protocol,
    String? url,
    List<String>? databases,
    String? selectedDatabase,
    bool? isLoading,
    String? errorMessage,
    List<String>? urlSuggestions,
    Map<String, Map<String, String>>? urlHistory,
    bool? showManualDbInput,
  }) {
    return LoginState(
      protocol: protocol ?? this.protocol,
      url: url ?? this.url,
      databases: databases ?? this.databases,
      selectedDatabase: selectedDatabase ?? this.selectedDatabase,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
      urlSuggestions: urlSuggestions ?? this.urlSuggestions,
      urlHistory: urlHistory ?? this.urlHistory,
      showManualDbInput: showManualDbInput ?? this.showManualDbInput,
    );
  }

  /// Used by Equatable to compare state changes.
  @override
  List<Object?> get props => [
    protocol,
    url,
    databases,
    selectedDatabase,
    isLoading,
    errorMessage,
    urlSuggestions,
    urlHistory,
    showManualDbInput
  ];
}