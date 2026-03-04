import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mobo_attendance/MainScreens/Dashboard/PendingLeaves/bloc/pending_leave_bloc.dart';
import 'package:mobo_attendance/MainScreens/Dashboard/PendingLeaves/services/pending_leave_service.dart';
import 'package:mocktail/mocktail.dart';

class MockPendingLeaveService extends Mock implements PendingLeaveService {}

void main() {
  late MockPendingLeaveService mockPendingLeaveService;

  setUp(() {
    mockPendingLeaveService = MockPendingLeaveService();
  });

  group('PendingLeaveBloc - Approve Leave', () {
    blocTest(
      'sets leaveLoading to true, then false, and refreshes pending leaves when approveLeave succeeds',
      build: () {
        when(
          () => mockPendingLeaveService.approveLeave(any()),
        ).thenAnswer((_) async => null);
        when(
          () => mockPendingLeaveService.pendingLeaveCount(
            searchQuery: any(named: 'searchQuery'),
            firstApproval: any(named: 'firstApproval'),
            secondApproval: any(named: 'secondApproval'),
          ),
        ).thenAnswer((_) async => 1);
        when(
          () => mockPendingLeaveService.loadPendingLeaves(
            any(),
            any(),
            searchQuery: any(named: 'searchQuery'),
            firstApproval: any(named: 'firstApproval'),
            secondApproval: any(named: 'secondApproval'),
          ),
        ).thenAnswer(
          (_) async => [
            {
              'id': 1,
              'name': 'John',
              'employee_id': [1, 'john'],
              'request_date_from': '1990-01-01',
              'request_date_to': '1990-01-01',
              'state': 'draft',
              'holiday_status_id': [1, 'Sick'],
              'number_of_days_display': 2,
              'display_name': 'Sick',
            },
          ],
        );
        return PendingLeaveBloc(service: mockPendingLeaveService);
      },
      act: (bloc) => bloc.add(ApproveLeave(1)),
      expect: () => [
        isA<PendingLeaveState>().having(
          (s) => s.leaveLoading[1],
          'loading true',
          true,
        ),

        isA<PendingLeaveState>().having(
          (s) => s.leaveLoading[1],
          'loading false',
          false,
        ),

        isA<ShowRatingDialog>(),
        isA<PendingLeaveState>(),

        isA<PendingLeaveState>().having(
          (s) => s.leaves.length,
          'leaves loaded',
          1,
        ),
      ],
      verify: (_) {
        verify(() => mockPendingLeaveService.approveLeave(any())).called(1);
        verify(
          () => mockPendingLeaveService.loadPendingLeaves(
            any(),
            any(),
            searchQuery: any(named: 'searchQuery'),
            firstApproval: any(named: 'firstApproval'),
            secondApproval: any(named: 'secondApproval'),
          ),
        ).called(1);
      },
    );

    blocTest(
      'sets leaveLoading to true, then false, and does not refresh leaves when approveLeave fails',
      build: () {
        when(() => mockPendingLeaveService.approveLeave(any())).thenAnswer(
          (_) async => 'Unexpected error occurred while approving leave',
        );
        return PendingLeaveBloc(service: mockPendingLeaveService);
      },
      act: (bloc) => bloc.add(ApproveLeave(1)),
      expect: () => [
        isA<PendingLeaveState>().having(
          (s) => s.leaveLoading[1],
          'loading true',
          true,
        ),

        isA<PendingLeaveState>().having(
          (s) => s.leaveLoading[1],
          'loading false',
          false,
        ),

        isA<ShowRatingDialog>(),

      ],
      verify: (_) {
        verify(() => mockPendingLeaveService.approveLeave(any())).called(1);
      },
    );
  });

  group('PendingLeaveBloc - Validate Leave', () {
    blocTest(
      'sets leaveLoading true, then false, and refreshes pending leaves when validateLeave succeeds',
      build: () {
        when(
          () => mockPendingLeaveService.validateLeave(any()),
        ).thenAnswer((_) async => null);
        when(
          () => mockPendingLeaveService.pendingLeaveCount(
            searchQuery: any(named: 'searchQuery'),
            firstApproval: any(named: 'firstApproval'),
            secondApproval: any(named: 'secondApproval'),
          ),
        ).thenAnswer((_) async => 1);
        when(
          () => mockPendingLeaveService.loadPendingLeaves(
            any(),
            any(),
            searchQuery: any(named: 'searchQuery'),
            firstApproval: any(named: 'firstApproval'),
            secondApproval: any(named: 'secondApproval'),
          ),
        ).thenAnswer(
          (_) async => [
            {
              'id': 1,
              'name': 'John',
              'employee_id': [1, 'john'],
              'request_date_from': '1990-01-01',
              'request_date_to': '1990-01-01',
              'state': 'draft',
              'holiday_status_id': [1, 'Sick'],
              'number_of_days_display': 2,
              'display_name': 'Sick',
            },
          ],
        );
        return PendingLeaveBloc(service: mockPendingLeaveService);
      },
      act: (bloc) => bloc.add(ValidateLeave(1)),
      expect: () => [
        isA<PendingLeaveState>().having(
          (s) => s.leaveLoading[1],
          'loading true',
          true,
        ),

        isA<PendingLeaveState>().having(
          (s) => s.leaveLoading[1],
          'loading false',
          false,
        ),
        isA<ShowRatingDialog>(),
        isA<PendingLeaveState>(),

        isA<PendingLeaveState>().having(
          (s) => s.leaves.length,
          'leaves loaded',
          1,
        ),
      ],
      verify: (_) {
        verify(() => mockPendingLeaveService.validateLeave(any())).called(1);
        verify(
          () => mockPendingLeaveService.loadPendingLeaves(
            any(),
            any(),
            searchQuery: any(named: 'searchQuery'),
            firstApproval: any(named: 'firstApproval'),
            secondApproval: any(named: 'secondApproval'),
          ),
        ).called(1);
      },
    );

    blocTest(
      'sets leaveLoading true, then false, and does not refresh leaves when validateLeave fails',
      build: () {
        when(() => mockPendingLeaveService.validateLeave(any())).thenAnswer(
          (_) async => 'Unexpected error occurred while validating leave',
        );
        return PendingLeaveBloc(service: mockPendingLeaveService);
      },
      act: (bloc) => bloc.add(ValidateLeave(1)),
      expect: () => [
        isA<PendingLeaveState>().having(
          (s) => s.leaveLoading[1],
          'loading true',
          true,
        ),

        isA<PendingLeaveState>().having(
          (s) => s.leaveLoading[1],
          'loading false',
          false,
        ),

        isA<ShowRatingDialog>(),

      ],
      verify: (_) {
        verify(() => mockPendingLeaveService.validateLeave(any())).called(1);
      },
    );
  });

  group('PendingLeaveBloc - Reject Leave', () {
    blocTest(
      'sets leaveLoading true, then false, and refreshes pending leaves when rejectLeave succeeds',
      build: () {
        when(
          () => mockPendingLeaveService.rejectLeave(any()),
        ).thenAnswer((_) async => null);
        when(
          () => mockPendingLeaveService.pendingLeaveCount(
            searchQuery: any(named: 'searchQuery'),
            firstApproval: any(named: 'firstApproval'),
            secondApproval: any(named: 'secondApproval'),
          ),
        ).thenAnswer((_) async => 1);
        when(
          () => mockPendingLeaveService.loadPendingLeaves(
            any(),
            any(),
            searchQuery: any(named: 'searchQuery'),
            firstApproval: any(named: 'firstApproval'),
            secondApproval: any(named: 'secondApproval'),
          ),
        ).thenAnswer(
          (_) async => [
            {
              'id': 1,
              'name': 'John',
              'employee_id': [1, 'john'],
              'request_date_from': '1990-01-01',
              'request_date_to': '1990-01-01',
              'state': 'draft',
              'holiday_status_id': [1, 'Sick'],
              'number_of_days_display': 2,
              'display_name': 'Sick',
            },
          ],
        );
        return PendingLeaveBloc(service: mockPendingLeaveService);
      },
      act: (bloc) => bloc.add(RejectLeave(1)),
      expect: () => [
        isA<PendingLeaveState>().having(
          (s) => s.leaveLoading[1],
          'loading true',
          true,
        ),

        isA<PendingLeaveState>().having(
          (s) => s.leaveLoading[1],
          'loading false',
          false,
        ),

        isA<ShowRatingDialog>(),
        isA<PendingLeaveState>(),

        isA<PendingLeaveState>().having(
          (s) => s.leaves.length,
          'leaves loaded',
          1,
        ),
      ],
      verify: (_) {
        verify(() => mockPendingLeaveService.rejectLeave(any())).called(1);
        verify(
          () => mockPendingLeaveService.loadPendingLeaves(
            any(),
            any(),
            searchQuery: any(named: 'searchQuery'),
            firstApproval: any(named: 'firstApproval'),
            secondApproval: any(named: 'secondApproval'),
          ),
        ).called(1);
      },
    );

    blocTest(
      'sets leaveLoading true, then false, and does not refresh leaves when rejectLeave fails',
      build: () {
        when(() => mockPendingLeaveService.rejectLeave(any())).thenAnswer(
          (_) async => 'Unexpected error occurred while rejecting leave',
        );
        return PendingLeaveBloc(service: mockPendingLeaveService);
      },
      act: (bloc) => bloc.add(RejectLeave(1)),
      expect: () => [
        isA<PendingLeaveState>().having(
          (s) => s.leaveLoading[1],
          'loading true',
          true,
        ),

        isA<PendingLeaveState>().having(
          (s) => s.leaveLoading[1],
          'loading false',
          false,
        ),

        isA<ShowRatingDialog>(),

      ],
      verify: (_) {
        verify(() => mockPendingLeaveService.rejectLeave(any())).called(1);
      },
    );
  });
}
