import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../CommonWidgets/shared/widgets/snackbar.dart';

/// A full-screen in-app browser page that displays web content using [WebViewWidget].
///
/// Features:
///   • Loads the provided [url] with JavaScript enabled
///   • Shows a loading indicator while the page is loading
///   • Displays error snackbar on load failure
///   • Custom app bar with back button and optional title
///   • Dark/light theme aware colors
///
/// Typically used when external links should open inside the app rather than
/// launching the system browser (e.g. from settings "Help & Support" or social links).
class InAppWebPage extends StatefulWidget {
  final Uri url;
  final String? title;

  const InAppWebPage({super.key, required this.url, this.title});

  @override
  State<InAppWebPage> createState() => _InAppWebPageState();
}

class _InAppWebPageState extends State<InAppWebPage> {
  /// Tracks whether the initial page load is still in progress
  bool isLoading = true;

  /// Controller for managing the WebView (load, navigation, JS, etc.)
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      // Allow JavaScript execution (required for most modern websites)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      // Start loading the target URL
      ..loadRequest(widget.url)
      // Handle navigation events
      ..setNavigationDelegate(
        NavigationDelegate(
          // Called when page has finished loading successfully
          onPageFinished: (_) {
            if (mounted) setState(() => isLoading = false);
          },
          // Called when a resource fails to load (e.g. no internet, 404, etc.)
          onWebResourceError: (error) {
            if (mounted) {
              CustomSnackbar.showError(
                context,
                'Failed to load page: ${error.description}',
              );
            }
          },
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title ?? 'Web Page',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            HugeIcons.strokeRoundedArrowLeft01,
            color: isDark ? Colors.white : Colors.black,
            size: 28,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        automaticallyImplyLeading: false,
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          // Centered loading indicator shown only during initial load
          if (isLoading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
