
import '../../../../LoginPages/login/models/session_model.dart';

/// Contract for handling company session authentication and session retrieval.
///
/// Implementations should handle:
/// - Login and session persistence
/// - Returning current active session

abstract class CompanySessionService {

  /// Logs in user and saves session locally.
  ///
  /// Returns true if login + session save is successful.
  Future<bool> loginAndSaveSession({
    required String serverUrl,
    required String database,
    required String userLogin,
    required String password,
  });

  /// Returns currently saved session if available, otherwise null.
  Future<SessionModel?> getCurrentSession();
}
