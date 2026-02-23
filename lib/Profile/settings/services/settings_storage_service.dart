import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// A singleton service that provides a clean, type-safe wrapper around [SharedPreferences].
///
/// Features:
/// - Singleton pattern (one instance across the app)
/// - Lazy initialization via `initialize()`
/// - Convenient methods for common types (bool, String, int, double, JSON maps)
/// - JSON serialization/deserialization helpers
/// - Key existence check, remove, and full clear
///
/// Usage:
///   ```dart
///   final storage = SettingsStorageService();
///   await storage.initialize();
///   await storage.setBool('darkMode', true);
///   final isDark = storage.getBool('darkMode') ?? false;
///   ```
class SettingsStorageService {
  static final SettingsStorageService _instance =
  SettingsStorageService._internal();

  factory SettingsStorageService() => _instance;
  SettingsStorageService._internal();

  late SharedPreferences _prefs;

  /// Initializes the underlying SharedPreferences instance.
  ///
  /// Must be called **before** using any get/set methods.
  /// Usually called in `initState()` of the first screen or in main().
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ────────────────────────────────────────────────
  // JSON helpers
  // ────────────────────────────────────────────────

  /// Stores a JSON-serializable map under the given [key].
  ///
  /// The map is automatically encoded to a JSON string.
  Future<void> setJson(String key, Map<String, dynamic> value) async {
    await _prefs.setString(key, jsonEncode(value));
  }

  /// Retrieves and decodes a JSON map stored under [key].
  ///
  /// Returns `null` if the key doesn't exist or the value isn't valid JSON.
  Future<Map<String, dynamic>?> getJson(String key) async {
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    return jsonDecode(raw);
  }

  // ────────────────────────────────────────────────
  // Utility & existence check
  // ────────────────────────────────────────────────

  /// Checks whether a value exists for the given [key].
  bool exists(String key) => _prefs.containsKey(key);

  // ────────────────────────────────────────────────
  // Type-specific setters & getters
  // ────────────────────────────────────────────────

  Future<void> setBool(String key, bool value) async => _prefs.setBool(key, value);
  Future<void> setString(String key, String value) async => _prefs.setString(key, value);
  String? getString(String key) => _prefs.getString(key);
  Future<void> setInt(String key, int value) async => _prefs.setInt(key, value);
  int? getInt(String key) => _prefs.getInt(key);
  Future<void> setDouble(String key, double value) async => _prefs.setDouble(key, value);
  double? getDouble(String key) => _prefs.getDouble(key);
  bool? getBool(String key) => _prefs.getBool(key);

  // ────────────────────────────────────────────────
  // Removal & reset
  // ────────────────────────────────────────────────

  /// Removes the value associated with the given [key].
  Future<void> remove(String key) async => _prefs.remove(key);

  /// Clears **all** data stored in SharedPreferences.
  ///
  /// Use with caution — this deletes **everything**, including login tokens,
  /// theme preferences, language settings, etc.
  Future<void> clearAll() async => _prefs.clear();
}

