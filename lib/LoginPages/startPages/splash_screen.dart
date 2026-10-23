import 'dart:async';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

import '../../CommonWidgets/shared/widgets/snackbar.dart';
import '../../Rating/review_service.dart';
import '../credetials/controllers/auth_controller.dart';
import '../credetials/services/auth_service.dart';
import '../credetials/services/storage_service.dart';

/// A splash screen that shows a video or logo while checking authentication.
///
/// Handles biometric authentication if enabled, and navigates
/// the user to the appropriate screen based on login status.
class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late AuthController _authController;
  final LocalAuthentication _localAuth = LocalAuthentication();

  /// Whether biometric authentication is enabled.
  bool _biometricEnabled = false;

  @override
  void initState() {
    super.initState();

    _authController = AuthController(
      authService: AuthService(),
      storageService: StorageService(),
    );

    _startAuthCheck();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(seconds: 2), () {
        ReviewService().trackAppOpen();
      });
    });
  }

  /// Performs biometric authentication if available.
  ///
  /// Shows error messages via a snackbar if biometric is not available
  /// or if authentication fails.
  ///
  /// [context] The BuildContext used to show snackbars.
  ///
  /// Returns `true` if the user successfully authenticates, otherwise `false`.
  Future<bool> authenticateBiometrics(BuildContext context) async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics || await _localAuth.isDeviceSupported();
      if (!canCheck) {
        CustomSnackbar.showError(context, 'Biometric not available');
        return false;
      }

      final biometrics = await _localAuth.getAvailableBiometrics();
      final type = biometrics.contains(BiometricType.face)
          ? 'Face ID'
          : biometrics.contains(BiometricType.fingerprint)
          ? 'Touch ID'
          : 'biometric';

      final ok = await _localAuth.authenticate(
        localizedReason: 'Authenticate with $type to log in',
        options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
      );

      if (!ok) CustomSnackbar.showError(context, 'Biometric failed, Please try again later');
      return ok;
    } catch (e) {
      CustomSnackbar.showError(context, 'Something went wrong, Please try again later');
      return false;
    }
  }

  /// Starts the authentication check after a delay.
  ///
  /// Checks for biometric authentication if enabled in SharedPreferences,
  /// verifies login status using AuthController, and navigates accordingly.
  Future<void> _startAuthCheck() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _biometricEnabled = prefs.getBool('biometricEnabled') ?? false;
    });
    await Future.delayed(const Duration(seconds: 3));
    final authModel = await _authController.checkLoginStatus();
    if (_biometricEnabled) {
      final authenticated = await authenticateBiometrics(context);
      if (!authenticated) return;
    }
    await _authController.handleAuthentication(context, authModel);
  }

  @override
  void dispose() {
    super.dispose();
  }

  /// Builds the splash screen UI.
  ///
  /// Shows a video if initialized, otherwise shows a circular logo.
  @override
  Widget build(BuildContext context) {
    final videoController = Provider.of<VideoPlayerController>(context);

    return Scaffold(
      body: videoController.value.isInitialized
          ? SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: videoController.value.size.width,
            height: videoController.value.size.height,
            child: VideoPlayer(videoController),
          ),
        ),
      )
          : Center(
        child: ClipOval(
          child: Image.asset(
            'assets/icon.png',
            width: 200,
            height: 200,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}
