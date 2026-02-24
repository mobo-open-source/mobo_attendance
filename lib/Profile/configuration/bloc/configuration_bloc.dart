import 'dart:developer';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../CommonWidgets/core/company/session/company_session_manager.dart';
import '../../../LoginPages/credetials/services/storage_service.dart';
import '../../../LoginPages/login/models/session_model.dart';
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
  /// Steps:
  /// 1. Sets `switchStatus: switching`
  /// 2. Saves new session model to secure storage
  /// 3. Updates shared preferences (login, url, database)
  /// 4. Clears company session cache
  /// 5. Verifies new active session
  /// 6. On success: `switchStatus: completed`
  /// 7. On failure: `switchStatus: failed` + error message
  ///
  /// Triggers full app reload via listener in UI.
  Future<void> _switchAccount(
      SwitchAccountEvent event,
      Emitter<ConfigurationState> emit,
      ) async {
    try {
      emit(state.copyWith(switchStatus: SwitchStatus.switching));

      final prefs = await SharedPreferences.getInstance();
      final user = event.user;

      // Preserve version & allowed companies
      final version = prefs.getInt("version") ?? 0;
      final allowedRaw = prefs.getStringList('allowed_company_ids') ?? [];
      final allowedCompanyIds = allowedRaw
          .map((e) => int.tryParse(e) ?? 0)
          .where((e) => e > 0)
          .toList();

      // Save new session
      await storageService.saveSession(
        SessionModel(
          sessionId: user['sessionId'],
          userName: user['userName'],
          userLogin: user['userLogin'],
          userId: user['userId'],
          serverVersion: user['serverVersion'],
          userLang: user['userLang'],
          partnerId: user['partnerId'],
          userTimezone: user['userTimezone'],
          companyId: user['companyId'],
          companyName: user['companyName'],
          isSystem: user['isSystem'] ?? false,
          version: version,
          allowedCompanyIds: allowedCompanyIds,
        ),
      );

      // Update basic user metadata in prefs
      await prefs.setString('userLogin', user['userLogin'].toString());
      await prefs.setString('url', user['url'] ?? '');
      await prefs.setString('database', user['database'] ?? '');

      // Clear any cached company/session data
      await CompanySessionManager.clearSessionCache();

      // Verify switch worked
      await CompanySessionManager.getCurrentSession();
      emit(state.copyWith(switchStatus: SwitchStatus.completed));
    } catch (e) {
      emit(state.copyWith(
        switchStatus: SwitchStatus.failed,
        error: e.toString(),
      ));
    }
  }

}
