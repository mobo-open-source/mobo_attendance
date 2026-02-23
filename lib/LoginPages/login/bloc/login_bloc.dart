import 'dart:async';
import 'dart:convert';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/network_service.dart';

part 'login_event.dart';

part 'login_state.dart';

/// Handles login related logic such as:
/// - Protocol selection (HTTP / HTTPS)
/// - URL input handling
/// - Fetching database list from server
/// - Database selection
/// - URL history suggestions
/// - Error handling
class LoginBloc extends Bloc<LoginEvent, LoginState> {
  late NetworkService _networkService;
  Timer? _debounce;

  /// Creates LoginBloc and initializes network service and URL history.
  LoginBloc({NetworkService? service})
    : _networkService = service ?? NetworkService(),
      super(const LoginState()) {
    on<ProtocolChanged>(_onProtocolChanged);
    on<UrlChanged>(_onUrlChanged);
    on<DatabaseSelected>(_onDatabaseSelected);
    on<FetchDatabases>(_onFetchDatabases);

    _loadUrlHistory();
  }

  /// Updates protocol and reloads URL history.
  /// If URL exists, automatically fetches databases.
  void _onProtocolChanged(
    ProtocolChanged event,
    Emitter<LoginState> emit,
  ) async {
    emit(
      state.copyWith(
        protocol: event.protocol,
        databases: [],
        selectedDatabase: null,
        errorMessage: "",
      ),
    );
    await _loadUrlHistoryForProtocol(event.protocol);

    if (state.url.isNotEmpty) {
      String inputUrl = state.url.trim();
      String protocolToUse = event.protocol;

      if (inputUrl.startsWith('http://')) {
        protocolToUse = 'http://';
        inputUrl = inputUrl.replaceFirst('http://', '');
      } else if (inputUrl.startsWith('https://')) {
        protocolToUse = 'https://';
        inputUrl = inputUrl.replaceFirst('https://', '');
      }

      final fullUrl = '$protocolToUse$inputUrl';
      add(FetchDatabases(fullUrl));
    }
  }

  /// Handles URL input changes with debounce.
  /// Detects protocol from URL and fetches databases after delay.
  void _onUrlChanged(UrlChanged event, Emitter<LoginState> emit) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    String input = event.url.trim();
    String detectedProtocol = state.protocol;

    if (input.startsWith('http://')) {
      detectedProtocol = 'http://';
      input = input.replaceFirst('http://', '');
    } else if (input.startsWith('https://')) {
      detectedProtocol = 'https://';
      input = input.replaceFirst('https://', '');
    }

    emit(
      state.copyWith(
        protocol: detectedProtocol,
        url: input,
        isLoading: input.isNotEmpty,
        databases: [],
        selectedDatabase: null,
        errorMessage: "",
      ),
    );

