import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:intl/intl.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'CommonWidgets/core/company/providers/company_provider.dart';
import 'CommonWidgets/core/language/translation_strings.dart';
import 'CommonWidgets/core/navigation/global_keys.dart';
import 'CommonWidgets/core/providers/language_provider.dart';
import 'CommonWidgets/core/providers/locale_provider.dart';
import 'CommonWidgets/core/providers/motion_provider.dart';
import 'CommonWidgets/core/providers/theme_provider.dart';
import 'LoginPages/login/pages/login_screen.dart';
import 'LoginPages/startPages/splash_screen.dart';
import 'MainScreens/Attendance/AttendanceCreate/bloc/create_attendance_bloc.dart';
import 'MainScreens/Attendance/AttendanceCreate/services/attendance_create_service.dart';
import 'MainScreens/Attendance/AttendanceForm/bloc/attendance_form_bloc.dart';
import 'MainScreens/Attendance/AttendanceList/bloc/attendance_list_bloc.dart';
import 'MainScreens/Attendance/AttendanceList/services/attendance_list_service.dart';
import 'MainScreens/Calendar/bloc/calendar_bloc.dart';
import 'MainScreens/Calendar/bloc/calendar_event.dart';
import 'MainScreens/Dashboard/AttendanceDashboard/bloc/attendance_dashboard_bloc.dart';
import 'MainScreens/Dashboard/AttendanceDashboard/services/attendance_dashboard_service.dart';
import 'MainScreens/Dashboard/LeaveHistory/bloc/leave_history_bloc.dart';
import 'MainScreens/Dashboard/PendingLeaves/bloc/pending_leave_bloc.dart';
import 'MainScreens/Dashboard/Report/bloc/report_bloc.dart';
import 'MainScreens/Dashboard/Report/bloc/report_event.dart';
import 'MainScreens/Dashboard/RequestAbsence/bloc/request_absence_bloc.dart';
import 'MainScreens/Dashboard/RequestAbsence/bloc/request_absence_event.dart';
import 'MainScreens/Employees/EmployeeCreate/bloc/employee_create_bloc.dart';
import 'MainScreens/Employees/EmployeeCreate/bloc/employee_create_event.dart';
import 'MainScreens/Employees/EmployeeForm/Form/bloc/employee_form_bloc.dart';
import 'MainScreens/Employees/EmployeeForm/SmartTabs/PrivateInfo/bloc/private_info_bloc.dart';
import 'MainScreens/Employees/EmployeeForm/SmartTabs/PrivateInfo/bloc/private_info_event.dart';
import 'MainScreens/Employees/EmployeeForm/SmartTabs/WorkInfo/bloc/work_info_bloc.dart';
import 'MainScreens/Employees/EmployeeList/bloc/employee_list_bloc.dart';
import 'Profile/settings/services/settings_storage_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Entry point of the application.
///
/// Responsibilities:
///   • Ensures Flutter bindings are initialized
///   • Initializes date formatting for intl
///   • Loads saved language and preloads translations if needed
///   • Loads reduce motion preference
///   • Initializes and plays splash video
///   • Sets up all global providers (Theme, Language, Motion, Company, etc.)
///   • Registers all BLoCs used across the app (most are pre-loaded eagerly)
///   • Starts the app with [LoginApp] as root widget
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize locale-specific date/number formatting
  await initializeDateFormatting();

  // Initialize persistent storage service
  final settingsStorageService = SettingsStorageService();
  await settingsStorageService.initialize();

  // Load saved language (fallback to English)
  final languageCode =
      await settingsStorageService.getString('languageCode') ?? 'en';

  // Set up translation provider and preload common strings if cache missing
  final translationService = LanguageProvider();
  await translationService.initializeTranslator(languageCode);
  if (!settingsStorageService.exists('translation_cache_$languageCode')) {
    await translationService.preload(TranslationStrings.preloadKeys);
  }

  // Load reduce motion preference (accessibility)
  final reduceMotion =
      await settingsStorageService.getBool('reduceMotion') ?? false;

  // Initialize and start splash screen background video
  final VideoPlayerController videoController = VideoPlayerController.asset(
    'assets/Attendance.mp4',
  );
  await videoController.initialize();
  videoController.setLooping(false);
  videoController.play();

  runApp(
    MultiProvider(
      providers: [
        // Language & localization
        ChangeNotifierProvider.value(value: translationService),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),

        // Theme & appearance
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(
          create: (_) => MotionProvider()..setReduceMotion(reduceMotion),
        ),

        // Company/session data
        ChangeNotifierProvider(
          create: (_) {
            final p = CompanyProvider();
            p.initialize();
            return p;
          },
        ),

        // Splash video controller (accessible app-wide if needed)
        ListenableProvider<VideoPlayerController>.value(value: videoController),
      ],
      child: MultiBlocProvider(
        providers: [
          // Dashboard & main data BLoCs (eagerly loaded)
          BlocProvider<AttendanceDashboardBloc>(
            create: (_) =>
                AttendanceDashboardBloc(AttendanceDashboardService())
                  ..add(LoadDashboardData()),
            lazy: false,
          ),
          BlocProvider<ReportBloc>(
            create: (_) => ReportBloc()..add(InitializeReport()),
            lazy: false,
          ),
          BlocProvider<LeaveHistoryBloc>(
            create: (_) => LeaveHistoryBloc()..add(InitializeLeaveHistory()),
            lazy: false,
          ),
          BlocProvider<PendingLeaveBloc>(
            create: (_) => PendingLeaveBloc()..add(InitializePendingLeave()),
            lazy: false,
          ),
          BlocProvider<RequestAbsenceBloc>(
            create: (_) => RequestAbsenceBloc()..add(InitializeRequestAbsence()),
            lazy: false,
          ),

          // Employee & attendance related BLoCs
          BlocProvider<EmployeeListBloc>(
            create: (_) => EmployeeListBloc()..add(InitializeEmployeeList()),
            lazy: false,
          ),
          BlocProvider<AttendanceListBloc>(
            create: (_) =>
                AttendanceListBloc(AttendanceListService())
                  ..add(const LoadAttendance(page: 0)),
            lazy: false,
          ),
          BlocProvider<CalendarBloc>(
            create: (_) => CalendarBloc()
              ..add(
                LoadCalendarData(
                  month: DateFormat.MMMM().format(DateTime.now()),
                  year: DateTime.now().year,
                ),
              ),
            lazy: false,
          ),

          // Form & creation BLoCs
          BlocProvider<EmployeeCreateBloc>(
            create: (_) =>
                EmployeeCreateBloc()..add(InitializeCreateEmployee()),
            lazy: false,
          ),
          BlocProvider<CreateAttendanceBloc>(
            create: (_) =>
                CreateAttendanceBloc(AttendanceCreateService())
                  ..add(InitializeCreateAttendanceDetails()),
            lazy: false,
          ),
          BlocProvider<EmployeeFormBloc>(
            create: (_) =>
            EmployeeFormBloc()
              ..add(LoadEmployeeDetails()),
            lazy: false,
          ),
          BlocProvider<AttendanceFormBloc>(
            create: (_) =>
            AttendanceFormBloc()
              ..add(InitializeAttendanceDetails()),
            lazy: false,
          ),
          BlocProvider<PrivateInfoBloc>(
            create: (_) =>
            PrivateInfoBloc()
              ..add(LoadPrivateInfoDetails()),
            lazy: false,
          ),
          BlocProvider<WorkInfoBloc>(
            create: (_) =>
            WorkInfoBloc()
              ..add(LoadWorkInfoDetails()),
            lazy: false,
          ),
        ],
        child: LoginApp(),
      ),
    ),
  );
}

