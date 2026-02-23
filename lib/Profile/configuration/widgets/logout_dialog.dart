import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../CommonWidgets/core/company/services/connectivity_service.dart';
import '../../../CommonWidgets/core/company/session/company_session_manager.dart';
import '../../../CommonWidgets/core/language/translate_widget.dart';
import '../../../CommonWidgets/core/security/secure_storage_service.dart';
import '../../../CommonWidgets/globals.dart';
import '../../../CommonWidgets/shared/widgets/snackbar.dart';
import '../../../LoginPages/credetials/services/storage_service.dart';
import '../services/app_shutdown_manager.dart';

/// Confirmation dialog shown when user taps "Logout".
///
/// Features:
/// - Clean dark/light theme support
/// - Non-dismissible loading overlay during logout process
/// - Preserves essential preferences (language, URL history, get-started flag, biometrics)
/// - Clears session, accounts, secure storage, cached data, and all major BLoCs
/// - Navigates back to login screen and shows success snackbar
class LogoutDialog extends StatefulWidget {
  final StorageService storageService;

  const LogoutDialog({required this.storageService});

  @override
  _LogoutDialogState createState() => _LogoutDialogState();
}

class _LogoutDialogState extends State<LogoutDialog> {
  bool isLogoutLoading = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AlertDialog(
      backgroundColor: isDark ? Colors.grey[800] : Colors.white,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          tr(
            "Confirm Logout",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
              fontSize: 18,
            ),
          ),
        ],
      ),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 15),
          tr(
            'Are you sure you want to log out? Your session will be ended.',
            style: TextStyle(
              fontWeight: FontWeight.normal,
              fontSize: 15,
            ),
          ),
        ],
      ),
      actions: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Cancel button
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? Colors.white : Colors.black87,
                  backgroundColor: isDark ? Colors.grey[800] : Colors.white,
                  side: BorderSide(
                    color: isDark ? Colors.white : AppStyle.primaryColor,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                child: tr(
                  'Cancel',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Log Out button (shows loading when in progress)
            Expanded(
              child: ElevatedButton(
                onPressed: () async {
                  await _performLogout(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark
                      ? Colors.red[700]
                      : Theme.of(context).colorScheme.error,
                  foregroundColor: isDark
                      ? Colors.white
                      : Theme.of(context).colorScheme.onError,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  elevation: isDark ? 0 : 3,
                ),
                child: isLogoutLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    :  tr(
                  'Log Out',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Performs the full logout sequence:
  /// 1. Shows non-dismissible loading dialog
  /// 2. Clears connectivity server URL
  /// 3. Preserves essential prefs (language, URL history, get-started, biometrics)
  /// 4. Clears all other shared preferences
  /// 5. Clears secure storage accounts
  /// 6. Clears session cache
  /// 7. Deletes all saved passwords
  /// 8. Closes all major BLoCs via AppShutdownManager
  /// 9. Navigates to login screen and removes previous routes
  /// 10. Shows success snackbar
  Future<void> _performLogout(BuildContext context) async {
    setState(() => isLogoutLoading = true);

    // Show non-dismissible loading overlay
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Dialog(
          backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LoadingAnimationWidget.fourRotatingDots(
                  color: isDark ? Colors.white : AppStyle.primaryColor,
                  size: 50,
                ),
                const SizedBox(height: 20),
                tr(
                  "Logging out...",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                tr(
                  "Please wait while we process your request.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          ),
        );
      },
    );

    // Artificial delay to ensure user sees loading (UX polish)
    await Future.delayed(const Duration(seconds: 2));

    // ── Clear runtime state ──────────────────────────────────────────────────
    ConnectivityService.instance.setCurrentServerUrl(null);

    // ── Preserve essential user preferences ──────────────────────────────────
    final prefs = await SharedPreferences.getInstance();
    List<String> urlHistory = prefs.getStringList('urlHistory') ?? [];
    bool isGetStarted = prefs.getBool('hasSeenGetStarted') ?? false;
    bool _biometricEnabled = prefs.getBool('biometricEnabled') ?? false;
    final languageCode = prefs.getString('languageCode') ?? 'en';

    // Clear everything else
    await prefs.clear();

    // Restore preserved values
    await prefs.setString('languageCode', languageCode);
    await prefs.setStringList('urlHistory', urlHistory);
    await prefs.setBool('hasSeenGetStarted', isGetStarted);
    await prefs.setBool('biometricEnabled', _biometricEnabled);

    // ── Clear secure storage and accounts ────────────────────────────────────
    await widget.storageService.clearAccounts();
    await CompanySessionManager.clearSessionCache();
    await SecureStorageService().deleteAllPasswords();

    // ── Shut down all major BLoCs ────────────────────────────────────────────
    AppShutdownManager.resetAllBlocs();

    // ── Navigate to login and clean stack ────────────────────────────────────
    if (context.mounted) {
      Navigator.pop(context);
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      CustomSnackbar.showSuccess(context, 'Logged out successfully');
    }

    setState(() => isLogoutLoading = false);
  }
}