    _debounce = Timer(const Duration(milliseconds: 800), () {
      add(FetchDatabases('$detectedProtocol$input'));
    });
  }

  /// Updates selected database.
  void _onDatabaseSelected(DatabaseSelected event, Emitter<LoginState> emit) {
    emit(state.copyWith(selectedDatabase: event.database, errorMessage: ""));
  }

  /// Fetches database list from server.
  /// Tries both HTTP and HTTPS if needed.
  /// Updates database list, manual input option, or error message.
  Future<void> _onFetchDatabases(
    FetchDatabases event,
    Emitter<LoginState> emit,
  ) async {
    emit(
      state.copyWith(
        isLoading: true,
        errorMessage: "",
        databases: [],
        selectedDatabase: null,
        showManualDbInput: false,
      ),
    );

    String rawUrl = event.fullUrl.trim();
    final match = RegExp(
      r'^(https?://)',
      caseSensitive: false,
    ).firstMatch(rawUrl);

    List<String> protocolsToTry = [];
    String host;

    if (match != null) {
      String detectedProtocol = match.group(1)!.toLowerCase();
      protocolsToTry = [detectedProtocol];
      host = rawUrl.substring(detectedProtocol.length);
    } else {
      host = rawUrl;
      protocolsToTry = [state.protocol];
      protocolsToTry.add(state.protocol == 'https://' ? 'http://' : 'https://');
    }

    bool success = false;
    dynamic lastError;

    for (String protocol in protocolsToTry) {
      try {
        final dbList = await _networkService.fetchDatabaseList(
          '$protocol$host',
        );

        if (dbList.isNotEmpty) {
          emit(
            state.copyWith(
              databases: dbList,
              selectedDatabase: dbList.length == 1 ? dbList.first : null,
              showManualDbInput: false,
              url: host,
              protocol: protocol,
              errorMessage: "",
            ),
          );
          success = true;
          break;
        } else {
          emit(
            state.copyWith(
              databases: [],
              selectedDatabase: null,
              showManualDbInput: true,
              url: host,
              protocol: protocol,
              errorMessage: "",
            ),
          );
          success = true;
          break;
        }
      } catch (error) {
        if (error is Map && error.containsKey('data')) {
          emit(
            state.copyWith(
              databases: [],
              selectedDatabase: null,
              showManualDbInput: true,
              url: host,
              protocol: protocol,
              errorMessage: "",
            ),
          );
          success = true;
          break;
        }
        lastError = error;
      }
    }

    if (!success) {
      emit(
        state.copyWith(
          databases: [],
          selectedDatabase: null,
          showManualDbInput: false,
          errorMessage: _formatError(lastError),
          url: host,
          protocol: null,
        ),
      );
    }

    emit(state.copyWith(isLoading: false));
  }

  /// Loads saved URL history from local storage.
  Future<void> _loadUrlHistory() async {
    await _loadUrlHistoryForProtocol(state.protocol);
  }

  /// Loads URL suggestions and history for given protocol.
  Future<void> _loadUrlHistoryForProtocol(String protocol) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('urlHistory') ?? [];
    final Map<String, Map<String, String>> history = {};
    final List<String> suggestions = [];

    for (var entry in raw) {
      try {
        final decoded = jsonDecode(entry) as Map<String, dynamic>;
        final protocol = decoded['protocol'] as String? ?? state.protocol;
        final url = decoded['url'] as String;
        final fullUrl = '$protocol$url';
        suggestions.add(fullUrl);
        history[fullUrl] = {
          'db': decoded['db'] ?? '',
          'username': decoded['username'] ?? '',
        };
      } catch (_) {}
    }
    if (!isClosed) {
      emit(state.copyWith(urlSuggestions: suggestions, urlHistory: history));
    }
  }

  /// Converts technical errors into user-friendly messages.
  String _formatError(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    if (errorStr.contains('html instead of json') ||
        errorStr.contains('formatexception')) {
      return 'Server configuration issue. This may not be an Odoo server or the URL is incorrect.';
    } else if (errorStr.contains('invalid login') ||
        errorStr.contains('wrong credentials')) {
      return 'Incorrect email or password. Please check your login credentials.';
    } else if (errorStr.contains('user not found') ||
        errorStr.contains('no such user')) {
      return 'User account not found. Please check your email address or contact your administrator.';
    } else if (errorStr.contains('database') &&
        errorStr.contains('not found')) {
      return 'Selected database is not available. Please choose a different database.';
    } else if (errorStr.contains('network') || errorStr.contains('socket')) {
      return 'Network connection failed. Please check your internet connection.';
    } else if (errorStr.contains('timeout')) {
      return 'Connection timed out. The server may be slow or unreachable.';
    } else if (errorStr.contains('unauthorized') || errorStr.contains('403')) {
      return 'Access denied. Your account may not have permission to access this database.';
    } else if (errorStr.contains('server') || errorStr.contains('500')) {
      return 'Server error occurred. Please try again later or contact your administrator.';
    } else if (errorStr.contains('ssl') || errorStr.contains('certificate')) {
      return 'SSL connection failed. Try using HTTP instead of HTTPS.';
    } else if (errorStr.contains('connection refused')) {
      return 'Server is not responding. Please verify the server URL and try again.';
    } else if (errorStr.contains('connection terminated during handshake')) {
      return 'Secure connection failed. The server may not support HTTPS or has an invalid SSL certificate. Try switching to HTTP or contact your administrator.';
    } else {
      return 'Network error occurred. Please check your internet connection and server URL';
    }
  }

  /// Cancels debounce timer when bloc is disposed.
  @override
  Future<void> close() {
    _debounce?.cancel();
    return super.close();
  }
}
