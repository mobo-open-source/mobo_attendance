import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../login/models/session_model.dart';

/// Service class responsible for handling local storage operations
/// using SharedPreferences.
///
/// This includes:
/// - Saving and retrieving user session details
/// - Managing login state (logged in status, database, URL)
/// - Storing and retrieving multiple logged-in account details
/// - Managing saved locale preferences
///
/// All data is persisted locally on the device.
class StorageService {

  /// Saves the current user session details to local storage.
  ///
  /// Stores user-related information such as:
  /// - Username and login
  /// - User ID and session ID
  /// - Server version and language
  /// - Partner ID and company details
  /// - Timezone and system flags
  /// - Allowed company IDs list
  ///
  /// [session] - SessionModel object containing session data.
  Future<void> saveSession(SessionModel session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userName', session.userName ?? '');
    await prefs.setString('userLogin', session.userLogin ?? '');
    await prefs.setInt('userId', session.userId ?? 0);
    await prefs.setString('sessionId', session.sessionId);
    await prefs.setString('serverVersion', session.serverVersion ?? '');
    await prefs.setString('userLang', session.userLang ?? '');
    await prefs.setInt('partnerId', session.partnerId ?? 0);
    await prefs.setString('userTimezone', session.userTimezone ?? '');
    await prefs.setInt('companyId', session.companyId ?? 1);
    await prefs.setString('company_name', session.companyName ?? '');
    await prefs.setBool('isSystem', session.isSystem);
    await prefs.setInt('version', session.version ?? 0);
    await prefs.setStringList(
      'allowed_company_ids',
      session.allowedCompanyIds.map((e) => e.toString()).toList(),
    );
  }

  /// Retrieves the saved user language/locale from local storage.
  ///
  /// Returns:
  /// - Saved locale string if available
  /// - null if no locale is stored
  Future<String?> getSavedLocale() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('userLang');
  }

  /// Saves login state information to local storage.
  ///
  /// Stores:
  /// - Whether user is logged in
  /// - Selected database name
  /// - Server URL
  ///
  /// [isLoggedIn] - Indicates login status.
  /// [database] - Selected database name.
  /// [url] - Server URL.
  Future<void> saveLoginState({
    required bool isLoggedIn,
    required String database,
    required String url,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', isLoggedIn);
    await prefs.setString('database', database);
    await prefs.setString('url', url);
  }

  /// Retrieves login state information from local storage.
  ///
  /// Returns a map containing:
  /// - isLoggedIn → bool
  /// - useLocalAuth → bool
  /// - database → String
  /// - url → String
  ///
  /// Provides default values if nothing is stored.
  Future<Map<String, dynamic>> getLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'isLoggedIn': prefs.getBool('isLoggedIn') ?? false,
      'useLocalAuth': prefs.getBool('useLocalAuth') ?? false,
      'database': prefs.getString('database') ?? '',
      'url': prefs.getString('url') ?? '',
    };
  }

  static const _accountsKey = 'loggedInAccounts';

  /// Saves or updates a logged-in account in local storage.
  ///
  /// Behavior:
  /// - Removes existing account with same userLogin
  /// - Adds new account to stored accounts list
  /// - Ensures 'image' field exists (adds empty string if missing)
  ///
  /// Accounts are stored as JSON string list.
  ///
  /// [account] - Map containing account details.
  Future<void> saveAccount(Map<String, dynamic> account) async {
    final prefs = await SharedPreferences.getInstance();
    final accounts = await getAccounts();

    accounts.removeWhere((a) =>
    a['userLogin'] == account['userLogin'] &&
        a['url'] == account['url'] &&
        a['database'] == account['database']);

    if (!account.containsKey('image')) {
      account['image'] = '';
    }

    accounts.add(account);

    await prefs.setString(_accountsKey, jsonEncode(accounts));
  }

  /// Retrieves all saved logged-in accounts from local storage.
  ///
  /// Returns:
  /// - List of account maps if available
  /// - Empty list if no accounts are stored
  Future<List<Map<String, dynamic>>> getAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final accountsJson = prefs.getString(_accountsKey);
    if (accountsJson == null) return [];
    final decoded = jsonDecode(accountsJson) as List<dynamic>;
    return decoded.cast<Map<String, dynamic>>();
  }

  /// Clears all saved logged-in accounts from local storage.
  ///
  /// Removes the stored accounts JSON completely.
  Future<void> clearAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accountsKey);
  }

  Future<void> removeAccount({
    required String userLogin,
    required String userName,
    required int userId,
    required String url,
    required String database,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final accounts = await getAccounts();

    accounts.removeWhere((a) =>
    a['userLogin'] == userLogin &&
    a['userName'] == userName &&
    a['userId'] == userId &&
        a['url'] == url &&
        a['database'] == database);

    await prefs.setString(_accountsKey, jsonEncode(accounts));
  }
}
