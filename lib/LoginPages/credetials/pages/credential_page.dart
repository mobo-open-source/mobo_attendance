import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../CommonWidgets/core/company/services/company_session_service_impl.dart';
import '../../../CommonWidgets/core/company/session/company_session_manager.dart';
import '../../../CommonWidgets/core/language/translate_widget.dart';
import '../../../CommonWidgets/core/providers/language_provider.dart';
import '../../../CommonWidgets/core/providers/motion_provider.dart';
import '../../../CommonWidgets/core/security/secure_storage_service.dart';
import '../../../CommonWidgets/globals.dart';
import '../../../MainScreens/AppBars/pages/common_app_bar.dart';
import '../../../MainScreens/AppBars/services/app_bootstrapper.dart';
import '../../../MainScreens/AppBars/services/common_storage_service.dart';
import '../../../Profile/configuration/services/app_shutdown_manager.dart';
import '../../resetPassword/pages/reset_password.dart';
import '../bloc/credentials_bloc.dart';
import '../services/app_install_check.dart';
import '../services/storage_service.dart';

/// CredentialsPage handles user login credentials UI,
/// bloc connection, and module validation before dashboard navigation.
class CredentialsPage extends StatelessWidget {
  final String protocol;
  final String url;
  final String database;

  const CredentialsPage({
    Key? key,
    required this.protocol,
    required this.url,
    required this.database,
  }) : super(key: key);

  /// Shows dialog when required module is not installed in backend.
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
                'Back to Login',
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final motionProvider = Provider.of<MotionProvider>(context, listen: false);

