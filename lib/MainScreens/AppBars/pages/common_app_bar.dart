import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_snake_navigationbar/flutter_snake_navigationbar.dart';
import 'package:flutter_svg/svg.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobo_attendance/MainScreens/AppBars/infrastructure/profile_refresh_bus.dart';
import 'package:provider/provider.dart';
import '../../../CommonWidgets/core/company/infrastructure/company_refresh_bus.dart';
import '../../../CommonWidgets/core/company/providers/company_provider.dart';
import '../../../CommonWidgets/core/company/widgets/company_selector_widget.dart';
import '../../../CommonWidgets/core/language/translate_widget.dart';
import '../../../CommonWidgets/core/providers/language_provider.dart';
import '../../../CommonWidgets/core/providers/motion_provider.dart';
import '../../../CommonWidgets/globals.dart';
import '../../../CommonWidgets/shared/widgets/snackbar.dart';
import '../../../LoginPages/credetials/services/storage_service.dart';
import '../../../LoginPages/login/models/session_model.dart';
import '../../../Profile/configuration/pages/configuration.dart';
import '../../../Profile/profile/models/profile.dart';
import '../../../Profile/profile/services/profile_service.dart';
import '../../Attendance/AttendanceList/pages/attendance_list_page.dart';
import '../../Calendar/pages/calendar_page.dart';
import '../../Dashboard/AttendanceDashboard/pages/attendance_dashboard_page.dart';
import '../../Employees/EmployeeList/pages/employee_list_page.dart';
import '../services/app_bootstrapper.dart';

/// A common app scaffold with a top AppBar and bottom navigation bar.
///
/// Features:
/// - Bottom navigation between Dashboard, Employees, Attendances, and Calendar pages.
/// - Shows user profile picture and name, supports editing via Configuration page.
/// - Allows switching companies with live refresh.
/// - Listens for profile and company updates to refresh UI.
/// - Supports translations and reduced motion for transitions.
class CommonAppBar extends StatefulWidget {
  final int initialIndex;

  const CommonAppBar({super.key, this.initialIndex = 0});

  @override
  State<CommonAppBar> createState() => _CommonAppBarState();
}

class _CommonAppBarState extends State<CommonAppBar> {
  int _currentIndex = 0;
  Uint8List? profileImageBytes;
  String? mail;
  String? userName;
  List<dynamic> loggedInUsers = [];
  late StorageService storageService;
  List<Profile> profiles = [];
  String profileImageUrl = '';
  late final StreamSubscription _profileSub;
  late final StreamSubscription _companySub;

  final List<Map<String, dynamic>> pages = [
    {'title': 'Dashboard', 'widget': AttendanceDashboardPage()},
    {'title': 'Employees', 'widget': EmployeeListPage()},
    {'title': 'Attendances', 'widget': AttendanceListPage()},
    {'title': 'Calendar', 'widget': CalendarPage()},
  ];

