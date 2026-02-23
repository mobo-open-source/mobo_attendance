import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mobo_attendance/LoginPages/login/bloc/login_bloc.dart';
import 'package:mobo_attendance/LoginPages/login/services/network_service.dart';
import 'package:mocktail/mocktail.dart';

class MockNetworkService extends Mock implements NetworkService {}

void main() {
  late MockNetworkService mockNetworkService;
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    mockNetworkService = MockNetworkService();
  });

  group('LoginBloc - Fetch Databases', () {
    blocTest(
      'Emits loading states and db list when fetch database succeeds',
      build: () {
        when(
          () => mockNetworkService.fetchDatabaseList(any()),
        ).thenAnswer((_) async => ['db1', 'db2']);
        return LoginBloc(service: mockNetworkService);
      },
      act: (bloc) => bloc.add(FetchDatabases('https://demo.odoo.com')),
      expect: () => [
        isA<LoginState>()
            .having((s) => s.isLoading, 'isLoading', true)
            .having((s) => s.errorMessage, 'errorMessage', ""),
        isA<LoginState>()
            .having((s) => s.isLoading, 'isLoading', true)
            .having((s) => s.databases, 'databases', ['db1', 'db2']),
        isA<LoginState>()
            .having((s) => s.isLoading, 'isLoading', false)
            .having((s) => s.databases, 'databases', ['db1', 'db2']),
      ],
      verify: (_) {
        verify(() => mockNetworkService.fetchDatabaseList(any())).called(1);
      },
    );

    blocTest(
      'Emits loading states and empty list when fetch database succeeds with empty',
      build: () {
        when(
          () => mockNetworkService.fetchDatabaseList(any()),
        ).thenAnswer((_) async => []);
        return LoginBloc(service: mockNetworkService);
      },
      act: (bloc) => bloc.add(FetchDatabases('https://demo.odoo.com')),
      expect: () => [
        isA<LoginState>()
            .having((s) => s.isLoading, 'isLoading', true)
            .having((s) => s.errorMessage, 'errorMessage', ""),
        isA<LoginState>()
            .having((s) => s.isLoading, 'isLoading', true)
            .having((s) => s.showManualDbInput, 'showManualDbInput', true)
            .having((s) => s.databases, 'databases', []),
        isA<LoginState>()
            .having((s) => s.isLoading, 'isLoading', false)
            .having((s) => s.databases, 'databases', []),
      ],
      verify: (_) {
        verify(() => mockNetworkService.fetchDatabaseList(any())).called(1);
      },
    );

    blocTest(
      'Emits loading states and error message when fetch database throws an exception',
      build: () {
        when(
          () => mockNetworkService.fetchDatabaseList(any()),
        ).thenThrow(Exception('Network Error'));
        return LoginBloc(service: mockNetworkService);
      },
      act: (bloc) => bloc.add(FetchDatabases('https://demo.odoo.com')),
      expect: () => [
        isA<LoginState>()
            .having((s) => s.isLoading, 'isLoading', true)
            .having((s) => s.errorMessage, 'errorMessage', ""),
        isA<LoginState>()
            .having((s) => s.isLoading, 'isLoading', true)
            .having(
              (s) => s.errorMessage,
          'errorMessage',
          "Network connection failed. Please check your internet connection.",
        ),
        isA<LoginState>()
            .having((s) => s.isLoading, 'isLoading', false)
            .having(
              (s) => s.errorMessage,
          'errorMessage',
          "Network connection failed. Please check your internet connection.",
        ),
      ],
      verify: (_) {
        verify(() => mockNetworkService.fetchDatabaseList(any())).called(1);
      },
    );
  });
}