    return BlocProvider(
      create: (context) => CredentialsBloc(
        sessionService: CompanySessionServiceImpl(),
        commonStorageService: CommonStorageService(),
      ),
      child: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[950] : Colors.grey[50],
                  image: DecorationImage(
                    image: const AssetImage("assets/background.png"),
                    fit: BoxFit.cover,
                    colorFilter: ColorFilter.mode(
                      isDark ? Colors.black : Colors.white,
                      BlendMode.dstATop,
                    ),
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          Positioned(
                            top: 0,
                            left: 0,
                            child: SafeArea(
                              child: BlocBuilder<CredentialsBloc, CredentialsState>(
                                builder: (context, state) => Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () => Navigator.pop(context),
                                    borderRadius: BorderRadius.circular(32),
                                    child: Container(
                                      height: 64,
                                      width: 64,
                                      alignment: Alignment.center,
                                      child: Icon(
                                        HugeIcons.strokeRoundedArrowLeft01,
                                        color: state.isLoading
                                            ? Colors.white54
                                            : Colors.white,
                                        size: 24,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SafeArea(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 40),
                              child: Stack(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Image.asset(
                                        'assets/attendance-icon.png',
                                        fit: BoxFit.fitWidth,
                                        height: 30,
                                        width: 30,
                                        errorBuilder: (_, __, ___) => const Icon(
                                          HugeIcons.strokeRoundedTask01,
                                          color: Color(0xFFC03355),
                                          size: 30,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      const Text(
                                        'mobo attendance',
                                        style: TextStyle(
                                          fontFamily: 'Yaro',
                                          color: Colors.white,
                                          fontSize: 24,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      Expanded(
                        child: Center(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: _LoginForm(
                              protocol: protocol,
                              url: url,
                              database: database,
                              motionProvider: motionProvider,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Login form widget responsible for:
/// - Input validation
/// - Password visibility toggle
/// - Login submission via Bloc
/// - Navigation based on login result
class _LoginForm extends StatefulWidget {
  final String protocol;
  final String url;
  final String database;
  final MotionProvider motionProvider;

  const _LoginForm({
    required this.protocol,
    required this.url,
    required this.database,
    required this.motionProvider,
  });

  @override
  State<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<_LoginForm> {
  /// Form key for validating login fields.
  final _formKey = GlobalKey<FormState>();

  /// Controller for username input.
  final _usernameController = TextEditingController();

  /// Controller for password input.
  final _passwordController = TextEditingController();

  /// Clears login error message from bloc when user edits fields.
  void _clearError() {
    if (context.read<CredentialsBloc>().state.errorMessage != null) {
      context.read<CredentialsBloc>().add(ClearErrorMessage());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            tr(
              'Sign In',
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w600,
                color: Colors.white,
                fontSize: 32,
              ),
            ),
            const SizedBox(height: 6),
            tr(
              'use proper information to continue',
              style: GoogleFonts.manrope(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 30),

            _buildInputField(
              controller: _usernameController,
              label: "Username",
              icon: HugeIcons.strokeRoundedUser03,
              onChanged: (_) {
                _clearError();
                if (_formKey.currentState!.validate()) {}
              },
            ),

            const SizedBox(height: 20),
            BlocBuilder<CredentialsBloc, CredentialsState>(
              builder: (context, state) => _buildInputField(
                controller: _passwordController,
                label: "Password",
                icon: HugeIcons.strokeRoundedSquareLockPassword,
                isPasswordField: true,
                isPasswordVisible: state.isPasswordVisible,
                onVisibilityToggle: () => context.read<CredentialsBloc>().add(
                  TogglePasswordVisibility(),
                ),
                onChanged: (_) {
                  _clearError();
                  if (_formKey.currentState!.validate()) {}
                },
              ),
            ),

            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ResetPasswordScreen(
                        url:
                            widget.protocol +
                            widget.url.replaceFirst(RegExp(r'^https?://'), ''),
                        database: widget.database,
                      ),
                    ),
                  );
                },
                child: tr(
                  'Forgot Password?',
                  style: GoogleFonts.manrope(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ),
            ),

            BlocBuilder<CredentialsBloc, CredentialsState>(
              builder: (context, state) {
                if (state.errorMessage != null &&
                    state.errorMessage!.isNotEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: tr(
                      state.errorMessage!,
                      style: GoogleFonts.manrope(color: Colors.white),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),

            const SizedBox(height: 20),
            BlocConsumer<CredentialsBloc, CredentialsState>(
              listener: (context, state) async{
                if (state.loginSuccess) {
                  final checker = AppInstallCheck();
                  final isInstalled = await checker.checkRequiredModules();

                  if (!isInstalled) {
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
                        context, '/login', (route) => false);
                    if (context.mounted) {
                      final parent =
                      context.findAncestorWidgetOfExactType<CredentialsPage>();
                      parent?.showModuleMissingDialog(context);
                    }
                    return;
                  } else {
                    AppBootstrapper.reloadAppBlocs(context);
                    Navigator.pushAndRemoveUntil(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (_, __, ___) => const CommonAppBar(),
                        transitionDuration: widget.motionProvider.reduceMotion
                            ? Duration.zero
                            : const Duration(milliseconds: 300),
                        transitionsBuilder: (_, animation, __, child) =>
                            FadeTransition(opacity: animation, child: child),
                      ), (route) => false,
                    );
                  }
                }
              },
              builder: (context, state) {
                return SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: state.isLoading
                        ? null
                        : () {
                            if (_formKey.currentState!.validate()) {
                              context.read<CredentialsBloc>().add(
                                SubmitLogin(
                                  context: context,
                                  protocol: widget.protocol,
                                  url: widget.url,
                                  database: widget.database,
                                  username: _usernameController.text.trim(),
                                  password: _passwordController.text.trim(),
                                ),
                              );
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: state.isLoading
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              tr(
                                'Signing',
                                style: GoogleFonts.manrope(
                                  color: Colors.white,
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
                            "Sign In",
                            style: GoogleFonts.manrope(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Builds reusable input field for username and password.
  ///
  /// Supports:
  /// - Password visibility toggle
  /// - Autofill hints
  /// - Localization validation message
  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    IconData? icon,
    bool isPasswordField = false,
    bool? isPasswordVisible,
    VoidCallback? onVisibilityToggle,
    Function(String)? onChanged,
  }) {
    final translationService = context.read<LanguageProvider>();

    return AutofillGroup(
      child: TextFormField(
        controller: controller,
        obscureText: isPasswordField ? !(isPasswordVisible ?? false) : false,
        onChanged: onChanged,
        validator: (v) => v?.isEmpty ?? true ? translationService.getCached('$label is required') : null,
        autofillHints: isPasswordField
            ? [AutofillHints.password]
            : [AutofillHints.username],
        style: GoogleFonts.manrope(color: Colors.black),
        decoration: InputDecoration(
          hintText: translationService.getCached(label)??label,
          hintStyle: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: Colors.black.withOpacity(.4),
          ),
          prefixIcon: icon != null
              ? Icon(icon, color: Colors.black54, size: 18)
              : null,
          suffixIcon: isPasswordField
              ? IconButton(
                  icon: Icon(
                    isPasswordVisible == true
                        ? Icons.visibility
                        : Icons.visibility_off,
                    color: isPasswordVisible == true ? Colors.black26 : Colors.black45,
                    size: 20,
                  ),
                  onPressed: onVisibilityToggle,
                )
              : null,
          filled: true,
          fillColor: Colors.grey.shade100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          errorStyle: GoogleFonts.manrope(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
