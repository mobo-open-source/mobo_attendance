import 'package:flutter_bloc/flutter_bloc.dart';
import '../services/work_info_service.dart';

part 'work_info_event.dart';

part 'work_info_state.dart';

class WorkInfoBloc extends Bloc<WorkInfoEvent, WorkInfoState> {
  late WorkInfoService _service;

  WorkInfoBloc({WorkInfoService? service})
      : _service = service ?? WorkInfoService(),
        super(WorkInfoInitial()) {
    on<LoadWorkInfo>(_onLoadWorkInfo);
    on<LoadWorkInfoDetails>(_onLoadWorkInfoDetails);
    on<ToggleEditMode>(_onToggleEditMode);
    on<CancelEdit>(_onCancelEdit);
    on<UpdateSelectedAddressWithDetails>(_onUpdateSelectedAddressWithDetails);
    on<UpdateSelectedLocation>(_onUpdateSelectedLocation);
    on<UpdateSelectedExpense>(_onUpdateSelectedExpense);
    on<UpdateSelectedWorkingHours>(_onUpdateSelectedWorkingHours);
    on<UpdateSelectedTimezone>(_onUpdateSelectedTimezone);
    on<SaveWorkInfo>(_onSaveWorkInfo);
  }

  Future<void> _onLoadWorkInfo(
    LoadWorkInfo event,
    Emitter<WorkInfoState> emit,
  ) async {
    final preservedAddressList = state.addressList;
    final preservedLocationList = state.locationList;
    final preservedExpenseList = state.expenseList;
    final preservedWorkingHoursList = state.workingHoursList;
    final preservedTimeZoneList = state.timeZoneList;
    emit(
      state.copyWith(
        isLoading: true,

        isAddress: true,
        isLocation: true,
        isExpense: true,
        isWorkHour: true,
        isTz: true,

        addressList: preservedAddressList,
        locationList: preservedLocationList,
        expenseList: preservedExpenseList,
        workingHoursList: preservedWorkingHoursList,
        timeZoneList: preservedTimeZoneList,
      ),
    );

    try {
      await _service.initializeClient();

      final hasPermission = await _service.canManageSkills();
      final parentChain = await _service.fetchParentChain(event.employeeId);
      final orgChart = parentChain.reversed.toList();
      final employeeDetails = await _service.loadEmployeeDetails(
        event.employeeId,
        hasPermission,
      );

      Map<String, dynamic>? addressDetails;
      int? initialAddressId;
      if (employeeDetails != null &&
          employeeDetails['address_id'] is List &&
          employeeDetails['address_id'].isNotEmpty) {
        final addrId = employeeDetails['address_id'][0];
        addressDetails = await _service.loadFullAddress(addrId);
        initialAddressId = addrId;
      }

      final initialLocationId =
          (employeeDetails?['work_location_id'] is List &&
              employeeDetails!['work_location_id'].isNotEmpty)
          ? employeeDetails['work_location_id'][0]
          : null;

      final initialExpenseId =
          (employeeDetails?['attendance_manager_id'] is List &&
              employeeDetails!['attendance_manager_id'].isNotEmpty)
          ? employeeDetails['attendance_manager_id'][0]
          : null;

      final initialWorkingHoursId =
          (employeeDetails?['resource_calendar_id'] is List &&
              employeeDetails!['resource_calendar_id'].isNotEmpty)
          ? employeeDetails['resource_calendar_id'][0]
          : null;

      final initialTz = employeeDetails?['tz'] ?? 'UTC';

      emit(
        state.copyWith(
          hasEditPermission: hasPermission,

          addressList: preservedAddressList,
          locationList: preservedLocationList,
          expenseList: preservedExpenseList,
          workingHoursList: preservedWorkingHoursList,
          timeZoneList: preservedTimeZoneList,

          employeeDetails: employeeDetails,
          addressDetails: addressDetails,
          selectedAddressId: initialAddressId,
          selectedLocationId: initialLocationId,
          selectedExpenseId: initialExpenseId,
          selectedWorkingHoursId: initialWorkingHoursId,
          selectedTzId: initialTz,
          orgChartList: orgChart,
          isLoading: false,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: 'Failed to load data: $e',

          addressList: preservedAddressList,
          locationList: preservedLocationList,
          expenseList: preservedExpenseList,
          workingHoursList: preservedWorkingHoursList,
          timeZoneList: preservedTimeZoneList,
        ),
      );
    }
  }

