import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../LoginPages/credetials/services/auth_service.dart';
import '../../../CommonWidgets/core/company/session/company_session_manager.dart';
import '../../../CommonWidgets/core/security/secure_storage_service.dart';
import '../../../LoginPages/credetials/services/storage_service.dart';
import '../../profile/services/profile_service.dart';
import 'configuration_event.dart';
import 'configuration_state.dart';

/// Manages account configuration and profile-related state for the app.
///
/// Responsibilities:
/// - Loading current user profile (name, email, image, etc.)
/// - Switching between saved accounts (updates session, shared prefs, clears cache)
/// - Refreshing profile data on demand
/// - Tracking account switch status (idle → switching → completed/failed)
///
/// Integrates with:
/// - `ProfileService` for profile data
/// - `StorageService` for secure session/account storage
/// - `CompanySessionManager` for active session management
/// - SharedPreferences for user metadata
class ConfigurationBloc extends Bloc<ConfigurationEvent, ConfigurationState> {
  final ProfileService profileService;
  final StorageService storageService;

  ConfigurationBloc({
    required this.profileService,
    required this.storageService,
  }) : super(const ConfigurationState()) {
    on<LoadProfileEvent>(_loadProfile);
    on<SwitchAccountEvent>(_switchAccount);
    on<RefreshProfileEvent>(_refreshProfile);
  }

  /// Loads the current user's profile data from the backend.
  ///
  /// Emits:
  /// - `isLoading: true` → starts loading
  /// - On success: `profiles` list updated
  /// - On failure: `error` message set
  Future<void> _loadProfile(
      LoadProfileEvent event, Emitter<ConfigurationState> emit) async {
    try {
      emit(state.copyWith(isLoading: true));

      await profileService.initializeClient();
      final profiles = await profileService.loadProfile();

      emit(state.copyWith(isLoading: false, profiles: profiles));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  /// Triggers a profile reload (alias for `LoadProfileEvent`).
  ///
  /// Usually called after profile edit or when returning to configuration screen.
  Future<void> _refreshProfile(
      RefreshProfileEvent event, Emitter<ConfigurationState> emit) async {
    add(LoadProfileEvent());
  }

  /// Switches to a different saved account.
  ///
  /// Unlike a plain cache copy, this always re-validates the account with the
  /// server before declaring the switch successful:
  /// 1. Sets `switchStatus: switching`
  /// 2. Looks up the account's password from secure storage
  /// 3. Tries to reuse the cached session cookie (cheap, no full re-login)
  /// 4. Falls back to a full username/password re-authentication
  /// 5. Persists the fresh session + refreshes the stored account's cached
  ///    sessionId so future switches are more likely to reuse the cookie
  /// 6. On success: `switchStatus: completed`
  /// 7. On failure (bad/missing password, unreachable server, etc.):
  ///    `switchStatus: failed` + error message — the UI never navigates away
  ///    on a switch that wasn't actually verified against the server.
  ///
  /// Triggers full app reload via listener in UI.
  Future<void> _switchAccount(
      SwitchAccountEvent event,
      Emitter<ConfigurationState> emit,
      ) async {
    try {
      emit(state.copyWith(switchStatus: SwitchStatus.switching));

      final user = event.user;
      final url = (user['url'] ?? '').toString();
      final database = (user['database'] ?? '').toString();
      final userLogin = (user['userLogin'] ?? '').toString();
      final storedSessionId = user['sessionId']?.toString();

      if (url.isEmpty || database.isEmpty || userLogin.isEmpty) {
        throw Exception('Stored account is missing connection details.');
      }

      final password = await SecureStorageService().getPassword(
        url: url,
        database: database,
        username: userLogin,
      );

      if (password == null || password.isEmpty) {
        throw Exception(
          'No saved password found for this account. Please remove it and add it again.',
        );
      }

      bool success = false;

      // 1) Try to reuse the cached session cookie first.
      if (storedSessionId != null && storedSessionId.isNotEmpty) {
        try {
          success = await CompanySessionManager.loginAndSaveSession(
            serverUrl: url,
            database: database,
            userLogin: userLogin,
            password: password,
            session_Id: storedSessionId,
          );
        } catch (_) {
          success = false;
        }
      }

      // 2) Fall back to a full re-authentication if the cookie is stale/invalid.
      if (!success) {
        success = await CompanySessionManager.loginAndSaveSession(
          serverUrl: url,
          database: database,
          userLogin: userLogin,
          password: password,
        );
      }

      if (!success) {
        throw Exception('Failed to switch account. Please try again.');
      }

      // Refresh the stored account's cached sessionId/metadata so the next
      // switch is more likely to succeed via the cheap cookie-reuse path.
      final refreshed = await CompanySessionManager.getCurrentSession();
      if (refreshed != null) {
        final updatedAccount = Map<String, dynamic>.from(user)
          ..['sessionId'] = refreshed.sessionId
          ..['serverVersion'] = refreshed.serverVersion
          ..['userLang'] = refreshed.userLang
          ..['partnerId'] = refreshed.partnerId
          ..['userTimezone'] = refreshed.userTimezone
          ..['companyId'] = refreshed.companyId
          ..['companyName'] = refreshed.companyName
          ..['isSystem'] = refreshed.isSystem;
        await storageService.saveAccount(updatedAccount);
      }

      emit(state.copyWith(switchStatus: SwitchStatus.completed));
    } catch (e) {
      emit(state.copyWith(
        switchStatus: SwitchStatus.failed,
        error: e is DatabaseExpiredException ? e.message : e.toString(),
      ));
    }
  }

}
