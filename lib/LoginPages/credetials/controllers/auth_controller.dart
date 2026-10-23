import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../MainScreens/AppBars/pages/common_app_bar.dart';
import '../../../MainScreens/AppBars/services/app_bootstrapper.dart';
import '../../login/models/auth_model.dart';
import '../../login/pages/login_screen.dart';
import '../../startPages/get_started_screen.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';

/// Handles authentication flow, login status check,
/// biometric verification, and navigation routing.
class AuthController {
  final AuthService _authService;
  final StorageService _storageService;

  /// Creates AuthController with required services.
  AuthController({
    required AuthService authService,
    required StorageService storageService,
  })  : _authService = authService,
        _storageService = storageService;

  /// Checks stored login and biometric preference status.
  Future<AuthModel> checkLoginStatus() async {
    final status = await _storageService.getLoginStatus();
    return AuthModel(
      isLoggedIn: status['isLoggedIn'],
      useLocalAuth: status['useLocalAuth'],
    );
  }

  /// Handles authentication decision flow and routes user accordingly.
  Future<void> handleAuthentication(BuildContext context, AuthModel authModel) async {
    if (authModel.isLoggedIn) {
      if (authModel.useLocalAuth) {
        final authResult = await _authService.authenticateWithBiometrics();
        if (authResult == AuthenticationResult.success || authResult == AuthenticationResult.unavailable) {
          await _navigateToDashboard(context);
        } else {
          await _navigateToLogin(context);
        }
      } else {
        await _navigateToDashboard(context);
      }
    } else {
      await _navigateToLogin(context);
    }
  }

  /// Navigates user to dashboard.
  Future<void> _navigateToDashboard(BuildContext context) async {
    // The app's data blocs are created eagerly at process start and fire
    // their first load before this splash check even completes, often
    // before the device's network has settled after a cold boot. Reload
    // them now that the app has actually determined the session is valid,
    // so a stale failure from that very first attempt doesn't stick.
    AppBootstrapper.reloadAppBlocs(context);

    Navigator.pushAndRemoveUntil(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const CommonAppBar(),
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),(route) => false,
    );
  }

  /// Navigates user to Login or Get Started screen based on onboarding status.
  Future<void> _navigateToLogin(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    bool isGetStarted = prefs.getBool('hasSeenGetStarted')?? false;
    if(isGetStarted) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const LoginScreen(),
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    }else{
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation,
              secondaryAnimation) => const GetStartedScreen(),
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    }
  }
}