  Future<void> _onLoadWorkInfoDetails(
    LoadWorkInfoDetails event,
    Emitter<WorkInfoState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));

    try {
      await _service.initializeClient();

      final hasPermission = await _service.canManageSkills();
      final addressList = await _service.loadAddress();
      final locationList = await _service.loadLocation();
      final expenseList = await _service.loadExpense();
      final workingHoursList = await _service.loadWorkingHours();
      final timeZoneList = await _service.fetchTimezones();

      emit(
        state.copyWith(
          hasEditPermission: hasPermission,
          addressList: addressList,
          locationList: locationList,
          expenseList: expenseList,
          workingHoursList: workingHoursList,
          timeZoneList: timeZoneList,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: 'Failed to load data: $e',
        ),
      );
    }
  }

  int? _safeRelId(dynamic field) {
    if (field is List && field.isNotEmpty) return field[0];
    return null;
  }

  bool _detectChanges(WorkInfoState state) {
    final original = state.employeeDetails;

    return state.selectedAddressId != _safeRelId(original?['address_id']) ||
        state.selectedLocationId != _safeRelId(original?['work_location_id']) ||
        state.selectedExpenseId !=
            _safeRelId(original?['attendance_manager_id']) ||
        state.selectedWorkingHoursId !=
            _safeRelId(original?['resource_calendar_id']) ||
        state.selectedTzId != (original?['tz'] ?? 'UTC');
  }

  void _onToggleEditMode(ToggleEditMode event, Emitter<WorkInfoState> emit) {
    emit(state.copyWith(isEditing: true));
  }

  void _onCancelEdit(CancelEdit event, Emitter<WorkInfoState> emit) {
    emit(state.copyWith(isEditing: false));
  }

  Future<void> _onUpdateSelectedAddressWithDetails(
    UpdateSelectedAddressWithDetails event,
    Emitter<WorkInfoState> emit,
  ) async {
    final updated = state.copyWith(
      selectedAddressId: event.addressId,
      addressDetails: event.fullAddressDetails,
    );

    emit(updated.copyWith(hasChanges: _detectChanges(updated)));
  }

  void _onUpdateSelectedLocation(
    UpdateSelectedLocation event,
    Emitter<WorkInfoState> emit,
  ) {
    final updated = state.copyWith(selectedLocationId: event.locationId);
    emit(updated.copyWith(hasChanges: _detectChanges(updated)));
  }

  void _onUpdateSelectedExpense(
    UpdateSelectedExpense event,
    Emitter<WorkInfoState> emit,
  ) {
    final updated = state.copyWith(selectedExpenseId: event.expenseId);
    emit(updated.copyWith(hasChanges: _detectChanges(updated)));
  }

  void _onUpdateSelectedWorkingHours(
    UpdateSelectedWorkingHours event,
    Emitter<WorkInfoState> emit,
  ) {
    final updated = state.copyWith(
      selectedWorkingHoursId: event.workingHoursId,
    );
    emit(updated.copyWith(hasChanges: _detectChanges(updated)));
  }

  void _onUpdateSelectedTimezone(
    UpdateSelectedTimezone event,
    Emitter<WorkInfoState> emit,
  ) {
    final updated = state.copyWith(selectedTzId: event.timezoneCode);
    emit(updated.copyWith(hasChanges: _detectChanges(updated)));
  }

  Future<void> _onSaveWorkInfo(
    SaveWorkInfo event,
    Emitter<WorkInfoState> emit,
  ) async {
    emit(state.copyWith(isSaving: true));

    try {
      await _service.initializeClient();
      final hasPermission = await _service.canManageSkills();
      final bool isAdmin = await _service.isSystemAdmin();

      final data = {
        'address_id': state.selectedAddressId,
        'work_location_id': state.selectedLocationId,
        if (isAdmin) 'attendance_manager_id': state.selectedExpenseId,
        if (state.selectedWorkingHoursId != null)
          'resource_calendar_id': state.selectedWorkingHoursId,
        'tz': state.selectedTzId ?? state.employeeDetails?['tz'],
      };

      final result = await _service.updateEmployeeDetails(
        state.employeeDetails?['id'],
        data,
      );

      if (result['success'] == true) {
        final updatedDetails = await _service.loadEmployeeDetails(
          state.employeeDetails?['id'],
          hasPermission,
        );

        Map<String, dynamic>? newAddressDetails;
        if (state.selectedAddressId != null) {
          newAddressDetails = await _service.loadFullAddress(
            state.selectedAddressId!,
          );
        }

        emit(
          state.copyWith(
            isSaving: false,
            isEditing: false,
            employeeDetails: updatedDetails,
            addressDetails: newAddressDetails,
            selectedAddressId: state.selectedAddressId,
            selectedLocationId: state.selectedLocationId,
            selectedExpenseId: state.selectedExpenseId,
            selectedWorkingHoursId: state.selectedWorkingHoursId,
            selectedTzId: state.selectedTzId,
            successMessage: "Work info updated successfully!",
          ),
        );
      } else if (result['warning'] == true) {
        emit(
          state.copyWith(
            warningMessage:
                result['warningMessage'] ??
                "Warning: Could not update all fields",
            isEditing: false,
            isSaving: false,
          ),
        );
      } else {
        emit(
          state.copyWith(
            isSaving: false,
            isEditing: false,
            errorMessage: "Failed to update work info, Please try again later",
          ),
        );
      }
    } catch (e) {
      emit(
        state.copyWith(
          isSaving: false,
          isEditing: false,
          errorMessage: 'Failed to update work info, Please try again later',
        ),
      );
    }
  }
}
