import 'dart:convert';
import 'dart:io' show ContentType, HttpClient, HttpHeaders;

import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../CommonWidgets/core/company/session/company_session_manager.dart';
import '../../../CommonWidgets/core/language/translate_widget.dart';
import '../../../CommonWidgets/core/providers/language_provider.dart';
import '../../../CommonWidgets/core/security/secure_storage_service.dart';
import '../../../CommonWidgets/globals.dart';
import '../../../MainScreens/AppBars/pages/common_app_bar.dart';
import '../../../MainScreens/AppBars/services/app_bootstrapper.dart';
import '../../../MainScreens/AppBars/services/common_storage_service.dart';
import '../../../Profile/configuration/services/app_shutdown_manager.dart';
import '../services/app_install_check.dart';
import '../services/storage_service.dart';

/// TotpPage handles Two-Factor Authentication (TOTP) verification flow.
///
/// Responsibilities:
/// - Load Odoo login page inside hidden WebView
/// - Inject credentials automatically
/// - Accept user TOTP input
/// - Submit TOTP via DOM injection
/// - Extract session cookies after successful login
/// - Save session + account data locally
/// - Navigate to dashboard after verification
class TotpPage extends StatefulWidget {
  final String serverUrl;
  final String database;
  final String username;
  final String password;
  final String protocol;

  /// Whether this TOTP verification is happening as part of adding a
  /// second account (from [ServerUrlScreen]/[SwitchCredentialsScreen])
  /// rather than the regular, single-account sign-in flow. This changes
  /// where a "module missing" failure sends the user back to, and
  /// whether the currently logged-in account gets wiped on that failure.
  final bool isAddingAccount;

  const TotpPage({
    super.key,
    required this.serverUrl,
    required this.database,
    required this.username,
    required this.password,
    required this.protocol,
    this.isAddingAccount = false,
  });

  @override
  State<TotpPage> createState() => _TotpPageState();
}

class _TotpPageState extends State<TotpPage> {
  /// Hidden WebView controller used for login automation.
  InAppWebViewController? _webController;

  /// Controller for TOTP input field.
  final _totpController = TextEditingController();

  /// Current error message displayed in UI.
  String? _error;

  /// Indicates whether WebView login process is still loading.
  bool _loading = true;

  /// Indicates whether TOTP verification is currently running.
  bool _verifying = false;

  /// Controls TOTP submit button state.
  bool _isButtonEnabled = false;

  /// Form validation key.
  final _formKey = GlobalKey<FormState>();

  /// Prevents multiple credential injections.
  bool _credentialsInjected = false;

  /// Active session ID extracted from cookies.
  String? sessionId;

  /// Storage service for saving multi-account data.
  final CommonStorageService _commonStorageService = CommonStorageService();

  /// Whether the WebView's cookie jar has been cleared and it's safe to
  /// start loading the login page.
  bool _webviewReady = false;

  /// Some callers (e.g. the "Add Account" flow) pass [serverUrl] without
  /// its protocol already stripped out, relying on [protocol] separately;
  /// others pass the full URL. Normalize so every use below is consistent
  /// regardless of which convention the caller used.
  String get _fullServerUrl {
    final trimmed = widget.serverUrl.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    return '${widget.protocol}$trimmed';
  }

  /// Whether an existing logged-in session was found and snapshotted when
  /// this screen opened (only relevant for [TotpPage.isAddingAccount]).
  bool _hadPreviousSession = false;

  /// Snapshot of the session-related SharedPreferences entries that were
  /// active before this add-account attempt started, so they can be
  /// restored if the new account turns out to be missing a required
  /// module — without this, the currently logged-in account would be
  /// silently replaced by the failed one.
  final Map<String, Object?> _previousPrefsSnapshot = {};

  static const _sessionPrefKeys = [
    'url',
    'database',
    'sessionId',
    'userName',
    'userLogin',
    'userId',
    'serverVersion',
    'userLang',
    'partnerId',
    'userTimezone',
    'companyId',
    'company_name',
    'isSystem',
    'version',
    'allowed_company_ids',
    'isLoggedIn',
  ];

