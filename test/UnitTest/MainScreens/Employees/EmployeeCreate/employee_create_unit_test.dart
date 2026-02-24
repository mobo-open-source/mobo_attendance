import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mobo_attendance/MainScreens/Employees/EmployeeCreate/bloc/employee_create_bloc.dart';
import 'package:mobo_attendance/MainScreens/Employees/EmployeeCreate/bloc/employee_create_event.dart';
import 'package:mobo_attendance/MainScreens/Employees/EmployeeCreate/bloc/employee_create_state.dart';
import 'package:mobo_attendance/MainScreens/Employees/EmployeeCreate/services/employee_create_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockEmployeeCreateService extends Mock implements EmployeeCreateService {}

void fillMandatoryFields(EmployeeCreateBloc bloc) {
  bloc.emit(
    bloc.state.copyWith(
      name: 'John Doe',
      workEmail: 'john@company.com',
      workPhone: '11111111111',
      mobilePhone: '9999999999',
      pin: '123456',
      badge: '222222222',
      imageBase64: 'https://abc.com',
      departmentId: 1,
      jobId: 1,
      managerId: 1,
      coachId: 1,
      userId: 1,
      employeeType: 'employee',
      privateStreet: 'London Street',
      privateStreet2: 'London Street 2',
      privateCity: 'London',
      privateStateId: 1,
      privateCountryId: 1,
      privateEmail: 'john@gmail.com',
      privatePhone: '22222222',
      privateBankId: 1,
      privateLang: 'en',
      kmHomeWork: '20',
      privateCarPlate: 'AB123CD',
      countryId: 2,
      identificationId: 'ID123',
      ssnId: 'SSN123',
      passportId: 'P123456',
      birthday: '1990-01-01',
      gender: 'male',
      placeOfBirth: 'London',
      countryOfBirthId: 1,
      maritalStatus: 'single',
      spouseName: 'Alice Doe',
      spouseBirthday: '1990-01-01',
      children: '2',
      certificate: 'odoo',
      fieldOfStudy: 'IT',
      studySchool: 'abc',
      visaNo: 'VS123',
      permitNo: 'PR123',
      visaExpire: '1990-01-01',
      workPermitExpire: '1990-01-01',
      addressId: 1,
      workLocationId: 1,
      expenseManagerId: 1,
      workingHoursId: 1,
      timezone: 'en',
      resumeLines: [
        {
          "name": 'Developer',
          "line_type_id": {'id': 1, 'name': 'Job'},
          "date_start": 1990 - 01 - 01,
          "date_end": 1990 - 01 - 01,
          "description": null,
        },
      ],
      selectedSkills: [
        {
          "skill_id": {'id': 1, 'name': "leadership"},
          "skill_level_id": {'id': 1, 'name': 'Medium'},
          "skill_type_id": {'id': 1, 'name': 'Medium'},
        },
      ],
    ),
  );
}

