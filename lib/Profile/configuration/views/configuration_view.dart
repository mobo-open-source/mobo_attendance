import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../CommonWidgets/core/language/translate_widget.dart';
import '../../../CommonWidgets/core/providers/language_provider.dart';
import '../../../CommonWidgets/core/providers/motion_provider.dart';
import '../../../CommonWidgets/globals.dart';
import '../../../LoginPages/credetials/services/storage_service.dart';
import '../../../LoginPages/login/bloc/login_bloc.dart';
import '../../../MainScreens/AppBars/pages/common_app_bar.dart';
import '../../../MainScreens/AppBars/services/app_bootstrapper.dart';
import '../../profile/pages/profile_form.dart';
import '../../settings/pages/settings.dart';
import '../bloc/configuration_bloc.dart';
import '../bloc/configuration_event.dart';
import '../bloc/configuration_state.dart';
import '../pages/SwitchAccount/server_url_screen.dart';
import '../widgets/logout_dialog.dart';

/// Configuration / account management screen.
///
/// Displays:
/// - Current user profile header (avatar, name, email) → tappable to edit profile
/// - Settings card with:
///   - App settings link
///   - Switch account section (list of saved accounts + add new)
///   - Logout button
///
/// Features:
/// - Multi-account switching (stored in secure storage)
/// - Motion-reduced navigation transitions
/// - Dark/light theme awareness
/// - Loading indicator during account switch
/// - Refresh profile callback on back navigation
class ConfigurationView extends StatefulWidget {
  final Uint8List? profileImageBytes;
  final String? userName;
  final String? mail;
  final Future<void> Function()? refreshProfile;

  const ConfigurationView({
    required this.profileImageBytes,
    required this.userName,
    required this.mail,
    this.refreshProfile,
  });

  @override
  State<ConfigurationView> createState() => ConfigurationViewState();
}

class ConfigurationViewState extends State<ConfigurationView> {
  bool isSwitching = false;

