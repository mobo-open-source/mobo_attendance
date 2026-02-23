import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_attendance/MainScreens/Dashboard/AttendanceDashboard/bloc/attendance_dashboard_bloc.dart';
import 'package:mobo_attendance/MainScreens/Dashboard/AttendanceDashboard/services/attendance_dashboard_service.dart';
import 'package:mocktail/mocktail.dart';

class TestAttendanceDashboardBloc extends AttendanceDashboardBloc {
  TestAttendanceDashboardBloc(super.service);

  @override
  Future<Map<String, dynamic>> getLocationAndNetworkInfo() async {
    return {
      "latitude": 10.0,
      "longitude": 20.0,
      "country": "India",
      "ip": "127.0.0.1",
    };
  }
}

class MockAttendanceDashboardService extends Mock
    implements AttendanceDashboardService {}

void main() {
  late MockAttendanceDashboardService mockService;
  late AttendanceDashboardBloc bloc;

  setUp(() {
    mockService = MockAttendanceDashboardService();
    bloc = TestAttendanceDashboardBloc(mockService);
  });

  group('AttendanceDashboardBloc - Check-in', () {
    blocTest<AttendanceDashboardBloc, AttendanceDashboardState>(
      'emits loading states when check-in succeeds',
      build: () {
        when(
          () => mockService.createAttendanceDetails(any()),
        ).thenAnswer((_) async => true);
        return bloc;
      },
      act: (bloc) => bloc.add(CheckInRequested()),
      expect: () => [
        isA<AttendanceDashboardState>().having(
          (s) => s.isCheckInLoading,
          'loading start',
          true,
        ),
        isA<AttendanceDashboardState>().having(
          (s) => s.isCheckInLoading,
          'loading end',
          false,
        ),
        isA<AttendanceDashboardState>(),
      ],
      verify: (_) {
        verify(
          () => mockService.createAttendanceDetails(
            any(that: containsPair('in_mode', 'systray')),
          ),
        ).called(1);
      },
    );

    blocTest<AttendanceDashboardBloc, AttendanceDashboardState>(
      'emits loading states and errorMessage when check-in fails',
      build: () {
        when(
          () => mockService.createAttendanceDetails(any()),
        ).thenAnswer((_) async => false);
        return bloc;
      },
      act: (bloc) => bloc.add(CheckInRequested()),
      expect: () => [
        isA<AttendanceDashboardState>().having(
          (s) => s.isCheckInLoading,
          'loading start',
          true,
        ),
        isA<AttendanceDashboardState>().having(
          (s) => s.errorMessage,
          'errorMessage',
          'Check-in failed',
        ),
        isA<AttendanceDashboardState>().having(
          (s) => s.isCheckInLoading,
          'loading end',
          false,
        ),
      ],
      verify: (_) {
        verify(
          () => mockService.createAttendanceDetails(
            any(that: containsPair('in_mode', 'systray')),
          ),
        ).called(1);
      },
    );

    blocTest<AttendanceDashboardBloc, AttendanceDashboardState>(
      'emits loading states and errorMessage when check-in throws an exception',
      build: () {
        when(
          () => mockService.createAttendanceDetails(any()),
        ).thenThrow(Exception('Network error'));
        return bloc;
      },
      act: (bloc) => bloc.add(CheckInRequested()),
      expect: () => [
        isA<AttendanceDashboardState>().having(
          (s) => s.isCheckInLoading,
          'loading start',
          true,
        ),
        isA<AttendanceDashboardState>().having(
          (s) => s.errorMessage,
          'errorMessage',
          'Something went wrong, Please try again later.',
        ),
        isA<AttendanceDashboardState>().having(
          (s) => s.isCheckInLoading,
          'loading end',
          false,
        ),
      ],
      verify: (_) {
        verify(
          () => mockService.createAttendanceDetails(
            any(that: containsPair('in_mode', 'systray')),
          ),
        ).called(1);
      },
    );
  });

  group('AttendanceDashboardBloc - Check-out', () {
    blocTest<AttendanceDashboardBloc, AttendanceDashboardState>(
      'emits loading states when check-out succeeds',
      build: () {
        when(
          () => mockService.writeAttendanceDetails(any()),
        ).thenAnswer((_) async => true);
        return bloc;
      },
      act: (bloc) => bloc.add(CheckOutRequested()),
      expect: () => [
        isA<AttendanceDashboardState>().having(
          (s) => s.isCheckInLoading,
          'loading start',
          true,
        ),
        isA<AttendanceDashboardState>().having(
          (s) => s.isCheckInLoading,
          'loading end',
          false,
        ),
        isA<AttendanceDashboardState>(),
      ],
      verify: (_) {
        verify(
          () => mockService.writeAttendanceDetails(
            any(that: containsPair('out_mode', 'systray')),
          ),
        ).called(1);
      },
    );

    blocTest<AttendanceDashboardBloc, AttendanceDashboardState>(
      'emits loading states and errorMessage when check-out fails',
      build: () {
        when(
          () => mockService.writeAttendanceDetails(any()),
        ).thenAnswer((_) async => false);
        return bloc;
      },
      act: (bloc) => bloc.add(CheckOutRequested()),
      expect: () => [
        isA<AttendanceDashboardState>().having(
          (s) => s.isCheckInLoading,
          'loading start',
          true,
        ),
        isA<AttendanceDashboardState>().having(
          (s) => s.errorMessage,
          'errorMessage',
          'Check-out failed',
        ),
        isA<AttendanceDashboardState>().having(
          (s) => s.isCheckInLoading,
          'loading end',
          false,
        ),
      ],
      verify: (_) {
        verify(
          () => mockService.writeAttendanceDetails(
            any(that: containsPair('out_mode', 'systray')),
          ),
        ).called(1);
      },
    );

    blocTest<AttendanceDashboardBloc, AttendanceDashboardState>(
      'emits loading states and errorMessage when check-out throws an exception',
      build: () {
        when(
          () => mockService.writeAttendanceDetails(any()),
        ).thenThrow(Exception('Network error'));
        return bloc;
      },
      act: (bloc) => bloc.add(CheckOutRequested()),
      expect: () => [
        isA<AttendanceDashboardState>().having(
          (s) => s.isCheckInLoading,
          'loading start',
          true,
        ),
        isA<AttendanceDashboardState>().having(
          (s) => s.errorMessage,
          'errorMessage',
          'Something went wrong, Please try again later.',
        ),
        isA<AttendanceDashboardState>().having(
          (s) => s.isCheckInLoading,
          'loading end',
          false,
        ),
      ],
      verify: (_) {
        verify(
          () => mockService.writeAttendanceDetails(
            any(that: containsPair('out_mode', 'systray')),
          ),
        ).called(1);
      },
    );
  });
}
