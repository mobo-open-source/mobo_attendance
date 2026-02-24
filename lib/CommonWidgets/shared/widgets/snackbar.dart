import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobo_attendance/CommonWidgets/core/providers/language_provider.dart';

import '../../core/colors/app_colors.dart';
import '../../core/navigation/global_keys.dart';

/// Defines supported snackbar visual categories.
/// Used to decide icon, color and semantic meaning.
enum SnackbarType {
  info,
  success,
  warning,
  error,
}

/// Centralized helper for showing styled, translated snackbars.
///
/// Key Features:
/// • Works without local Scaffold (uses global keys)
/// • Supports light/dark theme automatically
/// • Integrates with LanguageProvider for translation
/// • Prevents context crash using mounted checks
class CustomSnackbar {
  /// Shows a snackbar with title + message.
  /// Uses global ScaffoldMessenger for safe display.
  static void show({
    required BuildContext context,
    required String title,
    required String message,
    SnackbarType type = SnackbarType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    try {
      if (!context.mounted) {
        return;
      }
      Theme.of(context);
    } catch (e) {
      return;
    }

    void tryShow() {
      try {
        final ScaffoldMessengerState? messenger = scaffoldMessengerKey.currentState;
        if (messenger == null || !messenger.mounted) {
          return;
        }

        BuildContext? themeCtx;
        try {
          themeCtx = navigatorKey.currentContext;
          if (themeCtx != null && themeCtx.mounted) {
            Theme.of(themeCtx);
          } else {
            themeCtx = null;
          }
        } catch (e) {
          themeCtx = null;
        }

        _showWithMessenger(messenger, themeCtx, context, title, message, type, duration);
      } catch (e) {
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => tryShow());
  }

  /// Internal renderer that builds and displays snackbar UI.
  /// Handles translation, theme detection and safe messenger usage.
  static Future<void> _showWithMessenger(
      ScaffoldMessengerState messenger,
      BuildContext? themeContext,
      BuildContext context,
      String title,
      String message,
      SnackbarType type,
      Duration duration,
      ) async{
    try {
      final ts = context.read<LanguageProvider>();

      if (!messenger.mounted) {
        return;
      }

      bool isDark = false;
      if (themeContext != null && themeContext.mounted) {
        try {
          isDark = Theme.of(themeContext).brightness == Brightness.dark;
        } catch (e) {
          isDark = false;
        }
      }
      final colors = _getColorsForType(type, isDark);

      if (!messenger.mounted) {
        return;
      }

      try {
        messenger.hideCurrentSnackBar();
      } catch (e) {
      }
      final liveTitle   = await ts.translate(title);
      final liveMessage = await ts.translate(message);
      try {
        messenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: colors.iconBackgroundColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    colors.icon,
                    size: 16,
                    color: colors.iconColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        liveTitle,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        liveMessage,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[300] : Colors.grey[100],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: colors.backgroundColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: duration,
            elevation: 8,
          ),
        );
      } catch (e) {
      }
    } catch (e) {
    }
  }

  /// Returns color + icon styling based on snackbar type and theme mode.
  static _SnackbarColors _getColorsForType(SnackbarType type, bool isDark) {
    switch (type) {
      case SnackbarType.info:
        return _SnackbarColors(
          icon: Icons.info_outline,
          iconColor: Colors.blue[300]!,
          iconBackgroundColor: Colors.blue.withOpacity(0.2),
          backgroundColor: isDark ? AppColors.infoBackgroundDark :  AppColors.infoBackgroundLight,
        );
      case SnackbarType.success:
        return _SnackbarColors(
          icon: Icons.check_circle_outline,
          iconColor: Colors.green[300]!,
          iconBackgroundColor: Colors.green.withOpacity(0.2),
          backgroundColor: isDark ? AppColors.successBackgroundDark : AppColors.successBackgroundLight,
        );
      case SnackbarType.warning:
        return _SnackbarColors(
          icon: Icons.warning_outlined,
          iconColor: Colors.orange[300]!,
          iconBackgroundColor: Colors.orange.withOpacity(0.2),
          backgroundColor: isDark ? AppColors.warningBackgroundDark : AppColors.warningBackgroundLight,
        );
      case SnackbarType.error:
        return _SnackbarColors(
          icon: Icons.error_outline,
          iconColor: Colors.red[300]!,
          iconBackgroundColor: Colors.red.withOpacity(0.2),
          backgroundColor: isDark ? AppColors.errorBackgroundDark : AppColors.errorBackgroundLight,
        );
    }
  }

  /// Shortcut helper to show success snackbar.
  static void showSuccess(BuildContext context, String message) {
    show(
      context: context,
      title: 'Success',
      message: message,
      type: SnackbarType.success,
    );
  }

  /// Shortcut helper to show error snackbar.
  static void showError(BuildContext context, String message) {
    show(
      context: context,
      title: 'Error',
      message: message,
      type: SnackbarType.error,
    );
  }

  /// Shortcut helper to show info snackbar.
  static void showInfo(BuildContext context, String message) {
    show(
      context: context,
      title: 'Info',
      message: message,
      type: SnackbarType.info,
    );
  }

  /// Shortcut helper to show warning snackbar.
  static void showWarning(BuildContext context, String message) {
    show(
      context: context,
      title: 'Warning',
      message: message,
      type: SnackbarType.warning,
    );
  }
}

/// Internal styling model for snackbar visuals.
/// Holds icon + color configuration for each snackbar type.
class _SnackbarColors {
  final IconData icon;
  final Color iconColor;
  final Color iconBackgroundColor;
  final Color backgroundColor;

  _SnackbarColors({
    required this.icon,
    required this.iconColor,
    required this.iconBackgroundColor,
    required this.backgroundColor,
  });
}

