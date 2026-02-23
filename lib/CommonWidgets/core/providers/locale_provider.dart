import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../LoginPages/credetials/services/storage_service.dart';

/// Manages app locale state and persists selected language locally.
///
/// Responsibilities:
/// - Holds current Locale used by MaterialApp
/// - Loads saved locale from storage on app start
/// - Updates locale and saves user preference
class LocaleProvider extends ChangeNotifier {

  /// Default locale is English (US) until user preference is loaded.
  Locale _locale = const Locale('en', 'US');

  /// Local storage service used to retrieve saved locale code.
  final StorageService _storage = StorageService();

  /// Returns current active locale used by the app.
  Locale get locale => _locale;

  /// Loads previously saved locale from storage and applies it.
  ///
  /// Should be called during app initialization.
  Future<void> loadSavedLocale() async {
    final code = await _storage.getSavedLocale();
    if (code != null && code.isNotEmpty) {
      await changeLocale(code);
    }
  }

  /// Changes app locale using language code (ex: `en`, `en_US`, `ml`, `ar`).
  ///
  /// Steps:
  /// 1. Splits language and country code (if available)
  /// 2. Updates internal Locale
  /// 3. Saves preference to SharedPreferences
  /// 4. Notifies listeners to rebuild UI
  Future<void> changeLocale(String code) async {
    final parts = code.split('_');
    final String languageCode = parts[0];
    final String? countryCode = parts.length > 1 ? parts[1] : null;

    _locale = Locale(languageCode, countryCode);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userLang', code);

    notifyListeners();
  }
}