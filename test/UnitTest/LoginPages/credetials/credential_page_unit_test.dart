import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mobo_attendance/CommonWidgets/core/company/services/company_session_service.dart';
import 'package:mobo_attendance/LoginPages/credetials/bloc/credentials_bloc.dart';
import 'package:mobo_attendance/LoginPages/login/models/session_model.dart';
import 'package:mobo_attendance/MainScreens/AppBars/services/common_storage_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockCompanySessionService extends Mock implements CompanySessionService {}

class MockCommonStorageService extends Mock implements CommonStorageService {}

class FakeBuildContext extends Fake implements BuildContext {
  @override
  bool get mounted => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockCompanySessionService mockCompanySessionService;
  late MockCommonStorageService mockCommonStorageService;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockCompanySessionService = MockCompanySessionService();
    mockCommonStorageService = MockCommonStorageService();
  });

  setUpAll(() {
    registerFallbackValue(FakeBuildContext());
  });

  group('CredentialsBloc - Submit Credentials', () {
    blocTest(
      'Emits loading and session when login succeeds',
      build: () {
        when(
          () => mockCompanySessionService.loginAndSaveSession(
            serverUrl: any(named: 'serverUrl'),
            database: any(named: 'database'),
            userLogin: any(named: 'userLogin'),
            password: any(named: 'password'),
          ),
        ).thenAnswer((_) async => true);
        when(() => mockCompanySessionService.getCurrentSession()).thenAnswer(
          (_) async => SessionModel(
            userName: 'John',
            userLogin: 'john',
            userId: 1,
            sessionId: 'abc',
            serverVersion: '17.0',
            userLang: 'en',
            partnerId: 10,
            userTimezone: 'UTC',
            companyId: 1,
            companyName: 'Test Company',
            isSystem: false,
          ),
        );
        when(
          () => mockCommonStorageService.saveAccount(any()),
        ).thenAnswer((_) async => {});
        return CredentialsBloc(
          sessionService: mockCompanySessionService,
          commonStorageService: mockCommonStorageService,
        );
      },
      act: (bloc) => bloc.add(
        SubmitLogin(
          context: FakeBuildContext(),
          protocol: 'https://',
          url: 'demo.odoo.com',
          database: 'demo',
          username: 'admin',
          password: 'admin',
        ),
      ),
      expect: () => [
        CredentialsState.initial().copyWith(
          isLoading: true,
          errorMessage: null,
        ),
        isA<CredentialsState>()
            .having((s) => s.isLoading, 'isLoading', false)
            .having((s) => s.loginSuccess, 'loginSuccess', true)
            .having((s) => s.session, 'session', isNotNull),
      ],
      verify: (_) {
        verify(
          () => mockCompanySessionService.loginAndSaveSession(
            serverUrl: 'https://demo.odoo.com',
            database: 'demo',
            userLogin: 'admin',
            password: 'admin',
          ),
        ).called(1);

        verify(() => mockCommonStorageService.saveAccount(any())).called(1);
      },
    );

    blocTest(
      'Emits loading and errorMessage when login fails',
      build: () {
        when(
          () => mockCompanySessionService.loginAndSaveSession(
            serverUrl: any(named: 'serverUrl'),
            database: any(named: 'database'),
            userLogin: any(named: 'userLogin'),
            password: any(named: 'password'),
          ),
        ).thenAnswer((_) async => false);
        return CredentialsBloc(
          sessionService: mockCompanySessionService,
          commonStorageService: mockCommonStorageService,
        );
      },
      act: (bloc) => bloc.add(
        SubmitLogin(
          context: FakeBuildContext(),
          protocol: 'https://',
          url: 'demo.odoo.com',
          database: 'demo',
          username: 'admin',
          password: 'admin',
        ),
      ),
      expect: () => [
        CredentialsState.initial().copyWith(
          isLoading: true,
          errorMessage: null,
        ),
        isA<CredentialsState>()
            .having((s) => s.isLoading, 'isLoading', false)
            .having(
              (s) => s.errorMessage,
              'errorMessage',
              'Authentication failed.',
            ),
      ],
      verify: (_) {
        verify(
          () => mockCompanySessionService.loginAndSaveSession(
            serverUrl: 'https://demo.odoo.com',
            database: 'demo',
            userLogin: 'admin',
            password: 'admin',
          ),
        ).called(1);
      },
    );

    blocTest(
      'Emits loading and errorMessage when login throws exception',
      build: () {
        when(
          () => mockCompanySessionService.loginAndSaveSession(
            serverUrl: any(named: 'serverUrl'),
            database: any(named: 'database'),
            userLogin: any(named: 'userLogin'),
            password: any(named: 'password'),
          ),
        ).thenThrow(Exception('Network error'));
        return CredentialsBloc(
          sessionService: mockCompanySessionService,
          commonStorageService: mockCommonStorageService,
        );
      },
      act: (bloc) => bloc.add(
        SubmitLogin(
          context: FakeBuildContext(),
          protocol: 'https://',
          url: 'demo.odoo.com',
          database: 'demo',
          username: 'admin',
          password: 'admin',
        ),
      ),
      expect: () => [
        CredentialsState.initial().copyWith(
          isLoading: true,
          errorMessage: null,
        ),
        isA<CredentialsState>()
            .having((s) => s.isLoading, 'isLoading', false)
            .having(
              (s) => s.errorMessage,
              'errorMessage',
              'Network connection failed. Please check your internet connection.',
            ),
      ],
      verify: (_) {
        verify(
          () => mockCompanySessionService.loginAndSaveSession(
            serverUrl: 'https://demo.odoo.com',
            database: 'demo',
            userLogin: 'admin',
            password: 'admin',
          ),
        ).called(1);
      },
    );
  });
}
