import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mobo_attendance/MainScreens/Employees/EmployeeForm/SmartTabs/PrivateInfo/bloc/private_info_bloc.dart';
import 'package:mobo_attendance/MainScreens/Employees/EmployeeForm/SmartTabs/PrivateInfo/bloc/private_info_event.dart';
import 'package:mobo_attendance/MainScreens/Employees/EmployeeForm/SmartTabs/PrivateInfo/bloc/private_info_state.dart';
import 'package:mobo_attendance/MainScreens/Employees/EmployeeForm/SmartTabs/PrivateInfo/services/private_info_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockPrivateInfoService extends Mock implements PrivateInfoService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockPrivateInfoService mockPrivateInfoService;

  setUp(() {
    mockPrivateInfoService = MockPrivateInfoService();
    SharedPreferences.setMockInitialValues({});
  });

  group('PrivateInfoBloc - Update Private Information', () {
    blocTest<PrivateInfoBloc, PrivateInfoState>(
      'emits loading state, success message, and refreshes private info when update succeeds',
      build: () {
        when(
          () => mockPrivateInfoService.initializeClient(),
        ).thenAnswer((_) async {});
        when(
          () => mockPrivateInfoService.updateEmployeeDetails(any(), any()),
        ).thenAnswer(
          (_) async => {'success': true, 'error': null, 'warning': false},
        );
        when(
          () => mockPrivateInfoService.loadEmployeeDetails(any()),
        ).thenAnswer((_) async => {});
        return PrivateInfoBloc(service: mockPrivateInfoService);
      },
      seed: () {
        final state = PrivateInfoState(dropdownFocusNode: FocusNode()).copyWith(
          selectedPrivateStateId: 1,
          selectedPrivateCountryId: 1,
          selectedPrivateLangId: 'en',
          selectedCountryId: 1,
          selectedBirthCountryId: 1,
          selectedMarital: 'single',
          selectedCertificate: 'bachelor',
          selectedPrivateBankId: 1,
          selectedGender: 'male',
        );

        state.privateStreetController.text = '123 Main St';
        state.privateStreet2Controller.text = 'Apt 4B';
        state.privateCityController.text = 'Springfield';
        state.privateEmailController.text = 'john@example.com';
        state.privatePhoneController.text = '1234567890';
        state.kmHomeWorkController.text = '15';
        state.privateCarPlateController.text = 'XYZ-1234';
        state.identificationIdController.text = 'ID123';
        state.ssnIdController.text = 'SSN456';
        state.passportIdController.text = 'P123456';
        state.birthdayController.text = '1990-01-01';
        state.placeOfBirthController.text = 'Springfield';
        state.spouseNameController.text = 'Jane Doe';
        state.spouseBirthdayController.text = '1992-02-02';
        state.childrenController.text = '2';
        state.studyFieldController.text = 'Computer Science';
        state.studySchoolController.text = 'MIT';
        state.visaNoController.text = 'VISA123';
        state.permitNoController.text = 'PERMIT456';
        state.visaExpireController.text = '2030-12-31';
        state.workPermitExpireController.text = '2030-12-31';

        return state;
      },
      act: (bloc) => bloc.add(SavePrivateInfo(1)),
      expect: () => [
        isA<PrivateInfoState>().having((s) => s.isSaving, 'isSaving', true),
        isA<PrivateInfoState>()
            .having((s) => s.isSaving, 'isSaving', false)
            .having(
              (s) => s.successMessage,
              'successMessage',
              'Private info updated successfully!',
            ),
        isA<PrivateInfoState>(),
        isA<PrivateInfoState>().having((s) => s.isSaving, 'isSaving', false),
      ],
      verify: (_) {
        verify(() => mockPrivateInfoService.initializeClient()).called(1);
        verify(
          () => mockPrivateInfoService.updateEmployeeDetails(any(), any()),
        ).called(1);
        verify(
          () => mockPrivateInfoService.loadEmployeeDetails(any()),
        ).called(1);
      },
    );

    blocTest<PrivateInfoBloc, PrivateInfoState>(
      'emits loading state and warning message when update completes with a warning response',
      build: () {
        when(
          () => mockPrivateInfoService.initializeClient(),
        ).thenAnswer((_) async {});
        when(
          () => mockPrivateInfoService.updateEmployeeDetails(any(), any()),
        ).thenAnswer(
          (_) async => {
            'success': false,
            'warningMessage': 'You have not access to edit.',
            'warning': true,
          },
        );

        return PrivateInfoBloc(service: mockPrivateInfoService);
      },
      seed: () {
        final state = PrivateInfoState(dropdownFocusNode: FocusNode()).copyWith(
          selectedPrivateStateId: 1,
          selectedPrivateCountryId: 1,
          selectedPrivateLangId: 'en',
          selectedCountryId: 1,
          selectedBirthCountryId: 1,
          selectedMarital: 'single',
          selectedCertificate: 'bachelor',
          selectedPrivateBankId: 1,
          selectedGender: 'male',
        );

        state.privateStreetController.text = '123 Main St';
        state.privateStreet2Controller.text = 'Apt 4B';
        state.privateCityController.text = 'Springfield';
        state.privateEmailController.text = 'john@example.com';
        state.privatePhoneController.text = '1234567890';
        state.kmHomeWorkController.text = '15';
        state.privateCarPlateController.text = 'XYZ-1234';
        state.identificationIdController.text = 'ID123';
        state.ssnIdController.text = 'SSN456';
        state.passportIdController.text = 'P123456';
        state.birthdayController.text = '1990-01-01';
        state.placeOfBirthController.text = 'Springfield';
        state.spouseNameController.text = 'Jane Doe';
        state.spouseBirthdayController.text = '1992-02-02';
        state.childrenController.text = '2';
        state.studyFieldController.text = 'Computer Science';
        state.studySchoolController.text = 'MIT';
        state.visaNoController.text = 'VISA123';
        state.permitNoController.text = 'PERMIT456';
        state.visaExpireController.text = '2030-12-31';
        state.workPermitExpireController.text = '2030-12-31';

        return state;
      },
      act: (bloc) => bloc.add(SavePrivateInfo(1)),
      expect: () => [
        isA<PrivateInfoState>().having((s) => s.isSaving, 'isSaving', true),
        isA<PrivateInfoState>()
            .having((s) => s.isSaving, 'isSaving', false)
            .having(
              (s) => s.warningMessage,
              'warningMessage',
              'You have not access to edit.',
            ),
        isA<PrivateInfoState>().having((s) => s.isSaving, 'isSaving', false),
      ],
      verify: (_) {
        verify(() => mockPrivateInfoService.initializeClient()).called(1);
        verify(
          () => mockPrivateInfoService.updateEmployeeDetails(any(), any()),
        ).called(1);
      },
    );

    blocTest<PrivateInfoBloc, PrivateInfoState>(
      'emits loading state and error message when update fails with an error response',
      build: () {
        when(
          () => mockPrivateInfoService.initializeClient(),
        ).thenAnswer((_) async {});
        when(
          () => mockPrivateInfoService.updateEmployeeDetails(any(), any()),
        ).thenAnswer(
          (_) async => {
            'success': false,
            'errorMessage': 'Failed to update private info',
            'warning': false,
          },
        );

        return PrivateInfoBloc(service: mockPrivateInfoService);
      },
      seed: () {
        final state = PrivateInfoState(dropdownFocusNode: FocusNode()).copyWith(
          selectedPrivateStateId: 1,
          selectedPrivateCountryId: 1,
          selectedPrivateLangId: 'en',
          selectedCountryId: 1,
          selectedBirthCountryId: 1,
          selectedMarital: 'single',
          selectedCertificate: 'bachelor',
          selectedPrivateBankId: 1,
          selectedGender: 'male',
        );

        state.privateStreetController.text = '123 Main St';
        state.privateStreet2Controller.text = 'Apt 4B';
        state.privateCityController.text = 'Springfield';
        state.privateEmailController.text = 'john@example.com';
        state.privatePhoneController.text = '1234567890';
        state.kmHomeWorkController.text = '15';
        state.privateCarPlateController.text = 'XYZ-1234';
        state.identificationIdController.text = 'ID123';
        state.ssnIdController.text = 'SSN456';
        state.passportIdController.text = 'P123456';
        state.birthdayController.text = '1990-01-01';
        state.placeOfBirthController.text = 'Springfield';
        state.spouseNameController.text = 'Jane Doe';
        state.spouseBirthdayController.text = '1992-02-02';
        state.childrenController.text = '2';
        state.studyFieldController.text = 'Computer Science';
        state.studySchoolController.text = 'MIT';
        state.visaNoController.text = 'VISA123';
        state.permitNoController.text = 'PERMIT456';
        state.visaExpireController.text = '2030-12-31';
        state.workPermitExpireController.text = '2030-12-31';

        return state;
      },
      act: (bloc) => bloc.add(SavePrivateInfo(1)),
      expect: () => [
        isA<PrivateInfoState>().having((s) => s.isSaving, 'isSaving', true),
        isA<PrivateInfoState>()
            .having((s) => s.isSaving, 'isSaving', false)
            .having(
              (s) => s.errorMessage,
              'errorMessage',
              'Failed to update private info',
            ),
        isA<PrivateInfoState>().having((s) => s.isSaving, 'isSaving', false),
      ],
      verify: (_) {
        verify(() => mockPrivateInfoService.initializeClient()).called(1);
        verify(
          () => mockPrivateInfoService.updateEmployeeDetails(any(), any()),
        ).called(1);
      },
    );

    blocTest<PrivateInfoBloc, PrivateInfoState>(
      'emits loading state and exception message when update throws an unexpected error',
      build: () {
        when(
          () => mockPrivateInfoService.initializeClient(),
        ).thenAnswer((_) async {});
        when(
          () => mockPrivateInfoService.updateEmployeeDetails(any(), any()),
        ).thenThrow(
          Exception('Failed to update private info, Please try again later'),
        );

        return PrivateInfoBloc(service: mockPrivateInfoService);
      },
      seed: () {
        final state = PrivateInfoState(dropdownFocusNode: FocusNode()).copyWith(
          selectedPrivateStateId: 1,
          selectedPrivateCountryId: 1,
          selectedPrivateLangId: 'en',
          selectedCountryId: 1,
          selectedBirthCountryId: 1,
          selectedMarital: 'single',
          selectedCertificate: 'bachelor',
          selectedPrivateBankId: 1,
          selectedGender: 'male',
        );

        state.privateStreetController.text = '123 Main St';
        state.privateStreet2Controller.text = 'Apt 4B';
        state.privateCityController.text = 'Springfield';
        state.privateEmailController.text = 'john@example.com';
        state.privatePhoneController.text = '1234567890';
        state.kmHomeWorkController.text = '15';
        state.privateCarPlateController.text = 'XYZ-1234';
        state.identificationIdController.text = 'ID123';
        state.ssnIdController.text = 'SSN456';
        state.passportIdController.text = 'P123456';
        state.birthdayController.text = '1990-01-01';
        state.placeOfBirthController.text = 'Springfield';
        state.spouseNameController.text = 'Jane Doe';
        state.spouseBirthdayController.text = '1992-02-02';
        state.childrenController.text = '2';
        state.studyFieldController.text = 'Computer Science';
        state.studySchoolController.text = 'MIT';
        state.visaNoController.text = 'VISA123';
        state.permitNoController.text = 'PERMIT456';
        state.visaExpireController.text = '2030-12-31';
        state.workPermitExpireController.text = '2030-12-31';

        return state;
      },
      act: (bloc) => bloc.add(SavePrivateInfo(1)),
      expect: () => [
        isA<PrivateInfoState>().having((s) => s.isSaving, 'isSaving', true),
        isA<PrivateInfoState>()
            .having((s) => s.isSaving, 'isSaving', false)
            .having(
              (s) => s.errorMessage,
              'errorMessage',
              'Failed to update private info, Please try again later',
            ),
        isA<PrivateInfoState>().having((s) => s.isSaving, 'isSaving', false),
      ],
      verify: (_) {
        verify(() => mockPrivateInfoService.initializeClient()).called(1);
        verify(
          () => mockPrivateInfoService.updateEmployeeDetails(any(), any()),
        ).called(1);
      },
    );
  });

  group('PrivateInfoBloc - Upload Work Permit', () {
    blocTest<PrivateInfoBloc, PrivateInfoState>(
      'emits loading state, success message, and refreshes private info when upload succeeds',
      build: () {
        when(
          () => mockPrivateInfoService.initializeClient(),
        ).thenAnswer((_) async {});
        when(() => mockPrivateInfoService.writePermit(any(), any())).thenAnswer(
          (_) async => {'success': true, 'error': null, 'warning': false},
        );
        when(
          () => mockPrivateInfoService.loadEmployeeDetails(any()),
        ).thenAnswer((_) async => {});
        return PrivateInfoBloc(service: mockPrivateInfoService);
      },
      act: (bloc) => bloc.add(
        UploadWorkPermit(
          1,
          Uint8List.fromList([1, 2, 3, 4, 5]),
          base64Encode(Uint8List.fromList([1, 2, 3, 4, 5])),
        ),
      ),
      expect: () => [
        isA<PrivateInfoState>().having((s) => s.isSaving, 'isSaving', true),
        isA<PrivateInfoState>()
            .having((s) => s.isSaving, 'isSaving', false)
            .having(
              (s) => s.successMessage,
              'successMessage',
              'Work permit updated successfully!',
            ),
        isA<PrivateInfoState>(),
        isA<PrivateInfoState>().having((s) => s.isSaving, 'isSaving', false),
      ],
      verify: (_) {
        verify(() => mockPrivateInfoService.initializeClient()).called(1);
        verify(
          () => mockPrivateInfoService.writePermit(any(), any()),
        ).called(1);
        verify(
          () => mockPrivateInfoService.loadEmployeeDetails(any()),
        ).called(1);
      },
    );

    blocTest<PrivateInfoBloc, PrivateInfoState>(
      'emits loading state and warning message when upload completes with a warning response',
      build: () {
        when(
          () => mockPrivateInfoService.initializeClient(),
        ).thenAnswer((_) async {});
        when(() => mockPrivateInfoService.writePermit(any(), any())).thenAnswer(
          (_) async => {
            'success': false,
            'warningMessage': 'You have not access to upload.',
            'warning': true,
          },
        );

        return PrivateInfoBloc(service: mockPrivateInfoService);
      },
      act: (bloc) => bloc.add(
        UploadWorkPermit(
          1,
          Uint8List.fromList([1, 2, 3, 4, 5]),
          base64Encode(Uint8List.fromList([1, 2, 3, 4, 5])),
        ),
      ),
      expect: () => [
        isA<PrivateInfoState>().having((s) => s.isSaving, 'isSaving', true),
        isA<PrivateInfoState>()
            .having((s) => s.isSaving, 'isSaving', false)
            .having(
              (s) => s.warningMessage,
              'warningMessage',
              'You have not access to upload.',
            ),
        isA<PrivateInfoState>().having((s) => s.isSaving, 'isSaving', false),
      ],
      verify: (_) {
        verify(() => mockPrivateInfoService.initializeClient()).called(1);
        verify(
          () => mockPrivateInfoService.writePermit(any(), any()),
        ).called(1);
      },
    );

    blocTest<PrivateInfoBloc, PrivateInfoState>(
      'emits loading state and error message when upload fails with an error response',
      build: () {
        when(
          () => mockPrivateInfoService.initializeClient(),
        ).thenAnswer((_) async {});
        when(() => mockPrivateInfoService.writePermit(any(), any())).thenAnswer(
          (_) async => {
            'success': false,
            'errorMessage': 'Failed to upload work permit',
            'warning': false,
          },
        );

        return PrivateInfoBloc(service: mockPrivateInfoService);
      },
      act: (bloc) => bloc.add(
        UploadWorkPermit(
          1,
          Uint8List.fromList([1, 2, 3, 4, 5]),
          base64Encode(Uint8List.fromList([1, 2, 3, 4, 5])),
        ),
      ),
      expect: () => [
        isA<PrivateInfoState>().having((s) => s.isSaving, 'isSaving', true),
        isA<PrivateInfoState>()
            .having((s) => s.isSaving, 'isSaving', false)
            .having(
              (s) => s.errorMessage,
              'errorMessage',
              'Failed to upload work permit',
            ),
        isA<PrivateInfoState>().having((s) => s.isSaving, 'isSaving', false),
      ],
      verify: (_) {
        verify(() => mockPrivateInfoService.initializeClient()).called(1);
        verify(
          () => mockPrivateInfoService.writePermit(any(), any()),
        ).called(1);
      },
    );

    blocTest<PrivateInfoBloc, PrivateInfoState>(
      'emits loading state and exception message when upload throws an unexpected error',
      build: () {
        when(
          () => mockPrivateInfoService.initializeClient(),
        ).thenAnswer((_) async {});
        when(() => mockPrivateInfoService.writePermit(any(), any())).thenThrow(
          Exception('Failed to upload work permit, Please try again later'),
        );

        return PrivateInfoBloc(service: mockPrivateInfoService);
      },
      act: (bloc) => bloc.add(
        UploadWorkPermit(
          1,
          Uint8List.fromList([1, 2, 3, 4, 5]),
          base64Encode(Uint8List.fromList([1, 2, 3, 4, 5])),
        ),
      ),
      expect: () => [
        isA<PrivateInfoState>().having((s) => s.isSaving, 'isSaving', true),
        isA<PrivateInfoState>().having(
          (s) => s.errorMessage,
          'errorMessage',
          'Failed to upload work permit, Please try again later',
        ),
        isA<PrivateInfoState>().having((s) => s.isSaving, 'isSaving', false),
      ],
      verify: (_) {
        verify(() => mockPrivateInfoService.initializeClient()).called(1);
        verify(
          () => mockPrivateInfoService.writePermit(any(), any()),
        ).called(1);
      },
    );
  });
}
