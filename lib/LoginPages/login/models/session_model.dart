/// Stores user session information received after login.
///
/// Contains:
/// - User details
/// - Session ID
/// - Server information
/// - Company details
/// - Allowed company access list
class SessionModel {
  final String? userName;
  final String? userLogin;
  final int? userId;
  final String sessionId;
  final String? serverVersion;
  final String? userLang;
  final int? partnerId;
  final String? userTimezone;
  final int? companyId;
  final String? companyName;
  final bool isSystem;
  final int? version;
  final List<int> allowedCompanyIds;

  SessionModel({
    required this.sessionId,
    this.userName,
    this.userLogin,
    this.userId,
    this.serverVersion,
    this.userLang,
    this.partnerId,
    this.userTimezone,
    this.companyId,
    this.companyName,
    this.isSystem = false,
    this.version,
    this.allowedCompanyIds = const [],
  });
}