  @override
  Widget build(BuildContext context) {

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final motionProvider = Provider.of<MotionProvider>(context, listen: false);
    final bloc = context.read<ConfigurationBloc>();

    return WillPopScope(
      // Refresh profile when user navigates back (e.g. after profile edit)
      onWillPop: () async {
        widget.refreshProfile?.call();
        return true;
      },
      child: Scaffold(
        backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
        appBar: AppBar(
          backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              HugeIcons.strokeRoundedArrowLeft01,
              color: isDark ? Colors.white : Colors.black,
              size: 28,
            ),
            onPressed: () {
              Navigator.of(context).pop();
              widget.refreshProfile?.call();
            },
          ),
          title: tr(
            'Configuration',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
        ),
        body: BlocBuilder<ConfigurationBloc, ConfigurationState>(
          builder: (context, state) {
            final profiles = state.profiles;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Profile header (tappable → edit profile)
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        PageRouteBuilder(
                          pageBuilder: (context, animation, secondary) =>
                              ProfileFormPage(
                                refreshProfile: () async =>
                                    bloc.add(LoadProfileEvent()),
                              ),
                          transitionDuration: motionProvider.reduceMotion
                              ? Duration.zero
                              : const Duration(milliseconds: 300),
                          transitionsBuilder:
                              (context, animation, secondary, child) =>
                                  motionProvider.reduceMotion
                                  ? child
                                  : FadeTransition(
                                      opacity: animation,
                                      child: child,
                                    ),
                        ),
                      );
                    },
                    child: _buildProfileHeader(context, profiles),
                  ),
                  const SizedBox(height: 32),

                  // Main settings card (settings, switch account, logout)
                  _buildSettingsCard(context, profiles),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// Checks if bytes represent an SVG image (looks for `<svg` tag)
  bool isSvgBytes(Uint8List bytes) {
    final str = utf8.decode(bytes, allowMalformed: true);
    return str.contains('<svg');
  }

  /// Checks if base64 string represents an SVG image
  bool isSvgBase64(String data) {
    try {
      final decoded = utf8.decode(base64Decode(data), allowMalformed: true);
      return decoded.contains('<svg');
    } catch (_) {
      return false;
    }
  }

  /// Builds the tappable profile header with avatar, name, and email
  Widget _buildProfileHeader(BuildContext context, List profiles) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppStyle.primaryColor, AppStyle.primaryColor],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: ClipOval(
              child: SizedBox(
                width: 100,
                height: 100,
                child: profiles.isNotEmpty && profiles.first.image != null
                    ? isSvgBase64(profiles.first.image!)
                          ? SvgPicture.memory(
                              base64Decode(profiles.first.image!),
                              fit: BoxFit.cover,
                            )
                          : Image.memory(
                              base64Decode(profiles.first.image!),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.person, size: 50),
                            )
                    : widget.profileImageBytes != null
                    ? isSvgBytes(widget.profileImageBytes!)
                          ? SvgPicture.memory(
                              widget.profileImageBytes!,
                              fit: BoxFit.cover,
                            )
                          : Image.memory(
                              widget.profileImageBytes!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.person, size: 50),
                            )
                    : Icon(
                        HugeIcons.strokeRoundedUser,
                        size: 30,
                        color: Colors.white.withOpacity(0.9),
                      ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profiles.isNotEmpty
                      ? (profiles.first.name ?? "No Name")
                      : (widget.userName ?? "No Name"),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  profiles.isNotEmpty
                      ? (profiles.first.mail ?? "No Email")
                      : (widget.mail ?? "No Email"),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios,
            size: 16,
            color: Colors.white.withOpacity(0.7),
          ),
        ],
      ),
    );
  }

  /// Builds the main card containing Settings, Switch Account, and Logout options
  Widget _buildSettingsCard(BuildContext context, List profiles) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final motionProvider = Provider.of<MotionProvider>(context, listen: false);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // App Settings
          ListTile(
            leading: Icon(
              HugeIcons.strokeRoundedSettings02,
              color: isDark ? Colors.grey[400]! : Colors.grey[600]!,
            ),
            title: tr(
              'Settings',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            subtitle: tr(
              'App preferences and sync options',
              style: TextStyle(
                color: isDark ? Colors.grey[400]! : Colors.grey[600]!,
              ),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              Navigator.of(context).push(
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondary) =>
                      SettingsPage(),
                  transitionDuration: motionProvider.reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 300),
                  transitionsBuilder: (context, animation, secondary, child) =>
                      motionProvider.reduceMotion
                      ? child
                      : FadeTransition(opacity: animation, child: child),
                ),
              );
            },
          ),

          Divider(
            height: 1,
            thickness: 1,
            color: isDark ? Colors.grey[800] : Colors.grey[200],
            indent: 20,
            endIndent: 20,
          ),

          // Switch Account section (expandable)
          _buildSwitchAccount(context, profiles),

          Divider(
            height: 1,
            thickness: 1,
            color: isDark ? Colors.grey[800] : Colors.grey.shade200,
            indent: 20,
            endIndent: 20,
          ),

          // Logout
          ListTile(
            leading: const Icon(Icons.logout, color: Color(0xFFD32F2F)),
            title: tr(
              'Logout',
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFFD32F2F),
              ),
            ),
            subtitle: tr(
              'Sign out from this device',
              style: TextStyle(
                color: isDark ? Colors.grey[400]! : Colors.grey[600]!,
              ),
            ),
            onTap: () {
              showDialog(
                context: context,
                builder: (_) => ChangeNotifierProvider.value(
                  value: context.read<LanguageProvider>(),
                  child: LogoutDialog(storageService: StorageService()),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// Expandable section for switching between saved accounts
  Widget _buildSwitchAccount(BuildContext context, List profiles) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final motionProvider = Provider.of<MotionProvider>(context, listen: false);

    return Theme(
      data: Theme.of(context).copyWith(
        dividerColor: Colors.transparent,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
      ),
      child: ExpansionTile(
        leading: Icon(
          HugeIcons.strokeRoundedUserSwitch,
          color: isDark ? Colors.grey[400]! : Colors.grey[600]!,
        ),
        title: tr(
          'Switch Accounts',
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
        ),
        subtitle: tr(
          "Manage and switch between accounts",
          style: TextStyle(
            color: isDark ? Colors.grey[400]! : Colors.grey[600]!,
          ),
        ),
        children: [
          FutureBuilder<List<Map<String, dynamic>>>(
            future: StorageService().getAccounts(),
            builder: (context, snapshot) {
              final accounts = snapshot.data ?? [];

              final currentUserId = profiles.isNotEmpty
                  ? profiles.first.id
                  : null;

              final otherAccounts = accounts.where((user) {
                return user["userId"] != currentUserId &&
                    (user["userName"] ?? "").toString().isNotEmpty;
              }).toList();

              return Column(
                children: [
                  // No additional accounts message
                  if (otherAccounts.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Icon(
                            HugeIcons.strokeRoundedUserAdd01,
                            size: 30,
                            color: isDark
                                ? Colors.grey[600]
                                : Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          tr(
                            "No Additional Accounts",
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 5,),
                          tr(
                            'Add multiple accounts to switch between them quickly',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? Colors.grey[400]! : Colors.grey[600]!,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // List of saved accounts
                  ...otherAccounts.map((user) {
                    Uint8List? avatar;
                    try {
                      if (user['image'] != null &&
                          (user['image'] as String).isNotEmpty) {
                        avatar = base64Decode(user['image']);
                      }
                    } catch (_) {}

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: avatar != null
                            ? MemoryImage(avatar)
                            : null,
                        child: avatar == null ? const Icon(Icons.person) : null,
                      ),
                      title: tr(
                        user['userName'] ?? "",
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: tr(
                        user['userLogin'] ?? "",
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.grey[400]! : Colors.grey[600]!,
                        ),
                      ),
                      trailing:
                          BlocListener<ConfigurationBloc, ConfigurationState>(
                            listenWhen: (prev, curr) =>
                                prev.switchStatus != curr.switchStatus &&
                                curr.switchStatus == SwitchStatus.completed,
                            listener: (context, state) {
                              setState(() {
                                isSwitching = false;
                              });
                              AppBootstrapper.reloadAppBlocs(context);
                              Navigator.pushAndRemoveUntil(
                                context,
                                PageRouteBuilder(
                                  pageBuilder: (_, animation, secondary) =>
                                      const CommonAppBar(),
                                  transitionDuration:
                                      motionProvider.reduceMotion
                                      ? Duration.zero
                                      : const Duration(milliseconds: 300),
                                  transitionsBuilder:
                                      (context, animation, sec, child) =>
                                          motionProvider.reduceMotion
                                          ? child
                                          : FadeTransition(
                                              opacity: animation,
                                              child: child,
                                            ),
                                ),
                                (_) => false,
                              );
                            },
                            child: TextButton(
                              onPressed: () async {
                                setState(() {
                                  isSwitching = true;
                                });
                                context.read<ConfigurationBloc>().add(
                                  SwitchAccountEvent(user),
                                );
                              },
                              child: isSwitching
                                  ? LoadingAnimationWidget.threeArchedCircle(
                                      color: isDark
                                          ? Colors.white
                                          : AppStyle.primaryColor,
                                      size: 20,
                                    )
                                  : tr(
                                      "Switch",
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.white
                                            : AppStyle.primaryColor,
                                        fontSize: 14,
                                      ),
                                    ),
                            ),
                          ),
                    );
                  }),
                  const SizedBox(height: 10),

                  // Add new account button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async{
                          final prefs =
                              await SharedPreferences
                              .getInstance();
                          final url =
                              prefs.getString('url') ??
                                  '';
                          final database =
                              prefs.getString(
                                  'database') ??
                                  '';
                          Navigator.pop(context);
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => BlocProvider(
                                create: (context) => LoginBloc(),
                                child: ServerUrlScreen(
                                  serverUrl: url,
                                  database: database,
                                ),
                              ),
                            ),
                          );
                        },
                        icon: const Icon(HugeIcons.strokeRoundedUserAdd01),
                        label: tr(
                          "Add Account",
                          style: TextStyle(
                            color: isDark ? Colors.black : Colors.white,
                            fontSize: 16,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark
                              ? Colors.white
                              : AppStyle.primaryColor,
                          foregroundColor: isDark ? Colors.black : Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
