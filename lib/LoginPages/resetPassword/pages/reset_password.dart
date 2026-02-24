import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:mobo_attendance/LoginPages/resetPassword/pages/webview_screen.dart';

import '../../../CommonWidgets/core/language/translate_widget.dart';
import '../../../CommonWidgets/core/providers/language_provider.dart';
import '../services/reset_password_service.dart';

/// Reset Password screen.
///
/// Allows user to:
/// - Enter email address
/// - Request password reset email from server
/// - Show success / error message
/// - Redirect to WebView if reset requires external verification
class ResetPasswordScreen extends StatefulWidget {
  final String? url;
  final String? database;

  const ResetPasswordScreen({super.key, this.url, this.database});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

/// State for ResetPasswordScreen.
///
/// Handles:
/// - Form validation
/// - API call for reset password
/// - Loading state
/// - Success / Error animations
/// - Email input handling
class _ResetPasswordScreenState extends State<ResetPasswordScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  bool _isLoading = false;
  bool _shouldValidate = false;
  bool _emailHasError = false;
  String? _errorMessage;
  String? _successMessage;

  late AnimationController _successAnimationController;
  late Animation<double> _successFadeAnimation;
  late Animation<Offset> _successSlideAnimation;

  @override
  void initState() {
    super.initState();
    _successAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _successFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _successAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _successSlideAnimation =
        Tween<Offset>(begin: const Offset(0.0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _successAnimationController,
            curve: Curves.easeOutBack,
          ),
        );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _successAnimationController.dispose();
    super.dispose();
  }

