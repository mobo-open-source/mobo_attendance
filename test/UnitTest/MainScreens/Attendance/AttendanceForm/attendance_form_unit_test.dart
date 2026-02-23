import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mobo_attendance/MainScreens/Attendance/AttendanceForm/bloc/attendance_form_bloc.dart';
import 'package:mobo_attendance/MainScreens/Attendance/AttendanceForm/services/attendance_form_service.dart';
import 'package:mocktail/mocktail.dart';

class MockAttendanceFormService extends Mock implements AttendanceFormService {}

void main() {
  late MockAttendanceFormService mockAttendanceFormService;

  setUp(() {
    mockAttendanceFormService = MockAttendanceFormService();
  });

  group('AttendanceFormBloc - Update attendance form', () {
    blocTest(
      'emits success flow and reloads attendance when attendance update succeeds',
      build: () {
        when(
          () => mockAttendanceFormService.canManageSkills(),
        ).thenAnswer((_) async => true);

        when(() => mockAttendanceFormService.fetchAttendance(any())).thenAnswer(
          (_) async => [
            {
              'id': 1,
              'employee_id': [1, 'demo'],
              'employee_image': null,
              'check_in': '2025-01-01 09:00:00',
              'check_out': '2025-01-01 17:00:00',
            },
          ],
        );
        when(
          () => mockAttendanceFormService.updateAttendance(any(), any()),
        ).thenAnswer((_) async => {'success': true, 'error': null});
        return AttendanceFormBloc(service: mockAttendanceFormService);
      },
      seed: () => AttendanceFormLoaded(
        record: {'id': 1},
        formattedHours: '08:00',
        employees: const [],
        hasEditAccess: true,
      ),
      act: (bloc) => bloc.add(
        SaveAttendance(
          employeeId: 1,
          checkIn: '2025-01-01 09:00:00',
          checkOut: '2025-01-01 17:00:00',
          employeeName: 'demo',
        ),
      ),
      expect: () => [
        isA<AttendanceFormLoaded>().having((s) => s.isSaving, 'isSaving', true),
        isA<AttendanceFormLoaded>()
            .having((s) => s.isSaving, 'isSaving', false)
            .having(
              (s) => s.successMessage,
              'successMessage',
              'Attendance updated successfully',
            ),
        isA<AttendanceFormLoading>(),

        isA<AttendanceFormLoaded>(),
      ],
      verify: (bloc) {
        verify(
          () => mockAttendanceFormService.updateAttendance(1, any()),
        ).called(1);
      },
    );

    blocTest(
      'emits error state when attendance update fails due to service returning an error',
      build: () {
        when(
          () => mockAttendanceFormService.canManageSkills(),
        ).thenAnswer((_) async => true);

        when(() => mockAttendanceFormService.fetchAttendance(any())).thenAnswer(
          (_) async => [
            {
              'id': 1,
              'employee_id': [1, 'demo'],
              'employee_image': null,
              'check_in': '2025-01-01 09:00:00',
              'check_out': '2025-01-01 17:00:00',
            },
          ],
        );
        when(
          () => mockAttendanceFormService.updateAttendance(any(), any()),
        ).thenAnswer(
          (_) async => {'success': false, 'error': "Attendance update error"},
        );
        return AttendanceFormBloc(service: mockAttendanceFormService);
      },
      seed: () => AttendanceFormLoaded(
        record: {'id': 1},
        formattedHours: '08:00',
        employees: const [],
        hasEditAccess: true,
      ),
      act: (bloc) => bloc.add(
        SaveAttendance(
          employeeId: 1,
          checkIn: '2025-01-01 09:00:00',
          checkOut: '2025-01-01 17:00:00',
          employeeName: 'demo',
        ),
      ),
      expect: () => [
        isA<AttendanceFormLoaded>().having((s) => s.isSaving, 'isSaving', true),
        isA<AttendanceFormLoaded>()
            .having((s) => s.isSaving, 'isSaving', false)
            .having(
              (s) => s.errorMessage,
              'errorMessage',
              'Attendance update error',
            ),
      ],
      verify: (bloc) {
        verify(
          () => mockAttendanceFormService.updateAttendance(1, any()),
        ).called(1);
      },
    );

    blocTest(
      'emits error state when attendance update throws an exception',
      build: () {
        when(
          () => mockAttendanceFormService.canManageSkills(),
        ).thenAnswer((_) async => true);

        when(() => mockAttendanceFormService.fetchAttendance(any())).thenAnswer(
          (_) async => [
            {
              'id': 1,
              'employee_id': [1, 'demo'],
              'employee_image': null,
              'check_in': '2025-01-01 09:00:00',
              'check_out': '2025-01-01 17:00:00',
            },
          ],
        );
        when(
          () => mockAttendanceFormService.updateAttendance(any(), any()),
        ).thenThrow(Exception('Something went wrong, Please try again later'));
        return AttendanceFormBloc(service: mockAttendanceFormService);
      },
      seed: () => AttendanceFormLoaded(
        record: {'id': 1},
        formattedHours: '08:00',
        employees: const [],
        hasEditAccess: true,
      ),
      act: (bloc) => bloc.add(
        SaveAttendance(
          employeeId: 1,
          checkIn: '2025-01-01 09:00:00',
          checkOut: '2025-01-01 17:00:00',
          employeeName: 'demo',
        ),
      ),
      expect: () => [
        isA<AttendanceFormLoaded>().having((s) => s.isSaving, 'isSaving', true),
        isA<AttendanceFormLoaded>()
            .having((s) => s.isSaving, 'isSaving', false)
            .having(
              (s) => s.errorMessage,
              'errorMessage',
              'Something went wrong, Please try again later',
            ),
      ],
      verify: (bloc) {
        verify(
          () => mockAttendanceFormService.updateAttendance(1, any()),
        ).called(1);
      },
    );
  });
}
