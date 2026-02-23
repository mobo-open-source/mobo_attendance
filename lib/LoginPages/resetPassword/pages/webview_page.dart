import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:hugeicons/hugeicons.dart';
import 'dart:async';

/// A reusable WebView screen.
///
/// Features:
/// - Loads and displays a web page from a given URL
/// - Shows loading progress indicator
/// - Handles page load errors
/// - Supports pull-to-refresh
/// - Supports back and forward navigation
/// - Handles Android back button navigation inside WebView
class WebViewPage extends StatefulWidget {
  final String url;
  final String title;

  const WebViewPage({super.key, required this.url, required this.title});

  @override
  State<WebViewPage> createState() => _WebViewPageState();
}

/// State for WebViewPage.
///
/// Handles:
/// - WebView controller initialization
/// - Page loading state and progress tracking
/// - Error handling UI
/// - Navigation controls (back / forward)
/// - Pull-to-refresh functionality
class _WebViewPageState extends State<WebViewPage> {
  late final WebViewController _controller;
  bool isLoading = true;
  String? _errorMessage;
  int _loadingProgress = 0;
  Completer<void>? _refreshCompleter;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  /// Initializes WebView controller and navigation listeners.
  ///
  /// Sets:
  /// - JavaScript mode
  /// - Page loading progress listener
  /// - Page start / finish callbacks
  /// - Error handling callback
  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            setState(() {
              _loadingProgress = progress;
            });
          },
          onPageStarted: (String url) {
            setState(() {
              isLoading = true;
              _errorMessage = null;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              isLoading = false;
            });
            _refreshCompleter?.complete();
            _refreshCompleter = null;
          },
          onWebResourceError: (WebResourceError error) {
            setState(() {
              isLoading = false;
              _errorMessage = 'Failed to load page: ${error.description}';
            });
            _refreshCompleter?.completeError(error);
            _refreshCompleter = null;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  /// Reloads the current web page.
  ///
  /// Resets:
  /// - Loading state
  /// - Error message
  void _refresh() {
    setState(() {
      isLoading = true;
      _errorMessage = null;
    });
    _controller.reload();
  }

  /// Navigates back in WebView history.
  ///
  /// If no WebView history exists, closes the screen.
  void _goBack() async {
    if (await _controller.canGoBack()) {
      _controller.goBack();
    } else {
      Navigator.pop(context);
    }
  }

  /// Navigates forward in WebView history if available.
  void _goForward() async {
    if (await _controller.canGoForward()) {
      _controller.goForward();
    }
  }

  /// Handles device back button press.
  ///
  /// Returns:
  /// - false → If WebView can go back (prevents screen pop)
  /// - true → If WebView cannot go back (allows screen pop)
  Future<bool> _handleWillPop() async {
    if (await _controller.canGoBack()) {
      _controller.goBack();
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return WillPopScope(
      onWillPop: _handleWillPop,
      child: Scaffold(
        backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
        appBar: AppBar(
          backgroundColor: isDark ? Colors.grey[850] : Colors.white,
          foregroundColor: isDark ? Colors.white : Colors.black,
          elevation: 0,
          systemOverlayStyle: isDark
              ? SystemUiOverlayStyle.light
              : SystemUiOverlayStyle.dark,
          leading: IconButton(
            onPressed: () async {
              if (await _controller.canGoBack()) {
                _controller.goBack();
              } else {
                if (mounted) Navigator.pop(context);
              }
            },
            icon: const Icon(HugeIcons.strokeRoundedArrowLeft01, size: 20),
          ),
          title: Text(
            widget.title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              )
          ),
          actions: [
            IconButton(
              onPressed: _goBack,
              icon: const Icon(HugeIcons.strokeRoundedArrowLeft02, size: 20),
              tooltip: 'Back',
            ),
            IconButton(
              onPressed: _goForward,
              icon: const Icon(HugeIcons.strokeRoundedArrowRight02, size: 20),
              tooltip: 'Forward',
            ),
          ],
        ),
        body: Column(
          children: [
            if (_errorMessage == null && _loadingProgress < 100)
              LinearProgressIndicator(
                value: _loadingProgress == 0 ? null : _loadingProgress / 100.0,
                minHeight: 3,
              ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  _refreshCompleter = Completer<void>();
                  _refresh();
                  try {
                    await _refreshCompleter!.future.timeout(
                      const Duration(seconds: 12),
                    );
                  } catch (_) {
                  } finally {
                    _refreshCompleter = null;
                  }
                },
                color: Theme.of(context).primaryColor,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: SizedBox(
                    height: MediaQuery.of(context).size.height,
                    child: _errorMessage != null
                        ? _buildErrorWidget()
                        : WebViewWidget(controller: _controller),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds error UI when WebView fails to load.
  ///
  /// Shows:
  /// - Error icon
  /// - Error title and message
  /// - Go back button
  /// - Retry button
  Widget _buildErrorWidget() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: const Icon(
                HugeIcons.strokeRoundedAlertCircle,
                color: Colors.red,
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Unable to Load Page',
              style: GoogleFonts.montserrat(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'An error occurred while loading the page.',
              style: GoogleFonts.montserrat(
                fontSize: 14,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(
                    HugeIcons.strokeRoundedArrowLeft01,
                    size: 16,
                  ),
                  label: Text(
                    'Go Back',
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? Colors.white : Colors.black,
                    side: BorderSide(
                      color: isDark ? Colors.grey[600]! : Colors.grey[300]!,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _refresh,
                  icon: const Icon(HugeIcons.strokeRoundedRefresh, size: 16),
                  label: Text(
                    'Try Again',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