void main() {
  late MockEmployeeCreateService mockEmployeeCreateService;
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    mockEmployeeCreateService = MockEmployeeCreateService();
    SharedPreferences.setMockInitialValues({});
  });

  group('EmployeeCreateBloc - Employee creation', () {
    blocTest(
      'Should emit [isSaving = true, success = true, employeeId] when employee creation succeeds',
      build: () {
        when(
          () => mockEmployeeCreateService.loadState(any()),
        ).thenAnswer((_) async => []);
        when(
          () => mockEmployeeCreateService.createEmployeeDetails(
            any(),
            any(),
            any(),
          ),
        ).thenAnswer((_) async => {'success': true, 'employee_id': 1});
        return EmployeeCreateBloc(service: mockEmployeeCreateService);
      },
      act: (bloc) async {
        fillMandatoryFields(bloc);
        bloc.add(CreateEmployee());
      },
      wait: const Duration(milliseconds: 10),
      expect: () => [
        isA<EmployeeCreateState>().having((s) => s.isSaving, 'isSaving', true),
        isA<EmployeeCreateState>()
            .having((s) => s.success, 'success', true)
            .having((s) => s.isSaving, 'isSaving', false)
            .having((s) => s.employeeId, 'employeeId', 1),
      ],
      skip: 1,
      verify: (_) {
        verify(
          () => mockEmployeeCreateService.createEmployeeDetails(
            any(),
            any(),
            any(),
          ),
        ).called(1);
      },
    );

    blocTest<EmployeeCreateBloc, EmployeeCreateState>(
      'Should emit errorMessage when name is empty and CreateEmployee is added',
      build: () {
        when(
          () => mockEmployeeCreateService.loadState(any()),
        ).thenAnswer((_) async => []);
        when(
          () => mockEmployeeCreateService.createEmployeeDetails(
            any(),
            any(),
            any(),
          ),
        ).thenAnswer((_) async => {'success': true, 'employee_id': 999});

        return EmployeeCreateBloc(service: mockEmployeeCreateService);
      },
      seed: () => EmployeeCreateState(
        name: '',
        workEmail: 'test@company.com',
        workPhone: '1234567890',
        mobilePhone: '9876543210',
        pin: '1234',
        badge: 'EMP001',
        isSaving: false,
        success: false,
        errorMessage: null,
        dropdownFocusNode: FocusNode(),
      ),
      act: (bloc) async {
        bloc.add(CreateEmployee());
      },
      wait: const Duration(milliseconds: 10),
      expect: () => [
        isA<EmployeeCreateState>()
            .having((s) => s.isSaving, 'isSaving', false)
            .having((s) => s.errorMessage, 'errorMessage', 'Name is required')
            .having((s) => s.success, 'success', false),
      ],
      verify: (_) {
        verifyNever(
          () => mockEmployeeCreateService.createEmployeeDetails(
            any(),
            any(),
            any(),
          ),
        );
      },
    );

    blocTest(
      'Should emit [isSaving = true, errorMessage] when employee creation fails from API',
      build: () {
        when(
          () => mockEmployeeCreateService.loadState(any()),
        ).thenAnswer((_) async => []);
        when(
          () => mockEmployeeCreateService.createEmployeeDetails(
            any(),
            any(),
            any(),
          ),
        ).thenAnswer(
          (_) async => {
            'success': false,
            'errorMessage': 'Failed to create employee',
          },
        );
        return EmployeeCreateBloc(service: mockEmployeeCreateService);
      },
      act: (bloc) async {
        fillMandatoryFields(bloc);
        bloc.add(CreateEmployee());
      },
      wait: const Duration(milliseconds: 10),
      expect: () => [
        isA<EmployeeCreateState>().having((s) => s.isSaving, 'isSaving', true),
        isA<EmployeeCreateState>()
            .having((s) => s.success, 'success', false)
            .having((s) => s.isSaving, 'isSaving', false)
            .having(
              (s) => s.errorMessage,
              'errorMessage',
              'Failed to create employee',
            ),
      ],
      skip: 1,
      verify: (_) {
        verify(
          () => mockEmployeeCreateService.createEmployeeDetails(
            any(),
            any(),
            any(),
          ),
        ).called(1);
      },
    );

    blocTest(
      'Should emit errorMessage when employee creation throws an exception',
      build: () {
        when(
          () => mockEmployeeCreateService.loadState(any()),
        ).thenAnswer((_) async => []);
        when(
          () => mockEmployeeCreateService.createEmployeeDetails(
            any(),
            any(),
            any(),
          ),
        ).thenThrow(Exception('Connection failed'));
        return EmployeeCreateBloc(service: mockEmployeeCreateService);
      },
      act: (bloc) async {
        fillMandatoryFields(bloc);
        bloc.add(CreateEmployee());
      },
      wait: const Duration(milliseconds: 10),
      expect: () => [
        isA<EmployeeCreateState>().having((s) => s.isSaving, 'isSaving', true),
        isA<EmployeeCreateState>()
            .having((s) => s.isSaving, 'isSaving', false)
            .having(
              (s) => s.errorMessage,
              'errorMessage',
              'Something went wrong, please try again later',
            ),
      ],
      skip: 1,
      verify: (_) {
        verify(
          () => mockEmployeeCreateService.createEmployeeDetails(
            any(),
            any(),
            any(),
          ),
        ).called(1);
      },
    );
  });
}