  /// Initializes state, loads profile, company data,
  /// and listens to profile & company refresh events.
  @override
  void initState() {
    super.initState();
    storageService = StorageService();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await loadProfile();
      await context.read<CompanyProvider>().initialize();
    });

    _profileSub = ProfileRefreshBus.onProfileRefresh.listen((_) {
      if (!mounted) return;
      loadProfile();
    });

    _companySub = CompanyRefreshBus.stream.listen((_) async {
      if (!mounted) return;
      await context.read<CompanyProvider>().initialize();
      if (!mounted) return;
      AppBootstrapper.reloadAppBlocs(context);
    });


    _currentIndex = widget.initialIndex;
  }

  /// Cancels subscriptions to profile and company updates when disposing.
  @override
  void dispose() {
    _profileSub.cancel();
    _companySub.cancel();
    super.dispose();
  }

  /// Returns a cached translation for a given key, or the key itself if not found.
  String catchTranslate(BuildContext context, String key) {
    final service = Provider.of<LanguageProvider>(context, listen: false);
    return service.getCached(key) ?? key;
  }

  /// Loads user profile, updates profile image, name, email,
  /// and stores account info locally.
  Future<void> loadProfile() async {
    final profileService = ProfileService();
    profiles = await profileService.loadProfile();

    final storedAccounts = await storageService.getAccounts();
    if (!mounted) return;
    setState(() {
      loggedInUsers = storedAccounts;
    });

    if (profiles.isNotEmpty) {
      final profile = profiles.first;
      final base64Image = profile.image;

      mail = profile.mail;
      userName = profile.name;

      final currentAccounts = await storageService.getAccounts();

      final existing = currentAccounts.firstWhere(
        (a) => a['userId'] == profile.id,
        orElse: () => {},
      );

      final accountWithImage = {...existing, 'image': base64Image};

      await storageService.saveAccount(accountWithImage);

      if (base64Image.isNotEmpty) {
        Uint8List imageBytes = base64Decode(base64Image);
        if (!mounted) return;
        setState(() {
          profileImageBytes = imageBytes;
        });
      }
    }
  }

  /// Checks if a given Base64 string contains SVG content.
  bool isSvgBase64(String data) {
    try {
      final decoded = utf8.decode(base64Decode(data), allowMalformed: true);
      return decoded.contains('<svg');
    } catch (_) {
      return false;
    }
  }

  /// Checks if a given byte array contains SVG content.
  bool isSvgBytes(Uint8List bytes) {
    final str = utf8.decode(bytes, allowMalformed: true);
    return str.contains('<svg');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final motionProvider = Provider.of<MotionProvider>(context, listen: false);
    final translationService = Provider.of<LanguageProvider>(context, listen: false);

    return WillPopScope(
      onWillPop: () async {
        if (_currentIndex != 0) {
          setState(() {
            _currentIndex = 0;
          });
          return false;
        }
        SystemNavigator.pop();
        return true;
      },
      child: Scaffold(
        backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
        appBar: AppBar(
          title: tr(
            pages[_currentIndex]['title'],
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              )
          ),
          backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
          automaticallyImplyLeading: false,
          actions: [
            CompanySelectorWidget(
              onCompanyChanged: () async {
                if (!mounted) return;
                final provider = context.read<CompanyProvider>();
                final companyName =
                    provider.selectedCompany?['name']?.toString() ?? 'company';
                await loadProfile();
                CompanyRefreshBus.notify();

                CustomSnackbar.showSuccess(context, 'Switched to $companyName');
              },
            ),
            SizedBox(width: 10,),
            GestureDetector(
              onTap: () async {
                await Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (_, __, ___) => Configuration(
                      refreshProfile: loadProfile,
                      profileImageBytes: profileImageBytes,
                      userName: (userName?.isNotEmpty ?? false)
                          ? userName!
                          : catchTranslate(context, "Unknown"),
                      mail: (mail?.isNotEmpty ?? false)
                          ? mail!
                          : catchTranslate(context, "Unknown"),
                    ),
                    transitionDuration: motionProvider.reduceMotion
                        ? Duration.zero
                        : const Duration(milliseconds: 300),
                    reverseTransitionDuration: motionProvider.reduceMotion
                        ? Duration.zero
                        : const Duration(milliseconds: 300),
                    transitionsBuilder:
                        (context, animation, secondaryAnimation, child) {
                          if (motionProvider.reduceMotion) return child;
                          return FadeTransition(
                            opacity: animation,
                            child: child,
                          );
                        },
                  ),
                );
              },
              child: CircleAvatar(
                radius: 20,
                backgroundColor: theme.colorScheme.surface,
                child: profileImageBytes != null
                    ? isSvgBytes(profileImageBytes!)
                          ? ClipOval(
                              child: SvgPicture.memory(
                                profileImageBytes!,
                                width: 40,
                                height: 40,
                                fit: BoxFit.cover,
                              ),
                            )
                          : ClipOval(
                              child: Image.memory(
                                profileImageBytes!,
                                width: 40,
                                height: 40,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Icon(
                                  Icons.person,
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.6),
                                ),
                              ),
                            )
                    : Icon(
                        Icons.person,
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
              ),
            ),
            const SizedBox(width: 12),
          ],
        ),
        body: pages[_currentIndex]['widget'],
        bottomNavigationBar: SnakeNavigationBar.color(
          behaviour: SnakeBarBehaviour.pinned,
          snakeShape: SnakeShape.indicator,
          padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
          backgroundColor: isDark ? Colors.grey[900] : Colors.white,
          selectedItemColor: isDark ? Colors.white : AppStyle.primaryColor,
          unselectedItemColor: isDark ? Colors.grey[400] : Colors.black,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },

          items: [
            BottomNavigationBarItem(
              icon: Icon(HugeIcons.strokeRoundedDashboardSquare02),
              label: translationService.getCached("Dashboard")??"Dashboard",
            ),
            BottomNavigationBarItem(
              icon: Icon(HugeIcons.strokeRoundedUserMultiple),
              label: translationService.getCached("Employees")??"Employees",
            ),
            BottomNavigationBarItem(
              icon: Icon(HugeIcons.strokeRoundedTask01),
              label: translationService.getCached("Attendances")??"Attendances",
            ),
            BottomNavigationBarItem(
              icon: Icon(HugeIcons.strokeRoundedCalendar03),
              label: translationService.getCached("Calendar")??"Calendar",
            ),
          ],
          snakeViewColor: isDark ? Colors.white : AppStyle.primaryColor,
          unselectedLabelStyle: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.grey[400]! : Colors.grey[600]!,
          ),
          selectedLabelStyle: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : AppStyle.primaryColor,
          ),
          shadowColor: isDark ? Colors.black26 : Colors.grey[200]!,
          elevation: 8,
          height: 70,
        ),
      ),
    );
  }

  /// Switches the current session to another account and reloads the app.
  Future<void> switchAccount(Map<String, dynamic> user) async {
    final storageService = StorageService();

    await storageService.saveSession(
      SessionModel(
        sessionId: user['sessionId'],
        userName: user['userName'],
        userLogin: user['userLogin'],
        userId: user['userId'],
        serverVersion: user['serverVersion'],
        userLang: user['userLang'],
        partnerId: user['partnerId'],
        userTimezone: user['userTimezone'],
        companyId: user['companyId'],
        companyName: user['companyName'],
        isSystem: user['isSystem'] ?? false,
      ),
    );

    await storageService.saveLoginState(
      isLoggedIn: true,
      database: user['database'],
      url: user['url'],
    );
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const CommonAppBar(),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
        (route) => false,
      );
    }
  }
}
