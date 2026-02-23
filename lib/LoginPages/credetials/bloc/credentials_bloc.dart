import 'dart:convert';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../CommonWidgets/core/company/services/company_session_service.dart';
import '../../../MainScreens/AppBars/services/common_storage_service.dart';
import '../../login/models/session_model.dart';
import '../pages/totp_page.dart';
import '../services/storage_service.dart';

part 'credentials_event.dart';

part 'credentials_state.dart';

/// Bloc responsible for handling login credential flow.
///
/// Responsibilities:
/// • Handles login submission
/// • Manages password visibility toggle
/// • Stores session + account details
/// • Maintains URL login history
/// • Handles error formatting and navigation (like TOTP flow)
///
/// This acts as the business logic layer between UI and session services.
class CredentialsBloc extends Bloc<CredentialsEvent, CredentialsState> {
  final CompanySessionService sessionService;
  final CommonStorageService commonStorageService;

  CredentialsBloc({
    required this.sessionService,
    required this.commonStorageService,
  }) : super(CredentialsState.initial()) {
    on<TogglePasswordVisibility>(_onTogglePasswordVisibility);
    on<SubmitLogin>(_onSubmitLogin);
    on<ClearErrorMessage>(_onClearErrorMessage);
  }

  void _onClearErrorMessage(
    ClearErrorMessage event,
    Emitter<CredentialsState> emit,
  ) {
    emit(state.copyWith(errorMessage: null));
  }

  void _onTogglePasswordVisibility(
    TogglePasswordVisibility event,
    Emitter<CredentialsState> emit,
  ) {
    emit(state.copyWith(isPasswordVisible: !state.isPasswordVisible));
  }

  /// Handles login submission process.
  ///
  /// Flow:
  /// 1. Cleans and formats URL
  /// 2. Calls session service login
  /// 3. Saves login history
  /// 4. Stores session/account details locally
  /// 5. Updates UI state (loading, success, error)
  ///
  /// Also triggers TOTP navigation if server requires 2FA.
  Future<void> _onSubmitLogin(
    SubmitLogin event,
    Emitter<CredentialsState> emit,
  ) async {
    final context = event.context;
    if (!context.mounted) return;

    emit(state.copyWith(isLoading: true, errorMessage: null));
    try {
      final cleanUrl = event.url.replaceFirst(RegExp(r'^https?://'), '').trim();
      final fullUrl = event.protocol + cleanUrl;

      final success = await sessionService.loginAndSaveSession(
        serverUrl: fullUrl,
        database: event.database,
        userLogin: event.username.trim(),
        password: event.password.trim(),
      );
      await _saveUrlHistory(
        protocol: event.protocol,
        url: event.url,
        database: event.database,
        username: event.username.trim(),
      );

      if (!success) {
        emit(
          state.copyWith(
            isLoading: false,
            errorMessage: 'Authentication failed.',
          ),
        );
        return;
      }

      final session = await sessionService.getCurrentSession();
      await StorageService().clearAccounts();
      await commonStorageService.saveAccount({
        'userName': session?.userName,
        'userLogin': session?.userLogin,
        'userId': session?.userId,
        'sessionId': session?.sessionId,
        'serverVersion': session?.serverVersion,
        'userLang': session?.userLang,
        'partnerId': session?.partnerId,
        'userTimezone': session?.userTimezone,
        'companyId': session?.companyId,
        'companyName': session?.companyName,
        'isSystem': session?.isSystem,
        'url': fullUrl,
        'database': event.database,
        'image': '',
      });

      emit(
        state.copyWith(isLoading: false, loginSuccess: true, session: session),
      );
    } catch (e) {
      final message = await _formatError(e, event);
      emit(state.copyWith(isLoading: false, errorMessage: message));
    }
  }

  /// Saves recently used login URLs into local storage.
  ///
  /// Features:
  /// • Maintains latest 10 login entries
  /// • Removes duplicates
  /// • Normalizes protocol (http / https)
  /// • Stores database + username for quick login reuse
  Future<void> _saveUrlHistory({
    required String protocol,
    required String url,
    required String database,
    required String username,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> history = prefs.getStringList('urlHistory') ?? [];

    String finalProtocol = protocol;
    String finalUrl = url.trim();

    if (finalUrl.startsWith('https://')) {
      finalProtocol = 'https://';
      finalUrl = finalUrl.replaceFirst('https://', '');
    } else if (finalUrl.startsWith('http://')) {
      finalProtocol = 'http://';
      finalUrl = finalUrl.replaceFirst('http://', '');
    }

    final entry = jsonEncode({
      'protocol': finalProtocol,
      'url': finalUrl,
      'db': database,
      'username': username,
    });

    history.removeWhere((e) {
      final d = jsonDecode(e);
      return d['url'] == finalUrl && d['protocol'] == finalProtocol;
    });

    history.insert(0, entry);
    await prefs.setStringList('urlHistory', history.take(10).toList());
  }

  /// Converts raw login errors into user-friendly messages.
  ///
  /// Handles:
  /// • Authentication errors
  /// • Network failures
  /// • Server configuration issues
  /// • Database not found errors
  /// • SSL / certificate issues
  ///
  /// Also detects 2FA requirement and navigates to TOTP screen.
  Future<String> _formatError(dynamic error, SubmitLogin event) async {
    final errorStr = error.toString().toLowerCase();

    final context = event.context;
    final cleanUrl = event.url
        .replaceFirst(RegExp(r'^https?://'), '')
        .replaceAll(RegExp(r'^/+'), '');

    if (errorStr.contains('null') ||
        errorStr.contains('two factor') ||
        errorStr.contains('2fa')) {
      await StorageService().clearAccounts();
      await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => TotpPage(
            protocol: event.protocol,
            serverUrl: event.protocol + cleanUrl,
            database: event.database,
            username: event.username.trim(),
            password: event.password.trim(),
          ),
        ),
      );
    }

    if (errorStr.contains('accessdenied') ||
        errorStr.contains('wrong login/password') ||
        errorStr.contains('invalid login') ||
        errorStr.contains('{code: 200') && errorStr.contains('accessdenied')) {
      return 'Incorrect username or password. Please check your login credentials.';
    } else if (errorStr.contains('html instead of json') ||
        errorStr.contains('formatexception')) {
      return 'Server configuration issue. This may not be an Odoo server or the URL is incorrect.';
    } else if (errorStr.contains('invalid login') ||
        errorStr.contains('wrong credentials')) {
      return 'Incorrect username or password. Please check your login credentials.';
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
    } else if (errorStr.contains('null')) {
      return '';
    } else {
      return 'Login failed. Please check your credentials and server settings.';
    }
  }
}
