import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_switch/flutter_switch.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:local_auth/local_auth.dart';
import '../../../CommonWidgets/core/language/translate_widget.dart';
import '../../../CommonWidgets/core/language/translation_strings.dart';
import '../../../CommonWidgets/core/providers/language_provider.dart';
import '../../../CommonWidgets/core/providers/motion_provider.dart';
import '../../../CommonWidgets/core/providers/theme_provider.dart';
import '../../../CommonWidgets/globals.dart';
import '../../../CommonWidgets/shared/widgets/snackbar.dart';
import '../../../LoginPages/credetials/services/storage_service.dart';
import '../services/setting_service.dart';
import '../services/settings_storage_service.dart';
import '../widgets/app_web.dart';

/// Main settings screen of the application.
///
/// Contains sections for:
///   • Appearance (dark mode, reduce motion)
///   • Security (biometric app lock)
///   • Language & Region (language, currency, timezone)
///   • Data & Storage (clear cache)
///   • Help & Support (links to Odoo resources)
///   • About (company links, social media, copyright)
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // ────────────────────────────────────────────────
  // State variables
  // ────────────────────────────────────────────────

  bool darkMode = false;
  bool reduceMotion = false;
  String language = "English (US)";
  String languageCode = "en_US";
  String currency = "United States dollar";
  String timezone = "Europe/Brussels";

  List<Map<String, dynamic>> _languages = [];
  List<Map<String, dynamic>> _currency = [];
  List<Map<String, dynamic>> _timezone = [];

  late StorageService storageService;
  late SettingsStorageService settingsStorageService;
  bool _isLanguageLoading = false;
  bool _isLanguageChanged = false;
  int? userId;

  bool _biometricEnabled = false;
  final LocalAuthentication _auth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _loadBiometricPreference();
    storageService = StorageService();
    settingsStorageService = SettingsStorageService();
    settingsStorageService.initialize().then((_) {
      setState(() {
        userId = settingsStorageService.getInt('userId') ?? userId;
        language = settingsStorageService.getString('language') ?? language;
        currency = settingsStorageService.getString('currency') ?? currency;
        timezone = settingsStorageService.getString('timezone') ?? timezone;
      });
      _initializeOdooClient();
    });
  }

  /// Loads whether biometric lock is enabled from shared preferences
  Future<void> _loadBiometricPreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _biometricEnabled = prefs.getBool('biometricEnabled') ?? false;
    });
  }

  /// Toggles biometric authentication preference
  ///   - When enabling: authenticates user first
  ///   - When disabling: just saves preference
  Future<void> _toggleBiometric(bool value) async {
    final prefs = await SharedPreferences.getInstance();

    if (value) {
      bool canCheck = await _auth.canCheckBiometrics;
      bool isSupported = await _auth.isDeviceSupported();

      if (canCheck || isSupported) {
        bool authenticated = await _auth.authenticate(
          localizedReason: 'Enable biometric authentication',
          options: const AuthenticationOptions(
            biometricOnly: true,
            stickyAuth: true,
          ),
        );

        if (authenticated) {
          setState(() => _biometricEnabled = true);
          await prefs.setBool('biometricEnabled', true);
        }
      } else {
        CustomSnackbar.showError(
          context,
          'Biometric authentication not supported on this device.',
        );
        setState(() => _biometricEnabled = false);
        await prefs.setBool('biometricEnabled', false);
      }
    } else {
      setState(() => _biometricEnabled = false);
      await prefs.setBool('biometricEnabled', false);
    }

    if (mounted) {
      _biometricEnabled
          ? CustomSnackbar.showSuccess(
              context,
              'Biometric authentication enabled.',
            )
          : CustomSnackbar.showError(
              context,
              'Biometric authentication disabled.',
            );
    }
  }

  /// Initializes Odoo client and loads language/currency/timezone options
  Future<void> _initializeOdooClient() async {
    final settingService = SettingService();
    await settingService.initializeClient();
    await loadLanguageAndRegion(settingService);
  }

  /// Fetches available languages, currencies and timezones from backend
  Future<void> loadLanguageAndRegion(settingService) async {
    setState(() => _isLanguageLoading = true);

    try {
      final languages = await settingService.fetchLanguage();
      final currency = await settingService.fetchCurrency();
      final timezone = await settingService.fetchTimezones();

      if (languages != null && currency != null) {
        setState(() {
          _languages = List<Map<String, dynamic>>.from(languages);
          _currency = List<Map<String, dynamic>>.from(currency);
          _timezone = List<Map<String, dynamic>>.from(timezone);
        });
      }
    } catch (e) {
    } finally {
      setState(() => _isLanguageLoading = false);
    }
  }

  /// Calculates total size of temporary (cache) directory in bytes
  Future<int> getCacheSize() async {
    Directory cacheDir = await getTemporaryDirectory();
    return _getTotalSizeOfFilesInDir(cacheDir);
  }

  /// Recursively computes size of directory or file
  Future<int> _getTotalSizeOfFilesInDir(final FileSystemEntity file) async {
    if (file is File) {
      return await file.length();
    }
    if (file is Directory) {
      final List<FileSystemEntity> children = file.listSync();
      int total = 0;
      for (final child in children) {
        total += await _getTotalSizeOfFilesInDir(child);
      }
      return total;
    }
    return 0;
  }

  /// Deletes all files in the temporary cache directory
  Future<void> clearCache() async {
    Directory cacheDir = await getTemporaryDirectory();
    await _deleteDir(cacheDir);
  }

  /// Recursively deletes directory contents and then the directory itself
  Future<void> _deleteDir(FileSystemEntity file) async {
    if (file is Directory) {
      final List<FileSystemEntity> children = file.listSync();
      for (final child in children) {
        await _deleteDir(child);
      }
    }
    try {
      await file.delete();
    } catch (_) {}
  }

  /// Launches URL in external browser; throws if cannot launch
  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    final translationService = context.read<LanguageProvider>();
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.themeMode == ThemeMode.dark;
    final currencyDisplayKey = 'full_name';

    // Remove duplicate currency names (some currencies appear multiple times)
    final uniqueCurrencyItems = _currency
        .map((e) => e[currencyDisplayKey].toString())
        .toSet()
        .map((e) => {currencyDisplayKey: e})
        .toList();
    return Scaffold(
      backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
      appBar: AppBar(
        backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
        leading: IconButton(
          icon: Icon(
            HugeIcons.strokeRoundedArrowLeft01,
            color: isDark ? Colors.white : Colors.black,
            size: 28,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: tr(
          'Settings',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        automaticallyImplyLeading: false,
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ────────────────────────────────────────────────
              // Appearance Section
              // ────────────────────────────────────────────────
              Container(
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[850] : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? Colors.black.withOpacity(0.18)
                          : Colors.black.withOpacity(0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      tr(
                        'Appearance',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 18,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.dark_mode_outlined,
                              color: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  tr(
                                    'Dark Mode',
                                    style: TextStyle(
                                      fontWeight: FontWeight.normal,
                                      fontSize: 15,
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black,
                                    ),
                                  ),
                                  tr(
                                    'Switch between light and dark themes',
                                    style: TextStyle(
                                      fontWeight: FontWeight.normal,
                                      color: isDark
                                          ? Colors.grey[400]!
                                          : Colors.grey[600]!,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            FlutterSwitch(
                              width: 60,
                              activeColor: isDark
                                  ? Colors.grey[400]!
                                  : const Color(0xFFC03355),
                              inactiveColor: isDark
                                  ? Colors.black
                                  : Colors.white,
                              value: isDark,
                              onToggle: (value) async {
                                themeProvider.toggleTheme();
                                await settingsStorageService.setBool(
                                  'darkMode',
                                  value,
                                );
                              },
                              activeToggleColor: isDark
                                  ? Colors.black
                                  : Colors.white,
                              inactiveToggleColor: isDark
                                  ? Colors.grey[400]!
                                  : const Color(0xFFC03355),
                              showOnOff: false,
                              switchBorder: Border.all(
                                color: isDark
                                    ? Colors.grey[400]!
                                    : const Color(0xFFC03355),
                                width: 1.5,
                              ),
                              borderRadius: 30.0,
                            ),
                          ],
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.visibility_off,
                              color: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  tr(
                                    'Reduce Motion',
                                    style: TextStyle(
                                      fontWeight: FontWeight.normal,
                                      fontSize: 15,
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black,
                                    ),
                                  ),
                                  tr(
                                    'Minimize animations and motion effect',
                                    style: TextStyle(
                                      fontWeight: FontWeight.normal,
                                      color: isDark
                                          ? Colors.grey[400]!
                                          : Colors.grey[600]!,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            FlutterSwitch(
                              width: 60,
                              activeColor: isDark
                                  ? Colors.grey[400]!
                                  : const Color(0xFFC03355),
                              inactiveColor: isDark
                                  ? Colors.black
                                  : Colors.white,
                              value: Provider.of<MotionProvider>(
                                context,
                              ).reduceMotion,
                              onToggle: (val) async {
                                Provider.of<MotionProvider>(
                                  context,
                                  listen: false,
                                ).setReduceMotion(val);
                                await settingsStorageService.setBool(
                                  'reduceMotion',
                                  val,
                                );
                              },
                              activeToggleColor: isDark
                                  ? Colors.black
                                  : Colors.white,
                              inactiveToggleColor: isDark
                                  ? Colors.grey[400]!
                                  : const Color(0xFFC03355),
                              showOnOff: false,
                              switchBorder: Border.all(
                                color: isDark
                                    ? Colors.grey[400]!
                                    : const Color(0xFFC03355).withOpacity(0.7),
                                width: 1.5,
                              ),
                              borderRadius: 30.0,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ────────────────────────────────────────────────
              // Security Section
              // ────────────────────────────────────────────────
              Container(
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[850] : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? Colors.black.withOpacity(0.18)
                          : Colors.black.withOpacity(0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      tr(
                        'Security',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 18,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Icon(
                              HugeIcons.strokeRoundedFingerprintScan,
                              color: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  tr(
                                    'App Lock',
                                    style: TextStyle(
                                      fontWeight: FontWeight.normal,
                                      fontSize: 15,
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black,
                                    ),
                                  ),
                                  tr(
                                    'Enable biometric lock to keep your app secure.',
                                    softWrap: true,
                                    overflow: TextOverflow.visible,
                                    style: TextStyle(
                                      fontWeight: FontWeight.normal,
                                      color: isDark
                                          ? Colors.grey[400]!
                                          : Colors.grey[600]!,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: 10),
                            FlutterSwitch(
                              width: 60,
                              activeColor: isDark
                                  ? Colors.grey[400]!
                                  : const Color(0xFFC03355),
                              inactiveColor: isDark
                                  ? Colors.black
                                  : Colors.white,
                              value: _biometricEnabled,
                              onToggle: (val) async {
                                await _toggleBiometric(val);
                              },
                              activeToggleColor: isDark
                                  ? Colors.black
                                  : Colors.white,
                              inactiveToggleColor: isDark
                                  ? Colors.grey[400]!
                                  : const Color(0xFFC03355),
                              showOnOff: false,
                              switchBorder: Border.all(
                                color: isDark
                                    ? Colors.grey[400]!
                                    : const Color(0xFFC03355).withOpacity(0.7),
                                width: 1.5,
                              ),
                              borderRadius: 30.0,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ────────────────────────────────────────────────
              // Language & Region Section
              // ────────────────────────────────────────────────
              Container(
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[850] : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? Colors.black.withOpacity(0.18)
                          : Colors.black.withOpacity(0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: tr(
                              'Language & Region',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 18,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.refresh,
                              color: isDark
                                  ? Colors.grey[300]
                                  : Colors.grey[600],
                              size: 20,
                            ),
                            onPressed: () async {
                              setState(() => _isLanguageLoading = true);
                              try {
                                final settingService = SettingService();
                                await loadLanguageAndRegion(settingService);
                                setState(() {
                                  language =
                                      settingsStorageService.getString(
                                        'language',
                                      ) ??
                                      language;
                                  currency =
                                      settingsStorageService.getString(
                                        'currency',
                                      ) ??
                                      currency;
                                  timezone =
                                      settingsStorageService.getString(
                                        'timezone',
                                      ) ??
                                      timezone;
                                });
                                CustomSnackbar.showSuccess(
                                  context,
                                  'Language & Region refreshed',
                                );
                              } catch (e) {
                                CustomSnackbar.showError(
                                  context,
                                  "Something went wrong please try again later",
                                );
                              } finally {
                                setState(() => _isLanguageLoading = false);
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildDropdownTile(
                        icon: HugeIcons.strokeRoundedTranslate,
                        title: 'Language',
                        subtitle: 'Select your preferred language',
                        value: language,
                        items: _languages,
                        displayKey: 'name',
                        onChanged: (selectedName) async {
                          setState(() {
                            _isLanguageChanged = true;
                          });
                          if (selectedName != null) {
                            try {
                              final selectedLang = _languages.firstWhere(
                                (lang) => lang['name'] == selectedName,
                                orElse: () => {},
                              );

                              if (selectedLang != {}) {
                                final selectedCode = selectedLang['code'];
                                setState(() => language = selectedName);
                                await settingsStorageService.setString(
                                  'language',
                                  selectedName,
                                );
                                final ts = context.read<LanguageProvider>();
                                await ts.initializeTranslator(selectedCode);

                                setState(() {});

                                final updatedValue = {
                                  'lang': selectedCode,
                                  'tz': timezone,
                                };
                                final settingService = SettingService();
                                await settingService.updateLanguage(
                                  userId!,
                                  updatedValue,
                                );
                                await settingsStorageService.setString(
                                  'languageCode',
                                  selectedCode,
                                );

                                final translationService = context
                                    .read<LanguageProvider>();
                                translationService.clearCache();

                                await translationService.initializeTranslator(
                                  selectedCode,
                                );
                                if (!settingsStorageService.exists(
                                  'translation_cache_$languageCode',
                                )) {
                                  await translationService.preload(
                                    TranslationStrings.preloadKeys,
                                  );
                                }
                                translationService.notifyListeners();

                                if (mounted) {
                                  CustomSnackbar.showSuccess(
                                    context,
                                    'Language updated successfully',
                                  );
                                  _isLanguageChanged = false;
                                }
                              }
                            } catch (e) {
                              if (mounted) {
                                CustomSnackbar.showError(
                                  context,
                                  'Failed to update language. Please try again later.',
                                );
                                _isLanguageChanged = false;
                              }
                            }
                          }
                        },
                      ),

                      _buildDropdownTile(
                        icon: HugeIcons.strokeRoundedDollar01,
                        title: 'Currency',
                        subtitle: 'Default currency for transactions',
                        value: currency,
                        items: uniqueCurrencyItems,
                        displayKey: 'full_name',
                        onChanged: (selected) async {
                          if (selected != null) {
                            try {
                              setState(() => currency = selected);
                              await settingsStorageService.setString(
                                'currency',
                                selected,
                              );

                              if (mounted) {
                                CustomSnackbar.showSuccess(
                                  context,
                                  'Currency updated successfully',
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                CustomSnackbar.showError(
                                  context,
                                  'Failed to update currency. Please try again later.',
                                );
                              }
                            }
                          }
                        },
                      ),

                      _buildDropdownTile(
                        icon: HugeIcons.strokeRoundedClock01,
                        title: 'Timezone',
                        subtitle: 'Your local timezone',
                        value: timezone,
                        items: _timezone,
                        displayKey: 'name',
                        onChanged: (selectedName) async {
                          if (selectedName != null) {
                            try {
                              final selectedTz = _timezone.firstWhere(
                                (tz) => tz['name'] == selectedName,
                                orElse: () => {},
                              );

                              if (selectedTz != {}) {
                                final selectedCode = selectedTz['code'];
                                setState(() => timezone = selectedName);
                                await settingsStorageService.setString(
                                  'timezone',
                                  selectedName,
                                );

                                final updatedValue = {
                                  'lang': languageCode,
                                  'tz': selectedCode,
                                };
                                final settingService = SettingService();

                                await settingService.updateLanguage(
                                  userId!,
                                  updatedValue,
                                );
                                if (mounted) {
                                  CustomSnackbar.showSuccess(
                                    context,
                                    'Timezone updated successfully',
                                  );
                                }
                              }
                            } catch (e) {
                              if (mounted) {
                                CustomSnackbar.showError(
                                  context,
                                  'Failed to update language. Please try again later.',
                                );
                              }
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // ────────────────────────────────────────────────
              // Data & Storage
              // ────────────────────────────────────────────────
              Container(
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[850] : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? Colors.black.withOpacity(0.18)
                          : Colors.black.withOpacity(0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      tr(
                        'Data & Storage',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 18,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      ListTile(
                        leading: Icon(
                          Icons.delete_sweep_outlined,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                        title: tr(
                          'Clear Cache',
                          style: TextStyle(
                            fontWeight: FontWeight.normal,
                            fontSize: 15,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        subtitle: FutureBuilder<int>(
                          future: getCacheSize(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) return tr('Calculating...');
                            final sizeInMB = (snapshot.data! / (1024 * 1024))
                                .toStringAsFixed(2);
                            final cachedText =
                                translationService.getCached(
                                  "MB • Free up space by clearing temporary data",
                                ) ??
                                "MB • Free up space by clearing temporary data";

                            final text = (sizeInMB == '0.00')
                                ? translationService.getCached(
                                        'No cache data',
                                      ) ??
                                      'No cache data'
                                : '$sizeInMB $cachedText';

                            return tr(
                              text,
                              style: TextStyle(
                                fontWeight: FontWeight.normal,
                                color: isDark
                                    ? Colors.grey[400]!
                                    : Colors.grey[600]!,
                              ),
                            );
                          },
                        ),
                        onTap: () async {
                          await clearCache();
                          setState(() {});
                          CustomSnackbar.showSuccess(
                            context,
                            "Cache cleared successfully",
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // ────────────────────────────────────────────────
              // Help & Support
              // ────────────────────────────────────────────────
              Container(
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[850] : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? Colors.black.withOpacity(0.18)
                          : Colors.black.withOpacity(0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      tr(
                        'Help & Support',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 18,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      ListTile(
                        leading: Icon(
                          HugeIcons.strokeRoundedHelpCircle,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                        title: tr(
                          'Odoo Help Center',
                          style: TextStyle(
                            fontWeight: FontWeight.normal,
                            fontSize: 15,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        subtitle: tr(
                          'Documentation, guides and resources',
                          style: TextStyle(
                            fontWeight: FontWeight.normal,
                            color: isDark
                                ? Colors.grey[400]!
                                : Colors.grey[600]!,
                          ),
                        ),
                        onTap: () =>
                            _launchUrl("https://www.odoo.com/documentation"),
                      ),
                      ListTile(
                        leading: Icon(
                          HugeIcons.strokeRoundedCustomerSupport,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                        title: tr(
                          'Odoo Support',
                          style: TextStyle(
                            fontWeight: FontWeight.normal,
                            fontSize: 15,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        subtitle: tr(
                          'Create a ticket with Odoo Support',
                          style: TextStyle(
                            fontWeight: FontWeight.normal,
                            color: isDark
                                ? Colors.grey[400]!
                                : Colors.grey[600]!,
                          ),
                        ),
                        onTap: () => _launchUrl("https://www.odoo.com/help"),
                      ),
                      ListTile(
                        leading: Icon(
                          HugeIcons.strokeRoundedUserGroup,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                        title: tr(
                          'Odoo Community Forum',
                          style: TextStyle(
                            fontWeight: FontWeight.normal,
                            fontSize: 15,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        subtitle: tr(
                          'Ask the community for help',
                          style: TextStyle(
                            fontWeight: FontWeight.normal,
                            color: isDark
                                ? Colors.grey[400]!
                                : Colors.grey[600]!,
                          ),
                        ),
                        onTap: () =>
                            _launchUrl("https://www.odoo.com/forum/help-1"),
                      ),
                    ],
                  ),
                ),
              ),

              // ────────────────────────────────────────────────
              // About Section (company info, social links)
              // ────────────────────────────────────────────────
              Container(
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[850] : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? Colors.black.withOpacity(0.18)
                          : Colors.black.withOpacity(0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      tr(
                        'About',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 18,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      ListTile(
                        leading: Icon(
                          HugeIcons.strokeRoundedGlobe02,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                        title: tr(
                          'Visit Website',
                          style: TextStyle(
                            fontWeight: FontWeight.normal,
                            fontSize: 15,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        subtitle: Text(
                          'www.cybrosys.com',
                          style: TextStyle(
                            fontWeight: FontWeight.normal,
                            color: isDark
                                ? Colors.grey[400]!
                                : Colors.grey[600]!,
                          ),
                        ),
                        onTap: () => _launchUrl("https://www.cybrosys.com"),
                      ),
                      ListTile(
                        leading: Icon(
                          HugeIcons.strokeRoundedMail01,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                        title: tr(
                          'Contact Us',
                          style: TextStyle(
                            fontWeight: FontWeight.normal,
                            fontSize: 15,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        subtitle: Text(
                          'info@cybrosys.com',
                          style: TextStyle(
                            fontWeight: FontWeight.normal,
                            color: isDark
                                ? Colors.grey[400]!
                                : Colors.grey[600]!,
                          ),
                        ),
                        onTap: () => _launchUrl("mailto:info@cybrosys.com"),
                      ),
                      ListTile(
                        leading: Icon(
                          Icons.apps,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                        title: tr(
                          'More Apps',
                          style: TextStyle(
                            fontWeight: FontWeight.normal,
                            fontSize: 15,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        subtitle: tr(
                          'View our other apps on Play Store',
                          style: TextStyle(
                            fontWeight: FontWeight.normal,
                            color: isDark
                                ? Colors.grey[400]!
                                : Colors.grey[600]!,
                          ),
                        ),
                        onTap: () => _launchUrl(
                          "https://play.google.com/store/apps/developer?id=Cybrosys",
                        ),
                      ),
                      const SizedBox(height: 12),
                      Divider(
                        color: isDark ? Colors.grey[800] : Colors.grey[200],
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: tr(
                          'Follow Us',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 18,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildSocialButton(
                            context,
                            'assets/facebook.png',
                            const Color(0xFF1877F2),
                            () => _launchUrlSmart(
                              'https://www.facebook.com/cybrosystechnologies',
                              title: 'Facebook',
                            ),
                          ),
                          _buildSocialButton(
                            context,
                            'assets/linkedin.png',
                            const Color(0xFF0077B5),
                            () => _launchUrlSmart(
                              'https://www.linkedin.com/company/cybrosys/',
                              title: 'LinkedIn',
                            ),
                          ),
                          _buildSocialButton(
                            context,
                            'assets/instagram.png',
                            const Color(0xFFE4405F),
                            () => _launchUrlSmart(
                              'https://www.instagram.com/cybrosystech/',
                              title: 'Instagram',
                            ),
                          ),
                          _buildSocialButton(
                            context,
                            'assets/youtube.png',
                            const Color(0xFFFF0000),
                            () => _launchUrlSmart(
                              'https://www.youtube.com/channel/UCKjWLm7iCyOYINVspCSanjg',
                              title: 'YouTube',
                            ),
                          ),
                          const Divider(height: 32),
                        ],
                      ),

                      const SizedBox(height: 20),
                      Center(
                        child: Text(
                          '© ${DateTime.now().year} Cybrosys Technologies',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? Colors.white
                                : AppStyle.primaryColor,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_isLanguageChanged)
            Center(
              child: LoadingAnimationWidget.threeArchedCircle(
                color: isDark ? Colors.white : AppStyle.primaryColor,
                size: 40,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSocialButton(
    BuildContext context,
    String assetPath,
    Color underlineColor,
    VoidCallback onPressed,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(.2) : Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: IconButton(
            onPressed: onPressed,
            icon: Image.asset(
              assetPath,
              width: 24,
              height: 24,
              color: isDark ? Colors.white : null,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 48,
          height: 3,
          decoration: BoxDecoration(
            color: underlineColor,
            borderRadius: BorderRadius.circular(1.5),
          ),
        ),
      ],
    );
  }

  Future<void> _launchUrlSmart(String url, {String? title}) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _openInAppWebPage(uri, title: title);
    }
  }

  Future<void> _openInAppWebPage(Uri url, {String? title}) async {
    final motionProvider = Provider.of<MotionProvider>(context, listen: false);

    if (!mounted) return;
    try {
      Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              InAppWebPage(url: url, title: title),
          transitionDuration: motionProvider.reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 300),
          reverseTransitionDuration: motionProvider.reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 300),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            if (motionProvider.reduceMotion) return child;
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    } catch (e) {
      if (!mounted) return;
      CustomSnackbar.showError(context, "Could not open page, Try again later");
    }
  }

  Widget _buildDropdownTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required String? value,
    required List<Map<String, dynamic>> items,
    required String displayKey,
    required ValueChanged<String?> onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
      leading: Icon(icon, color: isDark ? Colors.grey[400] : Colors.grey[600]),
      title: tr(
        title,
        style: TextStyle(
          fontWeight: FontWeight.normal,
          fontSize: 15,
          color: isDark ? Colors.white : Colors.black,
        ),
      ),
      subtitle: tr(
        subtitle,
        style: TextStyle(
          fontWeight: FontWeight.normal,
          color: isDark ? Colors.grey[400]! : Colors.grey[600]!,
        ),
      ),
      trailing: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 120),
        child: Stack(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.1)
                    : Colors.grey[200],
                borderRadius: BorderRadius.circular(6),
              ),
              child: DropdownButton<String>(
                value: value,
                items: items.map((item) {
                  final itemValue = item[displayKey].toString();
                  return DropdownMenuItem<String>(
                    value: itemValue,
                    child: Text(
                      itemValue,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontSize: 12,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: onChanged,
                underline: const SizedBox(),
                dropdownColor: isDark ? Color(0xFF1F1F1F) : Colors.white,
                isDense: true,
                isExpanded: true,
              ),
            ),
            if (_isLanguageLoading)
              Center(
                child: LoadingAnimationWidget.threeArchedCircle(
                  color: isDark ? Colors.white : AppStyle.primaryColor,
                  size: 20,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
