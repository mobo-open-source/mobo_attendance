import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mobo_attendance/MainScreens/Employees/EmployeeForm/SmartTabs/WorkInfo/bloc/work_info_bloc.dart';
import 'package:mobo_attendance/MainScreens/Employees/EmployeeForm/SmartTabs/WorkInfo/services/work_info_service.dart';
import 'package:mocktail/mocktail.dart';

class MockWorkInfoService extends Mock implements WorkInfoService {}

void main() {
  late MockWorkInfoService mockWorkInfoService;
  setUp(() {
    mockWorkInfoService = MockWorkInfoService();
  });

  group('WorkInfoBloc - Update Work Information', () {
    blocTest<WorkInfoBloc, WorkInfoState>(
      'emits loading state and success message when work info update succeeds',
      build: () {
        when(
          () => mockWorkInfoService.initializeClient(),
        ).thenAnswer((_) async {});
        when(
          () => mockWorkInfoService.canManageSkills(),
        ).thenAnswer((_) async => true);
        when(
          () => mockWorkInfoService.isSystemAdmin(),
        ).thenAnswer((_) async => true);
        when(
          () => mockWorkInfoService.updateEmployeeDetails(any(), any()),
        ).thenAnswer((_) async => {'success': true, 'errorMessage': null});
        when(
          () => mockWorkInfoService.loadEmployeeDetails(any(), any()),
        ).thenAnswer(
          (_) async => {
            'address_id': 1,
            'work_location_id': 1,
            'attendance_manager_id': 1,
            'resource_calendar_id': 1,
            'tz': 'UTC',
            'name': 'John',
            'job_title': 1,
            'parent_id': 1,
            'image_1920': 'https://image.com',
          },
        );
        when(() => mockWorkInfoService.loadFullAddress(any())).thenAnswer(
          (_) async => {
            'name': 'John',
            'street': 'London',
            'street2': 'London 2',
            'city': 'London city',
            'zip': 123456,
            'state_id': 1,
            'country_id': 1,
          },
        );
        return WorkInfoBloc(service: mockWorkInfoService);
      },
      seed: () => WorkInfoState(
        employeeDetails: {
          'id': 1,
          'address_id': 1,
          'work_location_id': 1,
          'attendance_manager_id': 1,
          'resource_calendar_id': 1,
          'tz': 'UTC',
          'name': 'John',
          'job_title': 1,
          'parent_id': 1,
          'image_1920': 'https://image.com',
        },
        selectedAddressId: 10,
        selectedLocationId: 5,
        selectedExpenseId: 3,
        selectedWorkingHoursId: 2,
        selectedTzId: 'UTC',
      ),
      act: (bloc) => bloc.add(SaveWorkInfo()),
      expect: () => [
        isA<WorkInfoState>().having((s) => s.isSaving, 'isSaving', true),
        isA<WorkInfoState>()
            .having((s) => s.isSaving, 'isSaving', false)
            .having(
              (s) => s.successMessage,
              'successMessage',
              'Work info updated successfully!',
            ),
      ],
      verify: (_) {
        verify(
          () => mockWorkInfoService.updateEmployeeDetails(1, any()),
        ).called(1);
        verify(
          () => mockWorkInfoService.loadEmployeeDetails(1, true),
        ).called(1);
      },
    );

    blocTest<WorkInfoBloc, WorkInfoState>(
      'emits loading state and warning message when work info update get any warning',
      build: () {
        when(
          () => mockWorkInfoService.initializeClient(),
        ).thenAnswer((_) async {});
        when(
          () => mockWorkInfoService.canManageSkills(),
        ).thenAnswer((_) async => true);
        when(
          () => mockWorkInfoService.isSystemAdmin(),
        ).thenAnswer((_) async => true);
        when(
          () => mockWorkInfoService.updateEmployeeDetails(any(), any()),
        ).thenAnswer(
          (_) async => {
            'success': false,
            'warning': true,
            'warningMessage': 'You have no access',
          },
        );
        return WorkInfoBloc(service: mockWorkInfoService);
      },
      seed: () => WorkInfoState(
        employeeDetails: {
          'id': 1,
          'address_id': 1,
          'work_location_id': 1,
          'attendance_manager_id': 1,
          'resource_calendar_id': 1,
          'tz': 'UTC',
          'name': 'John',
          'job_title': 1,
          'parent_id': 1,
          'image_1920': 'https://image.com',
        },
        selectedAddressId: 10,
        selectedLocationId: 5,
        selectedExpenseId: 3,
        selectedWorkingHoursId: 2,
        selectedTzId: 'UTC',
      ),
      act: (bloc) => bloc.add(SaveWorkInfo()),
      expect: () => [
        isA<WorkInfoState>().having((s) => s.isSaving, 'isSaving', true),
        isA<WorkInfoState>()
            .having((s) => s.isSaving, 'isSaving', false)
            .having(
              (s) => s.warningMessage,
              'warningMessage',
              'You have no access',
            ),
      ],
      verify: (_) {
        verify(
          () => mockWorkInfoService.updateEmployeeDetails(1, any()),
        ).called(1);
      },
    );

    blocTest<WorkInfoBloc, WorkInfoState>(
      'emits loading state and error message when work info update fails',
      build: () {
        when(
          () => mockWorkInfoService.initializeClient(),
        ).thenAnswer((_) async {});
        when(
          () => mockWorkInfoService.canManageSkills(),
        ).thenAnswer((_) async => true);
        when(
          () => mockWorkInfoService.isSystemAdmin(),
        ).thenAnswer((_) async => true);
        when(
          () => mockWorkInfoService.updateEmployeeDetails(any(), any()),
        ).thenAnswer(
          (_) async => {
            'success': false,
            'warning': false,
            'errorMessage':
                'Failed to update work info, Please try again later',
          },
        );
        return WorkInfoBloc(service: mockWorkInfoService);
      },
      seed: () => WorkInfoState(
        employeeDetails: {
          'id': 1,
          'address_id': 1,
          'work_location_id': 1,
          'attendance_manager_id': 1,
          'resource_calendar_id': 1,
          'tz': 'UTC',
          'name': 'John',
          'job_title': 1,
          'parent_id': 1,
          'image_1920': 'https://image.com',
        },
        selectedAddressId: 10,
        selectedLocationId: 5,
        selectedExpenseId: 3,
        selectedWorkingHoursId: 2,
        selectedTzId: 'UTC',
      ),
      act: (bloc) => bloc.add(SaveWorkInfo()),
      expect: () => [
        isA<WorkInfoState>().having((s) => s.isSaving, 'isSaving', true),
        isA<WorkInfoState>()
            .having((s) => s.isSaving, 'isSaving', false)
            .having(
              (s) => s.errorMessage,
              'errorMessage',
              'Failed to update work info, Please try again later',
            ),
      ],
      verify: (_) {
        verify(
          () => mockWorkInfoService.updateEmployeeDetails(1, any()),
        ).called(1);
      },
    );
  });
}
