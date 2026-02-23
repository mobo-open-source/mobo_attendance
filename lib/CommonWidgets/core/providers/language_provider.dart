import 'package:flutter/foundation.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:collection/collection.dart';

import '../../../Profile/settings/services/settings_storage_service.dart';

/// Handles app language translation using MLKit On-Device Translator.
///
/// Features:
/// • On-device translation (no internet required after model download)
/// • Local caching for faster repeated translations
/// • Persistent cache storage per language
/// • Preload support for bulk translation
///
/// Default language → English
class LanguageProvider with ChangeNotifier {
  /// MLKit translator instance
  OnDeviceTranslator? _translator;

  /// Handles model download / availability
  final _modelManager = OnDeviceTranslatorModelManager();

  /// Current language code (ex: en, ar, hi)
  String _currentCode = 'en';

  /// Indicates translation model is initializing / downloading
  bool _isInitializing = false;

  /// In-memory translation cache
  final Map<String, String> _cache = {};

  String get currentCode => _currentCode;

  bool get isInitializing => _isInitializing;

  /// Converts language code string → MLKit TranslateLanguage enum
  ///
  /// Fallback → English if language not supported
  TranslateLanguage _codeToTranslateLanguageOrEnglish(String code) {
    final langCode = code.split('_').first;

    final lang = TranslateLanguage.values.firstWhereOrNull(
      (lang) => lang.bcpCode == langCode,
    );

    if (lang == null) {
      return TranslateLanguage.english;
    }

    return lang;
  }

  /// Preloads translations into cache.
  ///
  /// Useful when:
  /// • Opening new screen
  /// • Bulk translating UI labels
  Future<void> preload(List<String> texts) async {
    if (_translator == null) return;
    bool changed = false;

    for (final text in texts) {
      if (!_cache.containsKey(text)) {
        final translated = await _translator!.translateText(text);
        _cache[text] = translated ?? text;
        changed = true;
      }
    }
    if (changed) await _saveLocalCache();
  }

  /// Returns cached translation if available.
  ///
  /// Fallback → Original key text
  String? getCached(String key) {
    final v = _cache[key];
    if (v == null || v.trim().isEmpty) return key;
    return v;
  }

  /// Initializes translator for given language code.
  ///
  /// Steps:
  /// • Checks if model exists
  /// • Downloads if missing
  /// • Creates translator instance
  /// • Loads local cache
  Future<bool> initializeTranslator(String targetCode) async {
    if (targetCode == _currentCode) return true;

    _isInitializing = true;
    notifyListeners();

    final targetLang = _codeToTranslateLanguageOrEnglish(targetCode);

    /// Ensure translation model is available
    final isDownloaded = await _modelManager.isModelDownloaded(
      targetLang.bcpCode,
    );
    if (!isDownloaded) {
      await _modelManager.downloadModel(targetLang.bcpCode);
    }

    /// Dispose previous translator before creating new one
    await _translator?.close();

    _translator = OnDeviceTranslator(
      sourceLanguage: TranslateLanguage.english,
      targetLanguage: targetLang,
    );

    _currentCode = targetLang == TranslateLanguage.english
        ? 'en'
        : targetLang.bcpCode;
    await _loadLocalCache();
    _isInitializing = false;
    notifyListeners();
    return true;
  }

  /// Translates given English text.
  ///
  /// Flow:
  /// • If English → return original
  /// • If cached → return cached
  /// • Else → translate and cache result
  Future<String> translate(String english) async {
    if (_currentCode == 'en' || _translator == null) return english;

    if (_cache.containsKey(english)) return _cache[english]!;

    try {
      final result = await _translator!.translateText(english);
      final translated = result ?? english;
      _cache[english] = translated;
      await _saveLocalCache();
      return translated;
    } catch (_) {
      return english;
    }
  }

  /// Clears current language translation cache.
  Future<void> clearCache() async {
    _cache.clear();
    final storage = SettingsStorageService();
    await storage.setJson(_cacheKey(_currentCode), {});
  }

  @override
  void dispose() {
    _translator?.close();
    super.dispose();
  }

  /// Cache storage key generator per language
  static String _cacheKey(String code) => 'translation_cache_$code';

  /// Loads translation cache from local storage
  Future<void> _loadLocalCache() async {
    final storage = SettingsStorageService();
    final local = await storage.getJson(_cacheKey(_currentCode));

    if (local != null) {
      _cache
        ..clear()
        ..addAll(local.map((k, v) => MapEntry(k, v.toString())));
    }
  }

  /// Saves translation cache to local storage
  Future<void> _saveLocalCache() async {
    final storage = SettingsStorageService();
    await storage.setJson(_cacheKey(_currentCode), _cache);
  }
}
