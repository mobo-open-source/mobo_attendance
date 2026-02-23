import '../../../../LoginPages/login/models/session_model.dart';
import '../session/company_session_manager.dart';
import 'company_session_service.dart';

/// Default implementation of [CompanySessionService].
///
/// Delegates session operations to CompanySessionManager.
class CompanySessionServiceImpl implements CompanySessionService {

  /// Performs login and saves session using session manager.
  @override
  Future<bool> loginAndSaveSession({
    required String serverUrl,
    required String database,
    required String userLogin,
    required String password,
  }) {
    return CompanySessionManager.loginAndSaveSession(
      serverUrl: serverUrl,
      database: database,
      userLogin: userLogin,
      password: password,
    );
  }

  /// Returns current stored session from session manager.
  @override
  Future<SessionModel?> getCurrentSession() {
    return CompanySessionManager.getCurrentSession();
  }
}
