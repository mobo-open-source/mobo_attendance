import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mobo_attendance/MainScreens/Dashboard/RequestAbsence/bloc/request_absence_bloc.dart';
import 'package:mobo_attendance/MainScreens/Dashboard/RequestAbsence/bloc/request_absence_event.dart';
import 'package:mobo_attendance/MainScreens/Dashboard/RequestAbsence/bloc/request_absence_state.dart';
import 'package:mobo_attendance/MainScreens/Dashboard/RequestAbsence/services/request_absence_service.dart';
import 'package:mocktail/mocktail.dart';

class MockRequestAbsenceService extends Mock implements RequestAbsenceService {}

class FakePlatformFile extends Fake implements PlatformFile {}

void main() {
  late MockRequestAbsenceService mockRequestAbsenceService;

  setUp(() {
    mockRequestAbsenceService = MockRequestAbsenceService();
    registerFallbackValue(FakePlatformFile());
  });

  group('RequestAbsenceBloc - Submit Request', () {
    blocTest(
      "emits loading state and make success as true when submit absence succeeds",
      build: () {
        when(
          () => mockRequestAbsenceService.createRequestAbsence(any()),
        ).thenAnswer((_) async => {'success': true, 'id': 1});
        return RequestAbsenceBloc(service: mockRequestAbsenceService);
      },
      seed: () => RequestAbsenceState(
        selectedHolidayStatusId: 1,
        dateFrom: '2025-01-29',
        dateTo: '2025-01-29',
        durationDays: '2',
        selectedEmployeeId: 1,
      ),
      act: (bloc) => bloc.add(SubmitLeaveRequest()),
      expect: () => [
        isA<RequestAbsenceState>()
            .having((s) => s.isSaving, 'isSaving', true)
            .having((s) => s.errorMessage, 'errorMessage', null),

        isA<RequestAbsenceState>()
            .having((s) => s.isSaving, 'isSaving', false)
            .having((s) => s.success, 'success', true),
      ],
      verify: (_) {
        verify(
          () => mockRequestAbsenceService.createRequestAbsence(any()),
        ).called(1);
      },
    );

    blocTest(
      "emits loading state and errorMessage when submit absence fails",
      build: () {
        when(
          () => mockRequestAbsenceService.createRequestAbsence(any()),
        ).thenAnswer(
          (_) async => {
            'success': false,
            'error': 'Invalid response from server',
          },
        );
        return RequestAbsenceBloc(service: mockRequestAbsenceService);
      },
      seed: () => RequestAbsenceState(
        selectedHolidayStatusId: 1,
        dateFrom: '2025-01-29',
        dateTo: '2025-01-29',
        durationDays: '2',
        selectedEmployeeId: 1,
      ),
      act: (bloc) => bloc.add(SubmitLeaveRequest()),
      expect: () => [
        isA<RequestAbsenceState>()
            .having((s) => s.isSaving, 'isSaving', true)
            .having((s) => s.errorMessage, 'errorMessage', null),

        isA<RequestAbsenceState>()
            .having((s) => s.isSaving, 'isSaving', false)
            .having(
              (s) => s.errorMessage,
              'errorMessage',
              'Invalid response from server',
            ),
      ],
      verify: (_) {
        verify(
          () => mockRequestAbsenceService.createRequestAbsence(any()),
        ).called(1);
      },
    );

    blocTest<RequestAbsenceBloc, RequestAbsenceState>(
      'uploads attachment and submits leave request when attachedFile is not null',
      build: () {
        when(
          () => mockRequestAbsenceService.initializeClient(),
        ).thenAnswer((_) async {});

        when(
          () => mockRequestAbsenceService.uploadAttachment(
            file: any<PlatformFile>(named: 'file'),
            model: any<String>(named: 'model'),
          ),
        ).thenAnswer((_) async => 10);

        when(
          () => mockRequestAbsenceService.createRequestAbsence(any()),
        ).thenAnswer((_) async => {'success': true});

        return RequestAbsenceBloc(service: mockRequestAbsenceService);
      },

      seed: () => RequestAbsenceState().copyWith(
        selectedHolidayStatusId: 1,
        attachedFile: PlatformFile(
          name: 'test.pdf',
          size: 100,
          path: '/tmp/test.pdf',
        ),
        dateFrom: '2025-01-29',
        dateTo: '2025-01-29',
        durationDays: '2',
      ),

      act: (bloc) => bloc.add(SubmitLeaveRequest()),

      expect: () => [
        isA<RequestAbsenceState>().having((s) => s.isSaving, 'isSaving', true),

        isA<RequestAbsenceState>()
            .having((s) => s.isSaving, 'isSaving', false)
            .having((s) => s.success, 'success', true),
      ],

      verify: (_) {
        verify(() => mockRequestAbsenceService.initializeClient()).called(1);

        verify(
          () => mockRequestAbsenceService.uploadAttachment(
            file: any<PlatformFile>(named: 'file'),
            model: 'hr.leave',
          ),
        ).called(1);

        verify(
          () => mockRequestAbsenceService.createRequestAbsence(
            any(
              that: containsPair('supported_attachment_ids', [
                [
                  6,
                  0,
                  [10],
                ],
              ]),
            ),
          ),
        ).called(1);
      },
    );

    blocTest<RequestAbsenceBloc, RequestAbsenceState>(
      'uploads attachment and submits leave request when attachedFile is null',
      build: () {
        when(
          () => mockRequestAbsenceService.createRequestAbsence(any()),
        ).thenAnswer((_) async => {'success': true});

        return RequestAbsenceBloc(service: mockRequestAbsenceService);
      },

      seed: () => RequestAbsenceState().copyWith(
        selectedHolidayStatusId: 1,
        attachedFile: null,
        dateFrom: '2025-01-29',
        dateTo: '2025-01-29',
        durationDays: '2',
      ),

      act: (bloc) => bloc.add(SubmitLeaveRequest()),

      expect: () => [
        isA<RequestAbsenceState>()
            .having((s) => s.isSaving, 'isSaving', true)
            .having((s) => s.errorMessage, 'errorMessage', null),

        isA<RequestAbsenceState>()
            .having((s) => s.isSaving, 'isSaving', false)
            .having((s) => s.success, 'success', true),
      ],

      verify: (_) {
        verify(
          () => mockRequestAbsenceService.createRequestAbsence(any()),
        ).called(1);
      },
    );
  });
}
