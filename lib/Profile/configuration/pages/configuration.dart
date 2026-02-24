import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../LoginPages/credetials/services/storage_service.dart';
import '../../profile/services/profile_service.dart';
import '../bloc/configuration_bloc.dart';
import '../bloc/configuration_event.dart';
import '../views/configuration_view.dart';

/// Top-level widget that provides the [ConfigurationBloc] to the configuration screen.
///
/// Responsibilities:
/// - Instantiates [ConfigurationBloc] with required services
/// - Automatically triggers initial profile loading (`LoadProfileEvent`)
/// - Passes profile data (image bytes, name, email) and refresh callback to [ConfigurationView]
///
/// This widget acts as the dependency injection / provider boundary for the entire
/// configuration/account management flow.
class Configuration extends StatelessWidget {
  final Uint8List? profileImageBytes;
  final String? userName;
  final String? mail;
  final Future<void> Function()? refreshProfile;

  const Configuration({
    super.key,
    required this.profileImageBytes,
    required this.userName,
    required this.mail,
    this.refreshProfile,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      // Create bloc instance with required service dependencies
      create: (_) => ConfigurationBloc(
        profileService: ProfileService(),
        storageService: StorageService(),
      )
      // Automatically load profile when screen is first built
        ..add(LoadProfileEvent()),
      // Pass initial profile data + refresh callback to the view
      child: ConfigurationView(
        profileImageBytes: profileImageBytes,
        userName: userName,
        mail: mail,
        refreshProfile: refreshProfile,
      ),
    );
  }
}
