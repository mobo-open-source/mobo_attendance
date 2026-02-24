import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mobo_attendance/MainScreens/Employees/EmployeeForm/Form/bloc/employee_form_bloc.dart';
import 'package:mobo_attendance/MainScreens/Employees/EmployeeForm/Form/services/employee_form_service.dart';
import 'package:mocktail/mocktail.dart';

class MockEmployeeFormService extends Mock implements EmployeeFormService {}

void main() {
  late MockEmployeeFormService mockEmployeeFormService;

  setUp(() {
    mockEmployeeFormService = MockEmployeeFormService();
  });

  group('EmployeeFormBloc - Update Employee Details', () {
    blocTest(
      'emits saving and success states on successful employee update',
      build: () {
        when(
          () => mockEmployeeFormService.initializeClient(),
        ).thenAnswer((_) async => {});
        when(
          () => mockEmployeeFormService.updateHrEmployee(any(), any()),
        ).thenAnswer((_) async => {'success': true, 'error': null});
        when(
          () => mockEmployeeFormService.loadEmployeeDetails(any()),
        ).thenAnswer(
          (_) async => {
            'id': 1,
            'name': 'John',
            'work_email': 'jon@abc.in',
            'work_phone': 1234567890,
            'mobile_phone': 0987654321,
            'parent_id': 1,
            'department_id': 1,
            'coach_id': 1,
            'user_id': 1,
            'job_id': 1,
            'create_date': 1990 - 01 - 01,
            'resume_line_ids': [1, 2],
            'employee_skill_ids': [1, 2],
          },
        );

        return EmployeeFormBloc(service: mockEmployeeFormService);
      },
      seed: () => EmployeeFormState(
        dropdownFocusNode: FocusNode(),

        employeeDetails: const {'id': 1},

        nameController: TextEditingController(text: 'John'),
        emailController: TextEditingController(text: 'jon@abc.in'),
        workPhoneController: TextEditingController(text: '1234567890'),
        mobilePhoneController: TextEditingController(text: '0987654321'),
        pinController: TextEditingController(text: 'N/A'),
        badgeController: TextEditingController(text: 'EMP001'),

        jobId: 1,
        departmentId: 1,
        managerId: 1,
        coachId: 1,
        employeeType: 'employee',
        relatedUserId: 1,
        profileImageBase64: 'base64-image',
      ),
      act: (bloc) => bloc.add(SaveEmployee()),
      expect: () => [
        isA<EmployeeFormState>().having((s) => s.isSaving, 'isSaving', true),
        isA<EmployeeFormState>()
            .having((s) => s.isSaving, 'isSaving', false)
            .having(
              (s) => s.successMessage,
              'successMessage',
              'Employee details updated successfully',
            ),
      ],
      verify: (_) {
        verify(() => mockEmployeeFormService.initializeClient()).called(1);
        verify(
          () => mockEmployeeFormService.updateHrEmployee(any(), any()),
        ).called(1);
        verify(
          () => mockEmployeeFormService.loadEmployeeDetails(any()),
        ).called(1);
      },
    );

    blocTest(
      'emits saving and warning states on employee update failure',
      build: () {
        when(
          () => mockEmployeeFormService.initializeClient(),
        ).thenAnswer((_) async => {});
        when(
          () => mockEmployeeFormService.updateHrEmployee(any(), any()),
        ).thenAnswer((_) async => {'success': false, 'error': 'Update failed'});

        return EmployeeFormBloc(service: mockEmployeeFormService);
      },
      seed: () => EmployeeFormState(
        dropdownFocusNode: FocusNode(),

        employeeDetails: const {'id': 1},

        nameController: TextEditingController(text: 'John'),
        emailController: TextEditingController(text: 'jon@abc.in'),
        workPhoneController: TextEditingController(text: '1234567890'),
        mobilePhoneController: TextEditingController(text: '0987654321'),
        pinController: TextEditingController(text: 'N/A'),
        badgeController: TextEditingController(text: 'EMP001'),

        jobId: 1,
        departmentId: 1,
        managerId: 1,
        coachId: 1,
        employeeType: 'employee',
        relatedUserId: 1,
        profileImageBase64: 'base64-image',
      ),
      act: (bloc) => bloc.add(SaveEmployee()),
      expect: () => [
        isA<EmployeeFormState>().having((s) => s.isSaving, 'isSaving', true),
        isA<EmployeeFormState>()
            .having((s) => s.isSaving, 'isSaving', false)
            .having((s) => s.warningMessage, 'warningMessage', 'Update failed'),
      ],
      verify: (_) {
        verify(() => mockEmployeeFormService.initializeClient()).called(1);
        verify(
          () => mockEmployeeFormService.updateHrEmployee(any(), any()),
        ).called(1);
      },
    );

    blocTest(
      'emits saving and error states when update throws exception',
      build: () {
        when(
          () => mockEmployeeFormService.initializeClient(),
        ).thenAnswer((_) async => {});
        when(
          () => mockEmployeeFormService.updateHrEmployee(any(), any()),
        ).thenThrow(Exception("Failed to update, Please try again later."));

        return EmployeeFormBloc(service: mockEmployeeFormService);
      },
      seed: () => EmployeeFormState(
        dropdownFocusNode: FocusNode(),

        employeeDetails: const {'id': 1},

        nameController: TextEditingController(text: 'John'),
        emailController: TextEditingController(text: 'jon@abc.in'),
        workPhoneController: TextEditingController(text: '1234567890'),
        mobilePhoneController: TextEditingController(text: '0987654321'),
        pinController: TextEditingController(text: 'N/A'),
        badgeController: TextEditingController(text: 'EMP001'),

        jobId: 1,
        departmentId: 1,
        managerId: 1,
        coachId: 1,
        employeeType: 'employee',
        relatedUserId: 1,
        profileImageBase64: 'base64-image',
      ),
      act: (bloc) => bloc.add(SaveEmployee()),
      expect: () => [
        isA<EmployeeFormState>().having((s) => s.isSaving, 'isSaving', true),
        isA<EmployeeFormState>()
            .having((s) => s.isSaving, 'isSaving', false)
            .having(
              (s) => s.errorMessage,
              'errorMessage',
              'Failed to update, Please try again later.',
            ),
      ],
      verify: (_) {
        verify(() => mockEmployeeFormService.initializeClient()).called(1);
        verify(
          () => mockEmployeeFormService.updateHrEmployee(any(), any()),
        ).called(1);
      },
    );
  });

  group('EmployeeFormBloc - Generate Badge', () {
    blocTest(
      'generates badge successfully',
      build: () {
        when(
          () => mockEmployeeFormService.initializeClient(),
        ).thenAnswer((_) async {});
        when(
          () => mockEmployeeFormService.generateBadge(any()),
        ).thenAnswer((_) async => null);
        when(
          () => mockEmployeeFormService.loadEmployeeDetails(any()),
        ).thenAnswer(
          (_) async => {
            'id': 1,
            'name': 'John',
            'work_email': 'jon@abc.in',
            'work_phone': 1234567890,
            'mobile_phone': 0987654321,
            'parent_id': 1,
            'department_id': 1,
            'coach_id': 1,
            'user_id': 1,
            'job_id': 1,
            'create_date': 1990 - 01 - 01,
            'resume_line_ids': [1, 2],
            'employee_skill_ids': [1, 2],
          },
        );
        return EmployeeFormBloc(service: mockEmployeeFormService);
      },
      seed: () => EmployeeFormState(
        employeeDetails: const {'id': 1},
        badgeController: TextEditingController(),
        dropdownFocusNode: FocusNode(),
      ),
      act: (bloc) => bloc.add(GenerateBadge()),
      expect: () => [
        isA<EmployeeFormState>().having((s) => s.isSaving, 'isSaving', true),
        isA<EmployeeFormState>()
            .having((s) => s.isSaving, 'isSaving', false)
            .having(
              (s) => s.successMessage,
              'successMessage',
              'Badge generated successfully',
            ),
      ],
      verify: (_) {
        verify(() => mockEmployeeFormService.initializeClient()).called(1);
        verify(() => mockEmployeeFormService.generateBadge(any())).called(1);
        verify(
          () => mockEmployeeFormService.loadEmployeeDetails(any()),
        ).called(1);
      },
    );

    blocTest(
      'fails to generate badge with error message',
      build: () {
        when(
          () => mockEmployeeFormService.initializeClient(),
        ).thenAnswer((_) async {});
        when(() => mockEmployeeFormService.generateBadge(any())).thenAnswer(
          (_) async =>
              "Unexpected error occurred while generating badge, Please try again later.",
        );
        return EmployeeFormBloc(service: mockEmployeeFormService);
      },
      seed: () => EmployeeFormState(
        employeeDetails: const {'id': 1},
        badgeController: TextEditingController(),
        dropdownFocusNode: FocusNode(),
      ),
      act: (bloc) => bloc.add(GenerateBadge()),
      expect: () => [
        isA<EmployeeFormState>().having((s) => s.isSaving, 'isSaving', true),
        isA<EmployeeFormState>().having(
          (s) => s.errorMessage,
          'errorMessage',
          'Unexpected error occurred while generating badge, Please try again later.',
        ),
      ],
      verify: (_) {
        verify(() => mockEmployeeFormService.initializeClient()).called(1);
        verify(() => mockEmployeeFormService.generateBadge(any())).called(1);
      },
    );

    blocTest(
      'fails to generate badge due to exception',
      build: () {
        when(
          () => mockEmployeeFormService.initializeClient(),
        ).thenAnswer((_) async {});
        when(
          () => mockEmployeeFormService.generateBadge(any()),
        ).thenThrow(Exception('Failed to generate badge'));
        return EmployeeFormBloc(service: mockEmployeeFormService);
      },
      seed: () => EmployeeFormState(
        employeeDetails: const {'id': 1},
        badgeController: TextEditingController(),
        dropdownFocusNode: FocusNode(),
      ),
      act: (bloc) => bloc.add(GenerateBadge()),
      expect: () => [
        isA<EmployeeFormState>().having((s) => s.isSaving, 'isSaving', true),
        isA<EmployeeFormState>().having(
          (s) => s.errorMessage,
          'errorMessage',
          'Failed to generate badge',
        ),
      ],
      verify: (_) {
        verify(() => mockEmployeeFormService.initializeClient()).called(1);
        verify(() => mockEmployeeFormService.generateBadge(any())).called(1);
      },
    );
  });

  group('EmployeeFormBloc - Add Resume Line', () {
    blocTest(
      'emits success message when resume line is added successfully',
      build: () {
        when(
          () => mockEmployeeFormService.initializeClient(),
        ).thenAnswer((_) async {});
        when(
          () => mockEmployeeFormService.addResumeLine(any()),
        ).thenAnswer((_) async => null);
        when(
          () => mockEmployeeFormService.loadEmployeeDetails(any()),
        ).thenAnswer(
          (_) async => {
            'id': 1,
            'name': 'John',
            'work_email': 'jon@abc.in',
            'work_phone': 1234567890,
            'mobile_phone': 0987654321,
            'parent_id': 1,
            'department_id': 1,
            'coach_id': 1,
            'user_id': 1,
            'job_id': 1,
            'create_date': 1990 - 01 - 01,
            'resume_line_ids': [1, 2],
            'employee_skill_ids': [1, 2],
          },
        );
        return EmployeeFormBloc(service: mockEmployeeFormService);
      },
      seed: () => EmployeeFormState(
        employeeDetails: const {'id': 1},
        dropdownFocusNode: FocusNode(),
      ),
      act: (bloc) => bloc.add(
        AddResumeLine({
          "name": "Flutter",
          "line_type_id": 1,
          "line_type_name": 'Experience',
          "date_start": 1990 - 01 - 01,
          "date_end": 1990 - 01 - 01,
          "description": 'Flutter developer',
          "display_date": 1990 - 01 - 01,
        }),
      ),
      expect: () => [
        isA<EmployeeFormState>(),

        isA<EmployeeFormState>().having(
          (s) => s.successMessage,
          'successMessage',
          'Resume line added successfully',
        ),
      ],
      verify: (_) {
        verify(() => mockEmployeeFormService.initializeClient()).called(1);
        verify(() => mockEmployeeFormService.addResumeLine(any())).called(1);
        verify(
          () => mockEmployeeFormService.loadEmployeeDetails(any()),
        ).called(1);
      },
    );

    blocTest(
      'emits error message when resume line addition fails',
      build: () {
        when(
          () => mockEmployeeFormService.initializeClient(),
        ).thenAnswer((_) async {});
        when(
          () => mockEmployeeFormService.addResumeLine(any()),
        ).thenAnswer((_) async => 'Failed to add resume line.');
        return EmployeeFormBloc(service: mockEmployeeFormService);
      },
      seed: () => EmployeeFormState(
        employeeDetails: const {'id': 1},
        dropdownFocusNode: FocusNode(),
      ),
      act: (bloc) => bloc.add(
        AddResumeLine({
          "name": "Flutter",
          "line_type_id": 1,
          "line_type_name": 'Experience',
          "date_start": 1990 - 01 - 01,
          "date_end": 1990 - 01 - 01,
          "description": 'Flutter developer',
          "display_date": 1990 - 01 - 01,
        }),
      ),
      expect: () => [
        isA<EmployeeFormState>(),

        isA<EmployeeFormState>().having(
          (s) => s.errorMessage,
          'errorMessage',
          'Failed to add resume line.',
        ),
      ],
      verify: (_) {
        verify(() => mockEmployeeFormService.initializeClient()).called(1);
        verify(() => mockEmployeeFormService.addResumeLine(any())).called(1);
      },
    );

    blocTest(
      'emits error message when adding resume line throws exception',
      build: () {
        when(
          () => mockEmployeeFormService.initializeClient(),
        ).thenAnswer((_) async {});
        when(() => mockEmployeeFormService.addResumeLine(any())).thenThrow(
          Exception('Failed to add resume line, Please try again later.'),
        );
        return EmployeeFormBloc(service: mockEmployeeFormService);
      },
      seed: () => EmployeeFormState(
        employeeDetails: const {'id': 1},
        dropdownFocusNode: FocusNode(),
      ),
      act: (bloc) => bloc.add(
        AddResumeLine({
          "name": "Flutter",
          "line_type_id": 1,
          "line_type_name": 'Experience',
          "date_start": 1990 - 01 - 01,
          "date_end": 1990 - 01 - 01,
          "description": 'Flutter developer',
          "display_date": 1990 - 01 - 01,
        }),
      ),
      expect: () => [
        isA<EmployeeFormState>(),

        isA<EmployeeFormState>().having(
          (s) => s.errorMessage,
          'errorMessage',
          'Failed to add resume line, Please try again later.',
        ),
      ],
      verify: (_) {
        verify(() => mockEmployeeFormService.initializeClient()).called(1);
        verify(() => mockEmployeeFormService.addResumeLine(any())).called(1);
      },
    );
  });

  group('EmployeeFormBloc - Update Resume Line', () {
    blocTest(
      'emits success message when resume line is updated successfully',
      build: () {
        when(
          () => mockEmployeeFormService.initializeClient(),
        ).thenAnswer((_) async {});
        when(
          () => mockEmployeeFormService.updateResumeLine(any(), any()),
        ).thenAnswer((_) async => null);
        when(
          () => mockEmployeeFormService.loadEmployeeDetails(any()),
        ).thenAnswer(
          (_) async => {
            'id': 1,
            'name': 'John',
            'work_email': 'jon@abc.in',
            'work_phone': 1234567890,
            'mobile_phone': 0987654321,
            'parent_id': 1,
            'department_id': 1,
            'coach_id': 1,
            'user_id': 1,
            'job_id': 1,
            'create_date': 1990 - 01 - 01,
            'resume_line_ids': [1, 2],
            'employee_skill_ids': [1, 2],
          },
        );
        return EmployeeFormBloc(service: mockEmployeeFormService);
      },
      seed: () => EmployeeFormState(
        employeeDetails: const {'id': 1},
        dropdownFocusNode: FocusNode(),
      ),
      act: (bloc) => bloc.add(
        UpdateResumeLine(1, {
          "name": "Flutter",
          "line_type_id": 1,
          "line_type_name": 'Experience',
          "date_start": 1990 - 01 - 01,
          "date_end": 1990 - 01 - 01,
          "description": 'Flutter developer',
          "display_date": 1990 - 01 - 01,
        }),
      ),
      expect: () => [
        isA<EmployeeFormState>(),
        isA<EmployeeFormState>().having(
          (s) => s.employeeDetails,
          'employeeDetails',
          isNotNull,
        ),

        isA<EmployeeFormState>().having(
          (s) => s.successMessage,
          'successMessage',
          'Resume line updated successfully',
        ),
      ],
      verify: (_) {
        verify(() => mockEmployeeFormService.initializeClient()).called(1);
        verify(
          () => mockEmployeeFormService.updateResumeLine(any(), any()),
        ).called(1);
        verify(
          () => mockEmployeeFormService.loadEmployeeDetails(any()),
        ).called(1);
      },
    );

    blocTest(
      'emits error message when resume line update fails',
      build: () {
        when(
          () => mockEmployeeFormService.initializeClient(),
        ).thenAnswer((_) async {});
        when(
          () => mockEmployeeFormService.updateResumeLine(any(), any()),
        ).thenAnswer((_) async => 'Failed to update resume line');
        return EmployeeFormBloc(service: mockEmployeeFormService);
      },
      seed: () => EmployeeFormState(
        employeeDetails: const {'id': 1},
        dropdownFocusNode: FocusNode(),
      ),
      act: (bloc) => bloc.add(
        UpdateResumeLine(1, {
          "name": "Flutter",
          "line_type_id": 1,
          "line_type_name": 'Experience',
          "date_start": 1990 - 01 - 01,
          "date_end": 1990 - 01 - 01,
          "description": 'Flutter developer',
          "display_date": 1990 - 01 - 01,
        }),
      ),
      expect: () => [
        isA<EmployeeFormState>(),

        isA<EmployeeFormState>().having(
          (s) => s.errorMessage,
          'errorMessage',
          'Failed to update resume line',
        ),
      ],
      verify: (_) {
        verify(() => mockEmployeeFormService.initializeClient()).called(1);
        verify(
          () => mockEmployeeFormService.updateResumeLine(any(), any()),
        ).called(1);
      },
    );

    blocTest(
      'emits error message when updating resume line throws exception',
      build: () {
        when(
          () => mockEmployeeFormService.initializeClient(),
        ).thenAnswer((_) async {});
        when(
          () => mockEmployeeFormService.updateResumeLine(any(), any()),
        ).thenThrow(
          Exception('Failed to update resume line, Please try again later'),
        );
        return EmployeeFormBloc(service: mockEmployeeFormService);
      },
      seed: () => EmployeeFormState(
        employeeDetails: const {'id': 1},
        dropdownFocusNode: FocusNode(),
      ),
      act: (bloc) => bloc.add(
        UpdateResumeLine(1, {
          "name": "Flutter",
          "line_type_id": 1,
          "line_type_name": 'Experience',
          "date_start": 1990 - 01 - 01,
          "date_end": 1990 - 01 - 01,
          "description": 'Flutter developer',
          "display_date": 1990 - 01 - 01,
        }),
      ),
      expect: () => [
        isA<EmployeeFormState>(),

        isA<EmployeeFormState>().having(
          (s) => s.errorMessage,
          'errorMessage',
          'Failed to update resume line, Please try again later',
        ),
      ],
      verify: (_) {
        verify(() => mockEmployeeFormService.initializeClient()).called(1);
        verify(
          () => mockEmployeeFormService.updateResumeLine(any(), any()),
        ).called(1);
      },
    );
  });

  group('EmployeeFormBloc - Delete Resume Line', () {
    blocTest(
      'emits success message when resume line is deleted successfully',
      build: () {
        when(
          () => mockEmployeeFormService.initializeClient(),
        ).thenAnswer((_) async {});
        when(
          () => mockEmployeeFormService.deleteResumeLine(any()),
        ).thenAnswer((_) async => null);
        when(
          () => mockEmployeeFormService.loadEmployeeDetails(any()),
        ).thenAnswer(
          (_) async => {
            'id': 1,
            'name': 'John',
            'work_email': 'jon@abc.in',
            'work_phone': 1234567890,
            'mobile_phone': 0987654321,
            'parent_id': 1,
            'department_id': 1,
            'coach_id': 1,
            'user_id': 1,
            'job_id': 1,
            'create_date': 1990 - 01 - 01,
            'resume_line_ids': [1, 2],
            'employee_skill_ids': [1, 2],
          },
        );
        return EmployeeFormBloc(service: mockEmployeeFormService);
      },
      seed: () => EmployeeFormState(
        employeeDetails: const {'id': 1},
        dropdownFocusNode: FocusNode(),
      ),
      act: (bloc) => bloc.add(DeleteResumeLine(1)),
      expect: () => [
        isA<EmployeeFormState>(),
        isA<EmployeeFormState>().having(
          (s) => s.employeeDetails,
          'employeeDetails',
          isNotNull,
        ),
        isA<EmployeeFormState>().having(
          (s) => s.successMessage,
          'successMessage',
          'Resume line deleted successfully',
        ),
      ],
      verify: (_) {
        verify(() => mockEmployeeFormService.initializeClient()).called(1);
        verify(() => mockEmployeeFormService.deleteResumeLine(any())).called(1);
        verify(
          () => mockEmployeeFormService.loadEmployeeDetails(any()),
        ).called(1);
      },
    );

    blocTest(
      'emits error message when resume line deletion fails',
      build: () {
        when(
          () => mockEmployeeFormService.initializeClient(),
        ).thenAnswer((_) async {});
        when(
          () => mockEmployeeFormService.deleteResumeLine(any()),
        ).thenAnswer((_) async => 'Failed to delete resume line');
        return EmployeeFormBloc(service: mockEmployeeFormService);
      },
      seed: () => EmployeeFormState(
        employeeDetails: const {'id': 1},
        dropdownFocusNode: FocusNode(),
      ),
      act: (bloc) => bloc.add(DeleteResumeLine(1)),
      expect: () => [
        isA<EmployeeFormState>(),
        isA<EmployeeFormState>().having(
          (s) => s.errorMessage,
          'errorMessage',
          'Failed to delete resume line',
        ),
      ],
      verify: (_) {
        verify(() => mockEmployeeFormService.initializeClient()).called(1);
        verify(() => mockEmployeeFormService.deleteResumeLine(any())).called(1);
      },
    );

    blocTest(
      'emits error message when deleting resume line throws exception',
      build: () {
        when(
          () => mockEmployeeFormService.initializeClient(),
        ).thenAnswer((_) async {});
        when(() => mockEmployeeFormService.deleteResumeLine(any())).thenThrow(
          Exception('Failed to delete resume line, Please try again later.'),
        );
        return EmployeeFormBloc(service: mockEmployeeFormService);
      },
      seed: () => EmployeeFormState(
        employeeDetails: const {'id': 1},
        dropdownFocusNode: FocusNode(),
      ),
      act: (bloc) => bloc.add(DeleteResumeLine(1)),
      expect: () => [
        isA<EmployeeFormState>(),
        isA<EmployeeFormState>().having(
          (s) => s.errorMessage,
          'errorMessage',
          'Failed to delete resume line, Please try again later.',
        ),
      ],
      verify: (_) {
        verify(() => mockEmployeeFormService.initializeClient()).called(1);
        verify(() => mockEmployeeFormService.deleteResumeLine(any())).called(1);
      },
    );
  });

  group('EmployeeFormBloc - Add Skill', () {
    blocTest(
      'emits success message when skill is added successfully',
      build: () {
        when(
          () => mockEmployeeFormService.initializeClient(),
        ).thenAnswer((_) async {});
        when(
          () => mockEmployeeFormService.addEmployeeSkill(any()),
        ).thenAnswer((_) async => null);
        when(
          () => mockEmployeeFormService.loadEmployeeDetails(any()),
        ).thenAnswer(
          (_) async => {
            'id': 1,
            'name': 'John',
            'work_email': 'jon@abc.in',
            'work_phone': 1234567890,
            'mobile_phone': 0987654321,
            'parent_id': 1,
            'department_id': 1,
            'coach_id': 1,
            'user_id': 1,
            'job_id': 1,
            'create_date': 1990 - 01 - 01,
            'resume_line_ids': [1, 2],
            'employee_skill_ids': [1, 2],
          },
        );
        return EmployeeFormBloc(service: mockEmployeeFormService);
      },
      seed: () => EmployeeFormState(
        employeeDetails: const {'id': 1},
        dropdownFocusNode: FocusNode(),
      ),
      act: (bloc) => bloc.add(
        AddSkill({
          "employee_id": 1,
          "skill_id": 1,
          "skill_level_id": 1,
          "skill_type_id": 1,
        }),
      ),
      expect: () => [
        isA<EmployeeFormState>(),
        isA<EmployeeFormState>().having(
          (s) => s.employeeDetails,
          'employeeDetails',
          isNotNull,
        ),
        isA<EmployeeFormState>().having(
          (s) => s.successMessage,
          'successMessage',
          'Skill added successfully',
        ),
      ],
      verify: (_) {
        verify(() => mockEmployeeFormService.initializeClient()).called(1);
        verify(() => mockEmployeeFormService.addEmployeeSkill(any())).called(1);
        verify(
          () => mockEmployeeFormService.loadEmployeeDetails(any()),
        ).called(1);
      },
    );

    blocTest(
      'emits error message when adding skill fails',
      build: () {
        when(
          () => mockEmployeeFormService.initializeClient(),
        ).thenAnswer((_) async {});
        when(
          () => mockEmployeeFormService.addEmployeeSkill(any()),
        ).thenAnswer((_) async => 'Failed to add skill');
        return EmployeeFormBloc(service: mockEmployeeFormService);
      },
      seed: () => EmployeeFormState(
        employeeDetails: const {'id': 1},
        dropdownFocusNode: FocusNode(),
      ),
      act: (bloc) => bloc.add(
        AddSkill({
          "employee_id": 1,
          "skill_id": 1,
          "skill_level_id": 1,
          "skill_type_id": 1,
        }),
      ),
      expect: () => [
        isA<EmployeeFormState>(),

        isA<EmployeeFormState>().having(
          (s) => s.errorMessage,
          'errorMessage',
          'Failed to add skill',
        ),
      ],
      verify: (_) {
        verify(() => mockEmployeeFormService.initializeClient()).called(1);
        verify(() => mockEmployeeFormService.addEmployeeSkill(any())).called(1);
      },
    );

    blocTest(
      'emits error message when adding skill throws exception',
      build: () {
        when(
          () => mockEmployeeFormService.initializeClient(),
        ).thenAnswer((_) async {});
        when(
          () => mockEmployeeFormService.addEmployeeSkill(any()),
        ).thenThrow(Exception('Failed to add skill, Please try again later.'));
        return EmployeeFormBloc(service: mockEmployeeFormService);
      },
      seed: () => EmployeeFormState(
        employeeDetails: const {'id': 1},
        dropdownFocusNode: FocusNode(),
      ),
      act: (bloc) => bloc.add(
        AddSkill({
          "employee_id": 1,
          "skill_id": 1,
          "skill_level_id": 1,
          "skill_type_id": 1,
        }),
      ),
      expect: () => [
        isA<EmployeeFormState>(),

        isA<EmployeeFormState>().having(
          (s) => s.errorMessage,
          'errorMessage',
          'Failed to add skill, Please try again later.',
        ),
      ],
      verify: (_) {
        verify(() => mockEmployeeFormService.initializeClient()).called(1);
        verify(() => mockEmployeeFormService.addEmployeeSkill(any())).called(1);
      },
    );
  });

  group('EmployeeFormBloc - Update Skill', () {
    blocTest(
      'emits success message when skill is updated successfully',
      build: () {
        when(
          () => mockEmployeeFormService.initializeClient(),
        ).thenAnswer((_) async {});
        when(
          () => mockEmployeeFormService.updateEmployeeSkill(any(), any()),
        ).thenAnswer((_) async => null);
        when(
          () => mockEmployeeFormService.loadEmployeeDetails(any()),
        ).thenAnswer(
          (_) async => {
            'id': 1,
            'name': 'John',
            'work_email': 'jon@abc.in',
            'work_phone': 1234567890,
            'mobile_phone': 0987654321,
            'parent_id': 1,
            'department_id': 1,
            'coach_id': 1,
            'user_id': 1,
            'job_id': 1,
            'create_date': 1990 - 01 - 01,
            'resume_line_ids': [1, 2],
            'employee_skill_ids': [1, 2],
          },
        );
        return EmployeeFormBloc(service: mockEmployeeFormService);
      },
      seed: () => EmployeeFormState(
        employeeDetails: const {'id': 1},
        dropdownFocusNode: FocusNode(),
      ),
      act: (bloc) => bloc.add(
        UpdateSkill(1, {
          "employee_id": 1,
          "skill_id": 1,
          "skill_level_id": 1,
          "skill_type_id": 1,
        }),
      ),
      expect: () => [
        isA<EmployeeFormState>(),
        isA<EmployeeFormState>().having(
          (s) => s.employeeDetails,
          'employeeDetails',
          isNotNull,
        ),
        isA<EmployeeFormState>().having(
          (s) => s.successMessage,
          'successMessage',
          'Skill updated successfully',
        ),
      ],
      verify: (_) {
        verify(() => mockEmployeeFormService.initializeClient()).called(1);
        verify(
          () => mockEmployeeFormService.updateEmployeeSkill(any(), any()),
        ).called(1);
        verify(
          () => mockEmployeeFormService.loadEmployeeDetails(any()),
        ).called(1);
      },
    );

    blocTest(
      'emits error message when updating skill fails',
      build: () {
        when(
          () => mockEmployeeFormService.initializeClient(),
        ).thenAnswer((_) async {});
        when(
          () => mockEmployeeFormService.updateEmployeeSkill(any(), any()),
        ).thenAnswer((_) async => 'Failed to update skill');

        return EmployeeFormBloc(service: mockEmployeeFormService);
      },
      seed: () => EmployeeFormState(
        employeeDetails: const {'id': 1},
        dropdownFocusNode: FocusNode(),
      ),
      act: (bloc) => bloc.add(
        UpdateSkill(1, {
          "employee_id": 1,
          "skill_id": 1,
          "skill_level_id": 1,
          "skill_type_id": 1,
        }),
      ),
      expect: () => [
        isA<EmployeeFormState>(),
        isA<EmployeeFormState>().having(
          (s) => s.errorMessage,
          'errorMessage',
          'Failed to update skill',
        ),
      ],
      verify: (_) {
        verify(() => mockEmployeeFormService.initializeClient()).called(1);
        verify(
          () => mockEmployeeFormService.updateEmployeeSkill(any(), any()),
        ).called(1);
      },
    );

    blocTest(
      'emits error message when updating skill throws exception',
      build: () {
        when(
          () => mockEmployeeFormService.initializeClient(),
        ).thenAnswer((_) async {});
        when(
          () => mockEmployeeFormService.updateEmployeeSkill(any(), any()),
        ).thenThrow(
          Exception('Failed to update skill, Please try again later.'),
        );

        return EmployeeFormBloc(service: mockEmployeeFormService);
      },
      seed: () => EmployeeFormState(
        employeeDetails: const {'id': 1},
        dropdownFocusNode: FocusNode(),
      ),
      act: (bloc) => bloc.add(
        UpdateSkill(1, {
          "employee_id": 1,
          "skill_id": 1,
          "skill_level_id": 1,
          "skill_type_id": 1,
        }),
      ),
      expect: () => [
        isA<EmployeeFormState>(),
        isA<EmployeeFormState>().having(
          (s) => s.errorMessage,
          'errorMessage',
          'Failed to update skill, Please try again later.',
        ),
      ],
      verify: (_) {
        verify(() => mockEmployeeFormService.initializeClient()).called(1);
        verify(
          () => mockEmployeeFormService.updateEmployeeSkill(any(), any()),
        ).called(1);
      },
    );
  });

  group('EmployeeFormBloc - Delete Skill', () {
    blocTest(
      'emits success message when skill is deleted successfully',
      build: () {
        when(
          () => mockEmployeeFormService.initializeClient(),
        ).thenAnswer((_) async {});
        when(
          () => mockEmployeeFormService.deleteEmployeeSkill(any()),
        ).thenAnswer((_) async => null);
        when(
          () => mockEmployeeFormService.loadEmployeeDetails(any()),
        ).thenAnswer(
          (_) async => {
            'id': 1,
            'name': 'John',
            'work_email': 'jon@abc.in',
            'work_phone': 1234567890,
            'mobile_phone': 0987654321,
            'parent_id': 1,
            'department_id': 1,
            'coach_id': 1,
            'user_id': 1,
            'job_id': 1,
            'create_date': 1990 - 01 - 01,
            'resume_line_ids': [1, 2],
            'employee_skill_ids': [1, 2],
          },
        );
        return EmployeeFormBloc(service: mockEmployeeFormService);
      },
      seed: () => EmployeeFormState(
        employeeDetails: const {'id': 1},
        dropdownFocusNode: FocusNode(),
      ),
      act: (bloc) => bloc.add(DeleteSkill(1)),
      expect: () => [
        isA<EmployeeFormState>(),
        isA<EmployeeFormState>().having(
          (s) => s.employeeDetails,
          'employeeDetails',
          isNotNull,
        ),
        isA<EmployeeFormState>().having(
          (s) => s.successMessage,
          'successMessage',
          'Skill deleted successfully',
        ),
      ],
      verify: (_) {
        verify(() => mockEmployeeFormService.initializeClient()).called(1);
        verify(
          () => mockEmployeeFormService.deleteEmployeeSkill(any()),
        ).called(1);
        verify(
          () => mockEmployeeFormService.loadEmployeeDetails(any()),
        ).called(1);
      },
    );

    blocTest(
      'emits error message when deleting skill fails',
      build: () {
        when(
          () => mockEmployeeFormService.initializeClient(),
        ).thenAnswer((_) async {});
        when(
          () => mockEmployeeFormService.deleteEmployeeSkill(any()),
        ).thenAnswer((_) async => 'Failed to delete skill');
        return EmployeeFormBloc(service: mockEmployeeFormService);
      },
      seed: () => EmployeeFormState(
        employeeDetails: const {'id': 1},
        dropdownFocusNode: FocusNode(),
      ),
      act: (bloc) => bloc.add(DeleteSkill(1)),
      expect: () => [
        isA<EmployeeFormState>(),
        isA<EmployeeFormState>().having(
          (s) => s.errorMessage,
          'errorMessage',
          'Failed to delete skill',
        ),
      ],
      verify: (_) {
        verify(() => mockEmployeeFormService.initializeClient()).called(1);
        verify(
          () => mockEmployeeFormService.deleteEmployeeSkill(any()),
        ).called(1);
      },
    );

    blocTest(
      'emits error message when deleting skill throws exception',
      build: () {
        when(
          () => mockEmployeeFormService.initializeClient(),
        ).thenAnswer((_) async {});
        when(
          () => mockEmployeeFormService.deleteEmployeeSkill(any()),
        ).thenThrow(
          Exception('Failed to delete skill, Please try again later.'),
        );
        return EmployeeFormBloc(service: mockEmployeeFormService);
      },
      seed: () => EmployeeFormState(
        employeeDetails: const {'id': 1},
        dropdownFocusNode: FocusNode(),
      ),
      act: (bloc) => bloc.add(DeleteSkill(1)),
      expect: () => [
        isA<EmployeeFormState>(),
        isA<EmployeeFormState>().having(
          (s) => s.errorMessage,
          'errorMessage',
          'Failed to delete skill, Please try again later.',
        ),
      ],
      verify: (_) {
        verify(() => mockEmployeeFormService.initializeClient()).called(1);
        verify(
          () => mockEmployeeFormService.deleteEmployeeSkill(any()),
        ).called(1);
      },
    );
  });
}