/// Root widget of the application after providers are set up.
///
/// Handles:
///   • Theme switching (light/dark)
///   • Motion reduction (accessibility)
///   • Navigation key for global routing
///   • Custom page transitions (fade or instant based on reduce motion)
///   • Initial route handling (splash → login)
class LoginApp extends StatefulWidget {
  @override
  _LoginAppState createState() => _LoginAppState();
}

class _LoginAppState extends State<LoginApp> {
  @override
  void initState() {
    super.initState();

    // Load saved locale & track app open for review prompt logic
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LocaleProvider>().loadSavedLocale();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return  MaterialApp(
      title: 'Login Page',
      theme: themeProvider.lightTheme,
      darkTheme: themeProvider.darkTheme,
      themeMode: themeProvider.themeMode,
      debugShowCheckedModeBanner: false,

      // Global keys for navigation & snackbars
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: scaffoldMessengerKey,

      initialRoute: '/',
      onGenerateRoute: (settings) {
        WidgetBuilder builder;

        switch (settings.name) {
          case '/':
            builder = (context) => SplashScreen();
            break;
          case '/login':
            builder = (context) => LoginScreen();
            break;
          default:
            builder = (context) => SplashScreen();
        }

        final motionProvider = Provider.of<MotionProvider>(
          navigatorKey.currentContext!,
          listen: false,
        );

        return PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionDuration: motionProvider.reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 300),
          reverseTransitionDuration: motionProvider.reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 300),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            if (motionProvider.reduceMotion) return child;
            return FadeTransition(opacity: animation, child: child);
          },
        );
      },
    );
  }
}
