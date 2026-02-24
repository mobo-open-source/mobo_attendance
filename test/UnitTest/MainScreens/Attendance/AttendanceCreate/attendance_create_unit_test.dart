import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_attendance/MainScreens/Attendance/AttendanceCreate/bloc/create_attendance_bloc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:bloc_test/bloc_test.dart';

import 'package:mobo_attendance/MainScreens/Attendance/AttendanceCreate/services/attendance_create_service.dart';

class MockAttendanceCreateService extends Mock
    implements AttendanceCreateService {}

void main() {
  late MockAttendanceCreateService mockAttendanceCreateService;
  setUp(() {
    mockAttendanceCreateService = MockAttendanceCreateService();
  });

  group('CreateAttendanceBloc - Attendance creation', () {
    blocTest<CreateAttendanceBloc, CreateAttendanceState>(
      'emits [CreateAttendanceSaving, CreateAttendanceSuccess] when attendance creation succeeds',
      build: () {
        when(
          () => mockAttendanceCreateService.isEmployeeAlreadyCheckedIn(any()),
        ).thenAnswer((_) async => false);

        when(
          () => mockAttendanceCreateService.createAttendanceDetails(any()),
        ).thenAnswer((_) async => {'success': true, 'attendance_id': 1});

        return CreateAttendanceBloc(mockAttendanceCreateService);
      },
      seed: () => CreateAttendanceLoaded(
        employees: const [],
        selectedEmployeeId: 1,
        selectedEmployeeName: 'John Doe',
        checkIn: '2025-01-01 09:00',
        checkOut: '2025-01-01 18:00',
        workedHours: '09:00',
        isEmployeeSelect: true,
      ),
      act: (bloc) {
        bloc.add(SaveAttendance());
      },
      expect: () => [
        isA<CreateAttendanceSaving>(),
        isA<CreateAttendanceSuccess>()
            .having((s) => s.attendanceId, 'attendanceId', 1)
            .having(
              (s) => s.message,
              'message',
              'Attendance created successfully',
            ),
      ],
      verify: (_) {
        verify(
          () => mockAttendanceCreateService.createAttendanceDetails(any()),
        ).called(1);
        verify(
          () => mockAttendanceCreateService.isEmployeeAlreadyCheckedIn(1),
        ).called(1);
      },
    );

    blocTest(
      'emits [CreateAttendanceSaving, CreateAttendanceLoaded] when attendance creation is failed',
      build: () {
        when(
          () => mockAttendanceCreateService.isEmployeeAlreadyCheckedIn(any()),
        ).thenAnswer((_) async => false);
        when(
          () => mockAttendanceCreateService.createAttendanceDetails(any()),
        ).thenAnswer(
          (_) async => {'success': false, 'error': 'Exception error'},
        );
        return CreateAttendanceBloc(mockAttendanceCreateService);
      },
      seed: () => CreateAttendanceLoaded(
        employees: const [],
        selectedEmployeeId: 1,
        selectedEmployeeName: 'John Doe',
        checkIn: '2025-01-01 09:00',
        checkOut: '2025-01-01 18:00',
        workedHours: '09:00',
        isEmployeeSelect: true,
      ),
      act: (bloc) => bloc.add(SaveAttendance()),
      expect: () => [
        isA<CreateAttendanceSaving>(),
        isA<CreateAttendanceLoaded>().having(
          (s) => s.errorMessage,
          'errorMessage',
          'Exception error',
        ),
      ],
      verify: (_) {
        verify(
          () => mockAttendanceCreateService.isEmployeeAlreadyCheckedIn(any()),
        ).called(1);
        verify(
          () => mockAttendanceCreateService.createAttendanceDetails(any()),
        ).called(1);
      },
    );

    blocTest(
      'emits [CreateAttendanceSaving, CreateAttendanceError] when attendance is already exist',
      build: () {
        when(
          () => mockAttendanceCreateService.isEmployeeAlreadyCheckedIn(any()),
        ).thenAnswer((_) async => true);
        return CreateAttendanceBloc(mockAttendanceCreateService);
      },
      seed: () => CreateAttendanceLoaded(
        employees: const [],
        selectedEmployeeId: 1,
        selectedEmployeeName: 'John Doe',
        checkIn: '2025-01-01 09:00',
        checkOut: '2025-01-01 18:00',
        workedHours: '09:00',
        isEmployeeSelect: true,
      ),
      act: (bloc) => bloc.add(SaveAttendance()),
      expect: () => [
        isA<CreateAttendanceSaving>(),
        isA<CreateAttendanceError>().having(
          (s) => s.message,
          'message',
          "Cannot create new attendance_onSaveAttendance for John Doe. Employee hasn't checked out yet.",
        ),
        isA<CreateAttendanceLoaded>(),
      ],
      verify: (_) {
        verify(
          () => mockAttendanceCreateService.isEmployeeAlreadyCheckedIn(any()),
        ).called(1);
      },
    );

    blocTest(
      'emits [CreateAttendanceSaving, CreateAttendanceError] when employee is not selected',
      build: () {
        return CreateAttendanceBloc(mockAttendanceCreateService);
      },
      seed: () => CreateAttendanceLoaded(
        employees: const [],
        selectedEmployeeId: null,
        selectedEmployeeName: null,
        checkIn: '2025-01-01 09:00',
        checkOut: '2025-01-01 18:00',
        workedHours: '09:00',
        isEmployeeSelect: true,
      ),
      act: (bloc) => bloc.add(SaveAttendance()),
      expect: () => [
        isA<CreateAttendanceError>().having(
          (s) => s.message,
          'message',
          "Please select an employee",
        ),
        isA<CreateAttendanceLoaded>(),
      ],
    );
  });
}