  @override
  void initState() {
    super.initState();
    _snapshotPreviousSession();
    _startHttpLogin();
    Future.delayed(const Duration(seconds: 25), () {
      _showLoadFailure(
        'Verification page did not open. Please go back and try again.',
      );
    });
  }

  /// Captures whatever account was active before this add-account attempt,
  /// so it can be restored if the attempt fails. A no-op for the regular
  /// (non-add-account) sign-in flow, since there's nothing to preserve.
  Future<void> _snapshotPreviousSession() async {
    if (!widget.isAddingAccount) return;
    final prefs = await SharedPreferences.getInstance();
    _hadPreviousSession = prefs.getBool('isLoggedIn') ?? false;
    if (!_hadPreviousSession) return;
    for (final key in _sessionPrefKeys) {
      _previousPrefsSnapshot[key] = prefs.get(key);
    }
  }

  /// Writes the snapshotted previous session back to SharedPreferences and
  /// refreshes [CompanySessionManager]'s cache to match, undoing the
  /// overwrite that the failed add-account attempt made.
  Future<void> _restorePreviousSession() async {
    if (!_hadPreviousSession) return;
    final prefs = await SharedPreferences.getInstance();
    for (final entry in _previousPrefsSnapshot.entries) {
      final value = entry.value;
      if (value == null) {
        await prefs.remove(entry.key);
      } else if (value is String) {
        await prefs.setString(entry.key, value);
      } else if (value is int) {
        await prefs.setInt(entry.key, value);
      } else if (value is bool) {
        await prefs.setBool(entry.key, value);
      } else if (value is double) {
        await prefs.setDouble(entry.key, value);
      } else if (value is List<String>) {
        await prefs.setStringList(entry.key, value);
      }
    }
    await CompanySessionManager.clearSessionCache();
    await CompanySessionManager.forceRefreshFromPrefs();
  }


  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Center(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[950] : Colors.grey[50],
                  image: DecorationImage(
                    image: const AssetImage('assets/background.png'),
                    fit: BoxFit.cover,
                    colorFilter: ColorFilter.mode(
                      isDark
                          ? Colors.black.withOpacity(1)
                          : Colors.white.withOpacity(1),
                      BlendMode.dstATop,
                    ),
                  ),
                ),
              ),
            ),
          ),

          if (_webviewReady)
            Positioned.fill(
              child: Opacity(
                opacity: 0.0,
                child: InAppWebView(
                initialUrlRequest: URLRequest(
                  url: WebUri(
                    '$_fullServerUrl/web/login?db=${widget.database}',
                  ),
                  // Skips the ngrok-free "visit site" interstitial, which
                  // otherwise replaces the Odoo login page entirely.
                  headers: {'ngrok-skip-browser-warning': 'true'},
                ),
                initialOptions: InAppWebViewGroupOptions(
                  crossPlatform: InAppWebViewOptions(
                    javaScriptEnabled: true,
                    cacheEnabled: false,
                    clearCache: true,
                    // ngrok only shows its browser-warning interstitial for
                    // browser-like user agents; a custom one avoids it on
                    // every request (form POSTs and redirects included).
                    userAgent: "MoboAttendanceApp/1.0 (iOS; Odoo mobile)",
                  ),
                  android: AndroidInAppWebViewOptions(
                    useHybridComposition: true,
                    allowContentAccess: true,
                    allowFileAccess: true,
                    mixedContentMode:
                        AndroidMixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
                    forceDark: AndroidForceDark.FORCE_DARK_AUTO,
                    disableDefaultErrorPage: true,
                  ),
                ),
                onWebViewCreated: (controller) {
                  _webController = controller;
                },
                onReceivedServerTrustAuthRequest:
                    (controller, challenge) async {
                      return ServerTrustAuthResponse(
                        action: ServerTrustAuthResponseAction.PROCEED,
                      );
                    },

                shouldOverrideUrlLoading: (controller, navigationAction) async {
                  return NavigationActionPolicy.ALLOW;
                },

                onLoadError: (controller, url, code, message) {
                  _showLoadFailure();
                },

                onReceivedError: (controller, request, error) {
                  if (request.isForMainFrame ?? true) _showLoadFailure();
                },

                onReceivedHttpError: (controller, request, errorResponse) {
                  if (request.isForMainFrame ?? true) _showLoadFailure();
                },
                onLoadStop: (controller, url) async {
                  final urlStr = url?.toString() ?? '';
                  debugPrint('[TOTP] onLoadStop $urlStr');

                  if (urlStr.contains('/web/database/selector') ||
                      urlStr.contains('/web/database/manager')) {
                    await _handleDatabaseSelector();
                    return;
                  }

                  if (urlStr.contains('/web/login') && !_credentialsInjected) {
                    await Future.delayed(const Duration(milliseconds: 800));
                    await _injectCredentials();
                    return;
                  }

                  if (urlStr.contains('/web/login/totp') ||
                      urlStr.contains('totp_token') ||
                      await _hasTotpInput()) {
                    if (mounted) {
                      setState(() {
                        _loading = false;
                      });
                    }
                    await Future.delayed(const Duration(milliseconds: 600));
                    await _focusTotpField();
                    return;
                  }

                  // Any URL past the login/totp challenge means the user is
                  // authenticated — this covers backend users (redirected to
                  // /web or /odoo) as well as portal users (redirected to
                  // /my, which never matches a backend-only URL whitelist).
                  if (urlStr.isNotEmpty &&
                      !urlStr.contains('/login') &&
                      !urlStr.contains('/totp') &&
                      !urlStr.contains('/web/database')) {
                    await _extractAndSaveSession();
                  }
                },
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            child: SafeArea(
              bottom: false,
              child: IgnorePointer(
                ignoring: _loading,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(32),
                    child: Container(
                      height: 64,
                      width: 64,
                      alignment: Alignment.center,
                      child: Icon(
                        HugeIcons.strokeRoundedArrowLeft01,
                        color: _loading ? Colors.white54 : Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildHeader(),
                const SizedBox(height: 20),
                _buildForm(),
              ],
            ),
          ),

          if (_loading)
            Container(
              color: isDark ? Colors.black54 : Colors.white70,
              child: Center(
                child: LoadingAnimationWidget.fourRotatingDots(
                  color: Theme.of(context).colorScheme.primary,
                  size: 60,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Shows dialog when required backend module is missing.
  ///
  /// Used when mandatory modules like Attendance are not installed.
  void showModuleMissingDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titlePadding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        title: Row(
          children: [
            const HugeIcon(
              icon: HugeIcons.strokeRoundedAlertCircle,
              color: AppStyle.primaryColor,
              size: 24,
            ),
            const SizedBox(width: 12),
            Text(
              'Module Missing',
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: Colors.black,
              ),
            ),
          ],
        ),
        content: Text(
          'The required "Attendance" module is not installed. Please contact your administrator to enable it.',
          style: GoogleFonts.manrope(
            fontSize: 15,
            color: Colors.black87,
            height: 1.5,
          ),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppStyle.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                widget.isAddingAccount ? 'Back to Add Account' : 'Back to Login',
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Validates and submits TOTP code to WebView login form.
  ///
  /// Flow:
  /// 1. Validate TOTP format
  /// 2. Inject TOTP into DOM
  /// 3. Submit login form
  /// 4. Monitor login success state
  /// 5. Extract session cookies
  /// 6. Save session + navigate
  Future<void> _submitTotp() async {
    if (_verifying || _totpCsrf == null) return;

    setState(() {
      _verifying = true;
      _error = null;
    });

    final totp = _totpController.text.trim();
    if (totp.length != 6 || !RegExp(r'^\d{6}$').hasMatch(totp)) {
      setState(() {
        _error = 'Please enter a valid 6-digit code';
        _verifying = false;
      });
      return;
    }

    try {
      final res = await _http('POST', '/web/login/totp', form: {
        'csrf_token': _totpCsrf!,
        'totp_token': totp,
        'redirect': '',
      });
      debugPrint(
        '[TOTP] totp POST -> ${res.status} location=${res.location} '
        'cookies=${_cookies.keys.toList()}',
      );

      final loggedIn =
          res.status >= 300 &&
          res.status < 400 &&
          !(res.location ?? '').contains('/login') &&
          !(res.location ?? '').contains('/totp');

      if (!loggedIn) {
        // Odoo re-renders the TOTP page with a new CSRF token on failure.
        final csrf = _extractCsrf(res.body);
        if (csrf != null) _totpCsrf = csrf;
        setState(() {
          _error = 'Invalid code. Please try again.';
        });
        return;
      }

      final sid = _cookies['session_id'];
      if (sid == null || sid.isEmpty) {
        setState(() => _error = 'Login failed. Please try again.');
        return;
      }
      sessionId = sid;

      final ok = await _saveSessionData();
      if (!ok) {
        setState(() {
          _error =
              _expiredMessage ?? 'Invalid code or login failed. Please try again.';
        });
        return;
      }

      await _finishLogin();
    } catch (e) {
      setState(() {
        _error = 'Authentication failed. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  /// Verifies required modules and opens the app (or backs out) after a
  /// successful login.
  Future<void> _finishLogin() async {
      if (mounted) {
        final checker = AppInstallCheck();
        final isInstalled = await checker.checkRequiredModules();

        if (!isInstalled) {
          if (widget.isAddingAccount) {
            // Only undo what this failed add-account attempt just wrote —
            // the account(s) already signed in must be left untouched.
            final failedSession = await CompanySessionManager.getCurrentSession();
            await StorageService().removeAccount(
              userLogin: failedSession?.userLogin ?? widget.username.trim(),
              userName: failedSession?.userName ?? '',
              userId: failedSession?.userId ?? 0,
              url: _fullServerUrl,
              database: widget.database,
            );
            await SecureStorageService().deletePassword(
              url: _fullServerUrl,
              database: widget.database,
              username: widget.username.trim(),
            );
            await _restorePreviousSession();

            if (mounted) {
              final navigator = Navigator.of(context);
              if (navigator.canPop()) navigator.pop();
              if (navigator.canPop()) navigator.pop();
              showModuleMissingDialog(context);
            }
            return;
          }

          final prefs = await SharedPreferences.getInstance();
          List<String> urlHistory = prefs.getStringList('urlHistory') ?? [];
          bool isGetStarted = prefs.getBool('hasSeenGetStarted') ?? false;

          await prefs.clear();

          await prefs.setStringList('urlHistory', urlHistory);
          await prefs.setBool('hasSeenGetStarted', isGetStarted);
          await StorageService().clearAccounts();
          await CompanySessionManager.clearSessionCache();
          await SecureStorageService().deleteAllPasswords();
          AppShutdownManager.resetAllBlocs();
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/login',
            (route) => false,
          );
          if (mounted) {
            showModuleMissingDialog(context);
          }
          return;
        } else {
          AppBootstrapper.reloadAppBlocs(context);
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => const CommonAppBar(),
              transitionDuration: const Duration(milliseconds: 300),
              transitionsBuilder: (_, a, __, c) =>
                  FadeTransition(opacity: a, child: c),
            ),
          );
        }
      }
  }


  /// Saves recently used server login history.
  ///
  /// Keeps last 10 entries for quick login selection.
  Future<void> _saveUrlHistory({
    required String protocol,
    required String url,
    required String database,
    required String username,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> history = prefs.getStringList('urlHistory') ?? [];

    String finalProtocol = protocol;
    String finalUrl = url.trim();

    if (finalUrl.startsWith('https://')) {
      finalProtocol = 'https://';
      finalUrl = finalUrl.replaceFirst('https://', '');
    } else if (finalUrl.startsWith('http://')) {
      finalProtocol = 'http://';
      finalUrl = finalUrl.replaceFirst('http://', '');
    }

    final entry = jsonEncode({
      'protocol': finalProtocol,
      'url': finalUrl,
      'db': database,
      'username': username,
    });

    history.removeWhere((e) {
      final d = jsonDecode(e);
      return d['url'] == finalUrl && d['protocol'] == finalProtocol;
    });

    history.insert(0, entry);
    await prefs.setStringList('urlHistory', history.take(10).toList());
  }

  /// Extracts session cookie from WebView and saves:
  /// - Session in CompanySessionManager
  /// - Account in local storage
  /// - Login metadata in SharedPreferences
  String? _expiredMessage;

  Future<bool> _saveSessionData() async {
    _expiredMessage = null;
    try {
      final sessionCookie = Cookie(name: 'session_id', value: sessionId ?? '');

      if (sessionCookie.value.isNotEmpty) {
        sessionId = sessionCookie.value;

        final success = await CompanySessionManager.loginAndSaveSession(
          serverUrl: _fullServerUrl,
          database: widget.database,
          userLogin: widget.username.trim(),
          password: widget.password.trim(),
          session_Id: sessionId,
        );
        await _saveUrlHistory(
          protocol: widget.protocol,
          url: _fullServerUrl,
          database: widget.database,
          username: widget.username.trim(),
        );
        if (!success) {
          return false;
        }
        final session = await CompanySessionManager.getCurrentSession();
        await _commonStorageService.saveAccount({
          'userName': session?.userName,
          'userLogin': session?.userLogin,
          'userId': session?.userId,
          'sessionId': session?.sessionId,
          'serverVersion': session?.serverVersion,
          'userLang': session?.userLang,
          'partnerId': session?.partnerId,
          'userTimezone': session?.userTimezone,
          'companyId': session?.companyId,
          'companyName': session?.companyName,
          'isSystem': session?.isSystem,
          'url': _fullServerUrl,
          'database': widget.database,
          'image': '',
        });

        // Store the password securely so a stale session can be silently
        // refreshed later without prompting the user to log in again.
        await SecureStorageService().savePassword(
          url: _fullServerUrl,
          database: widget.database,
          username: widget.username.trim(),
          password: widget.password.trim(),
        );

        final prefs = await SharedPreferences.getInstance();

        await prefs.remove('logoutAction');

        await prefs.setString('sessionId', sessionId!);
        await prefs.setString('username', widget.username);
        await prefs.setString('url', _fullServerUrl);
        await prefs.setString('database', widget.database);
        await prefs.setBool('logoutAction', false);
        await prefs.setBool('isLoggedIn', true);

        await prefs.setInt(
          'loginTimestamp',
          DateTime.now().millisecondsSinceEpoch,
        );
        return true;
      }
      return false;
    } on DatabaseExpiredException catch (e) {
      _expiredMessage = e.message;
      return false;
    } catch (e) {
      debugPrint('[TOTP] save session failed: $e');
      return false;
    }
  }

  /// Injects login credentials into Odoo login page DOM.
  ///
  /// Automatically fills:
  /// - Username
  /// - Password
  /// - Database
  /// Then triggers login submit.
  Future<void> _injectCredentials() async {
    if (_credentialsInjected) return;

    final safeUser = jsonEncode(widget.username);
    final safePass = jsonEncode(widget.password);
    final safeDb = jsonEncode(widget.database);

    // The form may render slightly after onLoadStop (Odoo 19/20 pages), so
    // retry a few times before giving up.
    for (var attempt = 0; attempt < 8 && mounted; attempt++) {
      final result = await _webController?.evaluateJavascript(
        source:
            """
      (function() {
        const login = document.querySelector('input[name="login"], #login, input[type="email"]');
        const password = document.querySelector('input[name="password"], #password');
        if (!login || !password) return "missing";
        const form = login.closest('form') || document.querySelector('form.oe_login_form, form[action*="/web/login"], form');
        if (!form) return "missing";

        const setVal = (el, v) => {
          const setter = Object.getOwnPropertyDescriptor(Object.getPrototypeOf(el), 'value');
          if (setter && setter.set) setter.set.call(el, v); else el.value = v;
          el.dispatchEvent(new Event('input', {bubbles: true}));
          el.dispatchEvent(new Event('change', {bubbles: true}));
        };
        setVal(login, $safeUser);
        setVal(password, $safePass);
        const db = document.querySelector('input[name="db"], select[name="db"]');
        if (db) setVal(db, $safeDb);

        const btn = form.querySelector('button[type="submit"], button.btn-primary, input[type="submit"]');
        if (btn) btn.click();
        else if (form.requestSubmit) form.requestSubmit();
        else form.submit();
        return "submitted";
      })();
    """,
      );
      debugPrint('[TOTP] inject attempt $attempt -> $result');
      if (result == "submitted") {
        _credentialsInjected = true;
        return;
      }
      await Future.delayed(const Duration(milliseconds: 700));
    }
    _showLoadFailure(
      'Could not find the login form on the server page (Odoo login page layout not recognised).',
    );
  }

  // ---------------------------------------------------------------------
  // Direct HTTP login (replaces the hidden WebView, which is unreliable on
  // iOS: it needs ATS exceptions, hits ngrok's interstitial and can't expose
  // HttpOnly cookies consistently).
  // ---------------------------------------------------------------------

  /// Session cookies collected across the login requests.
  final Map<String, String> _cookies = {};

  /// CSRF token of the TOTP form, needed to submit the code.
  String? _totpCsrf;

  HttpClient? _client;

  Future<_HttpResult> _http(
    String method,
    String path, {
    Map<String, String>? form,
  }) async {
    if (_client == null) {
      final c = HttpClient();
      c.badCertificateCallback = (_, __, ___) => true;
      c.connectionTimeout = const Duration(seconds: 20);
      c.userAgent = 'MoboAttendanceApp/1.0 (Odoo mobile)';
      _client = c;
    }

    var uri = path.startsWith('http')
        ? Uri.parse(path)
        : Uri.parse('$_fullServerUrl$path');
    var m = method;
    var body = form;

    // Follow redirects manually so cookies are carried along each hop.
    for (var hop = 0; hop < 8; hop++) {
      final req = await _client!.openUrl(m, uri);
      req.followRedirects = false;
      req.headers.set('ngrok-skip-browser-warning', 'true');
      if (_cookies.isNotEmpty) {
        req.headers.set(
          HttpHeaders.cookieHeader,
          _cookies.entries.map((e) => '${e.key}=${e.value}').join('; '),
        );
      }
      if (body != null) {
        req.headers.contentType = ContentType(
          'application',
          'x-www-form-urlencoded',
          charset: 'utf-8',
        );
        req.write(
          body.entries
              .map(
                (e) =>
                    '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}',
              )
              .join('&'),
        );
      }
      final resp = await req.close();
      final text = await resp.transform(utf8.decoder).join();
      for (final c in resp.cookies) {
        _cookies[c.name] = c.value;
      }
      final loc = resp.headers.value(HttpHeaders.locationHeader);
      debugPrint('[TOTP] $m $uri -> ${resp.statusCode} loc=$loc');

      // Odoo bounces /web/login to itself once to set the session cookie
      // (GET only); other redirects are returned to the caller as-is.
      final isRedirect = resp.statusCode >= 300 && resp.statusCode < 400;
      if (isRedirect && loc != null && m == 'GET') {
        final next = uri.resolve(loc);
        if (!next.path.contains('/login/totp') || hop > 0) {
          uri = next;
          continue;
        }
      }
      return _HttpResult(resp.statusCode, text, loc);
    }
    return _HttpResult(310, '', null);
  }

  String? _extractCsrf(String html) {
    final m = RegExp(
      r'name="csrf_token"[^>]*value="([^"]+)"|value="([^"]+)"[^>]*name="csrf_token"',
    ).firstMatch(html);
    return m?.group(1) ?? m?.group(2);
  }

  /// Runs login (username/password) and loads the TOTP form, so the screen
  /// only needs the six-digit code from the user.
  Future<void> _startHttpLogin() async {
    try {
      final login = await _http(
        'GET',
        '/web/login?db=${Uri.encodeQueryComponent(widget.database)}',
      );
      final csrf = _extractCsrf(login.body);
      if (csrf == null) {
        _showLoadFailure(
          'Could not read the server login page. Check the server URL.',
        );
        return;
      }

      final post = await _http('POST', '/web/login', form: {
        'csrf_token': csrf,
        'db': widget.database,
        'login': widget.username,
        'password': widget.password,
        'redirect': '',
        'type': 'password',
      });

      final loc = post.location ?? '';
      if (post.status < 300 || post.status >= 400) {
        _showLoadFailure('Login failed. Please go back and check your credentials.');
        return;
      }
      if (!loc.contains('/totp')) {
        // No 2FA step was required after all: session is already valid.
        sessionId = _cookies['session_id'];
        if (sessionId != null && await _saveSessionData()) {
          if (mounted) setState(() => _loading = false);
          await _finishLogin();
        } else {
          _showLoadFailure(_expiredMessage ?? 'Login failed. Please try again.');
        }
        return;
      }

      final totpPage = await _http('GET', loc.startsWith('http') ? loc : loc);
      final totpCsrf = _extractCsrf(totpPage.body);
      if (totpCsrf == null) {
        _showLoadFailure('Could not open the verification page on the server.');
        return;
      }
      _totpCsrf = totpCsrf;
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      debugPrint('[TOTP] http login failed: $e');
      _showLoadFailure();
    }
  }

  /// Stops the loading overlay and tells the user the server page could not
  /// be loaded (e.g. unreachable host or blocked cleartext HTTP), instead of
  /// spinning forever.
  void _showLoadFailure([String? message]) {
    if (!mounted || !_loading) return;
    setState(() {
      _loading = false;
      _error =
          message ??
          'Could not reach the server for verification. Check the URL and your network connection.';
    });
  }

  /// Whether the current WebView page contains the TOTP input, regardless of
  /// the URL Odoo used for it (it differs between Odoo versions).
  Future<bool> _hasTotpInput() async {
    try {
      final r = await _webController?.evaluateJavascript(
        source:
            "!!document.querySelector('input[name=\"totp_token\"], input[autocomplete=\"one-time-code\"]')",
      );
      return r == true;
    } catch (_) {
      return false;
    }
  }

  /// Focuses TOTP input field inside WebView page.
  Future<void> _focusTotpField() async {
    await _webController?.evaluateJavascript(
      source: """
      const input = document.querySelector('input[name="totp_token"], input[autocomplete="one-time-code"]');
      if (input) {
        input.focus();
        input.select();
      }
    """,
    );
  }

  /// Handles database selector page when multiple DBs exist.
  ///
  /// Auto-selects target database and submits form.
  Future<void> _handleDatabaseSelector() async {
    await _webController?.evaluateJavascript(
      source:
          """
      const select = document.querySelector('select[name="db"]');
      if (select) {
        select.value = '${widget.database}';
        const btn = document.querySelector('button[type="submit"]');
        if (btn) btn.click();
      }
    """,
    );
  }

  /// Waits until Odoo session_info becomes available.
  ///
  /// Used for confirming successful authentication.
  Future<Map<String, dynamic>?> waitForSessionInfo() async {
    for (int i = 0; i < 10; i++) {
      final result = await _webController!.evaluateJavascript(
        source: """
        (function () {
          if (window.odoo && odoo.session_info) {
            return odoo.session_info;
          }
          return null;
        })();
      """,
      );

      if (result != null) {
        return Map<String, dynamic>.from(result);
      }

      await Future.delayed(const Duration(milliseconds: 500));
    }
    return null;
  }

  /// Extracts session cookie after login redirect.
  ///
  /// Used as fallback session validation.
  Future<void> _extractAndSaveSession() async {
    final currentUrl = await _webController?.getUrl();
    if (currentUrl == null) return;

    final cookies = await CookieManager.instance().getCookies(url: currentUrl);
    final sessionCookie = cookies.firstWhere(
      (c) => c.name == 'session_id',
      orElse: () => Cookie(name: 'session_id', value: ''),
    );

    if (sessionCookie.value.isEmpty) {
      setState(() => _error = "Login failed. Please try again.");
      return;
    }
  }

  /// Builds TOTP page header UI.
  ///
  /// Shows:
  /// - 2FA icon
  /// - Title
  /// - Instructions
  /// - Server URL
  Widget _buildHeader() {
    return Column(
      children: [
        Icon(
          HugeIcons.strokeRoundedTwoFactorAccess,
          color: Colors.white,
          size: 48,
        ),
        const SizedBox(height: 24),
        tr(
          'Two-factor Authentication',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w600,
            color: Colors.white,
            fontSize: 25,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        tr(
          'To login, enter below the six-digit authentication code provided by your Authenticator app.',
          style: GoogleFonts.montserrat(
            fontSize: 14,
            color: Colors.white70,
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
        if (widget.serverUrl.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Server: ${widget.serverUrl}',
            style: GoogleFonts.manrope(
              fontSize: 12,
              color: Colors.white60,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  /// Builds TOTP input form.
  ///
  /// Includes:
  /// - TOTP field validation
  /// - Error display
  /// - Submit button with loading state
  Widget _buildForm() {
    final translationService = context.watch<LanguageProvider>();

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _totpController,
            keyboardType: TextInputType.number,
            enabled: !_loading || !_verifying,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return translationService.getCached('TOTP is required') ??
                    'TOTP is required';
              }
              return null;
            },
            onChanged: (value) {
              setState(() {
                _isButtonEnabled = value.trim().isNotEmpty;
                _formKey.currentState?.validate();
                if (_error != null) _error = null;
              });
            },
            cursorColor: Colors.black,
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Colors.black,
            ),
            decoration: InputDecoration(
              hintText:
                  translationService.getCached('Enter TOTP Code') ??
                  'Enter TOTP Code',
              hintStyle: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Colors.black.withOpacity(.4),
              ),
              prefixIcon: const Icon(HugeIcons.strokeRoundedSmsCode, size: 20),
              prefixIconColor: MaterialStateColor.resolveWith(
                (states) => states.contains(MaterialState.disabled)
                    ? Colors.black26
                    : Colors.black54,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
              errorStyle: const TextStyle(color: Colors.white),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.red[900]!, width: 1.0),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.white, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 10),

          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: _error != null ? 48 : 0,
            child: _error != null
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(
                          HugeIcons.strokeRoundedAlertCircle,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: tr(
                            _error!,
                            style: GoogleFonts.manrope(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : null,
          ),

          const SizedBox(height: 20),

          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: (_verifying || !_isButtonEnabled) ? null : _submitTotp,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _verifying
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        tr(
                          'Authenticating',
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 12),
                        LoadingAnimationWidget.staggeredDotsWave(
                          color: Colors.white,
                          size: 28,
                        ),
                      ],
                    )
                  : tr(
                      'Authenticate',
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _webController?.dispose();
    _totpController.dispose();
    super.dispose();
  }
}

class _HttpResult {
  final int status;
  final String body;
  final String? location;
  const _HttpResult(this.status, this.body, this.location);
}