  /// Sends reset password email request to server.
  ///
  /// Flow:
  /// - Validates email input
  /// - Calls ResetPasswordService
  /// - Shows success message OR error message
  /// - Navigates to WebView if required by server
  Future<void> _sendResetEmail() async {
    final ts = context.read<LanguageProvider>();

    FocusScope.of(context).unfocus();

    setState(() {
      _shouldValidate = true;
      _errorMessage = null;
      _successMessage = null;
    });

    final formValid = _formKey.currentState?.validate() ?? false;

    setState(() {
      _emailHasError =
          _emailController.text.trim().isEmpty ||
          !ResetPasswordService.isValidEmail(_emailController.text.trim());
    });

    if (!formValid) {
      await HapticFeedback.lightImpact();
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await ResetPasswordService.sendResetPasswordEmail(
        serverUrl: widget.url ?? '',
        database: widget.database ?? '',
        login: _emailController.text.trim(),
      );

      if (!mounted) return;

      if (result['success'] == true) {
        final translated = await ts.translate(result['message']);

        setState(() {
          _successMessage = translated;
          _errorMessage = null;
        });
        _successAnimationController.forward();
        await HapticFeedback.selectionClick();
      } else if (result['requiresWebView'] == true) {
        await HapticFeedback.lightImpact();
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => WebViewScreen(
                url: result['webViewUrl'],
                title: 'Reset Password',
              ),
            ),
          );
        }
      } else {
        final translated = await ts.translate(result['message']);

        setState(() {
          _errorMessage = translated;
          _successMessage = null;
        });
        await HapticFeedback.heavyImpact();
      }
    } catch (e) {
      if (!mounted) return;
      final translated = await ts.translate("An unexpected error occurred. Please try again.");

      setState(() {
        _errorMessage = translated;
        _successMessage = null;
      });
      await HapticFeedback.heavyImpact();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return WillPopScope(
      onWillPop: () async => !_isLoading,
      child: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[950] : Colors.grey[50],
                  image: DecorationImage(
                    image: AssetImage('assets/background.png'),
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

            LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 400),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            _buildHeader(),
                            const SizedBox(height: 48),

                            if (_successMessage != null)
                              AnimatedBuilder(
                                animation: _successAnimationController,
                                builder: (context, child) {
                                  return SlideTransition(
                                    position: _successSlideAnimation,
                                    child: FadeTransition(
                                      opacity: _successFadeAnimation,
                                      child: _buildSuccessMessage(),
                                    ),
                                  );
                                },
                              ),

                            if (_successMessage == null) ...[
                              _buildForm(),
                            ] else ...[
                              const SizedBox(height: 32),
                              _buildBackToLoginButton(),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

            Positioned(
              top: 0,
              left: 0,
              child: SafeArea(
                bottom: false,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _isLoading
                        ? null
                        : () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(32),
                    child: Container(
                      height: 64,
                      width: 64,
                      alignment: Alignment.center,
                      child: Icon(
                        HugeIcons.strokeRoundedArrowLeft01,
                        color: _isLoading ? Colors.white54 : Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds screen header section.
  ///
  /// Displays:
  /// - Lock icon
  /// - Reset password title
  /// - Description text
  /// - Server URL (if available)
  Widget _buildHeader() {
    final translationService = context.read<LanguageProvider>();
    final serverLabel = translationService.getCached('Server: ') ?? 'Server: ';

    return Column(
      children: [
        Icon(
          HugeIcons.strokeRoundedLockPassword,
          color: Colors.white,
          size: 48,
        ),
        const SizedBox(height: 24),
        tr(
          'Reset Password',
          style: GoogleFonts.montserrat(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        tr(
          'Enter your email address and we\'ll send you a link to reset your password',
          style: GoogleFonts.montserrat(
            fontSize: 14,
            color: Colors.white70,
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
        if (widget.url != null) ...[
          const SizedBox(height: 16),
          Text(
            '$serverLabel${widget.url}',
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

  /// Builds email input form.
  ///
  /// Includes:
  /// - Email text field
  /// - Validation handling
  /// - Error message display
  /// - Send button with loading animation
  Widget _buildForm() {
    final translationService = context.read<LanguageProvider>();
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            enabled: !_isLoading,
            autovalidateMode: _shouldValidate
                ? AutovalidateMode.onUserInteraction
                : AutovalidateMode.disabled,
            validator: (value) {
              if (!_shouldValidate) return null;
              if (value == null || value.trim().isEmpty) {
                return translationService.getCached('Email is required');
              }
              return null;
            },
            onChanged: (value) {
              setState(() {
                _emailHasError =
                    value.trim().isEmpty ||
                    !ResetPasswordService.isValidEmail(value.trim());
                if (_errorMessage != null) {
                  _errorMessage = null;
                }
              });
            },
            cursorColor: Colors.black,
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Colors.black,
            ),
            decoration: InputDecoration(
              hintText: translationService.getCached('Email Address'),
              hintStyle: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Colors.black.withOpacity(.4),
              ),
              prefixIcon: Icon(HugeIcons.strokeRoundedMail01, size: 20),
              prefixIconColor: MaterialStateColor.resolveWith(
                (states) => states.contains(MaterialState.disabled)
                    ? Colors.black26
                    : Colors.black54,
              ),
              suffixIcon: _emailHasError
                  ? Icon(Icons.error_outline, color: Colors.red, size: 20)
                  : null,
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
          const SizedBox(height: 24),

          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: _errorMessage != null ? 48 : 0,
            child: _errorMessage != null
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
                          child: Text(
                             _errorMessage!,
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

          const SizedBox(height: 24),

          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _sendResetEmail,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        tr(
                          'Sending',
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
                      'Send',
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

  /// Builds success message UI after email is sent.
  ///
  /// Shows:
  /// - Success icon
  /// - Confirmation text
  /// - Server response message
  Widget _buildSuccessMessage() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(
            HugeIcons.strokeRoundedCheckmarkCircle02,
            color: Colors.green,
            size: 48,
          ),
          const SizedBox(height: 16),
          tr(
            'Email Sent!',
            style: GoogleFonts.montserrat(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _successMessage!,
            style: GoogleFonts.manrope(
              fontSize: 14,
              color: Colors.white70,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Builds "Back to Login" button.
  ///
  /// Navigates user back to login screen.
  Widget _buildBackToLoginButton() {
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: () => Navigator.of(context).pop(),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.black.withOpacity(.75),
          disabledForegroundColor: Colors.white,
          overlayColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: tr(
          'Back to Login',
          style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
