part of 'work_info_bloc.dart';

class WorkInfoState {
  final bool isLoading;
  final bool isEditing;
  final bool isSaving;
  final bool hasEditPermission;
  final bool hasChanges;

  final Map<String, dynamic>? employeeDetails;
  final Map<String, dynamic>? addressDetails;

  final List<Map<String, dynamic>> addressList;
  final List<Map<String, dynamic>> locationList;
  final List<Map<String, dynamic>> expenseList;
  final List<Map<String, dynamic>> workingHoursList;
  final List<Map<String, dynamic>> timeZoneList;
  final List<Map<String, dynamic>> orgChartList;

  final int? selectedAddressId;
  final int? selectedLocationId;
  final int? selectedExpenseId;
  final int? selectedWorkingHoursId;
  final String? selectedTzId;

  final String? successMessage;
  final String? errorMessage;
  final String? warningMessage;

  WorkInfoState({
    this.isLoading = false,
    this.isEditing = false,
    this.isSaving = false,
    this.hasEditPermission = false,
    this.hasChanges = false,

    this.employeeDetails,
    this.addressDetails,
    this.addressList = const [],
    this.locationList = const [],
    this.expenseList = const [],
    this.workingHoursList = const [],
    this.timeZoneList = const [],
    this.orgChartList = const [],
    this.selectedAddressId,
    this.selectedLocationId,
    this.selectedExpenseId,
    this.selectedWorkingHoursId,
    this.selectedTzId,
    this.errorMessage,
    this.warningMessage,
    this.successMessage,
  });

  WorkInfoState copyWith({
    bool? isLoading,
    bool? isEditing,
    bool? isSaving,
    bool? hasEditPermission,
    bool? hasChanges,

    Map<String, dynamic>? employeeDetails,
    Map<String, dynamic>? addressDetails,
    List<Map<String, dynamic>>? addressList,
    List<Map<String, dynamic>>? locationList,
    List<Map<String, dynamic>>? expenseList,
    List<Map<String, dynamic>>? workingHoursList,
    List<Map<String, dynamic>>? timeZoneList,
    List<Map<String, dynamic>>? orgChartList,
    int? selectedAddressId,
    bool isAddress = false,
    int? selectedLocationId,
    bool isLocation = false,
    int? selectedExpenseId,
    bool isExpense = false,
    int? selectedWorkingHoursId,
    bool isWorkHour = false,
    String? selectedTzId,
    bool isTz = false,
    String? errorMessage,
    String? warningMessage,
    String? successMessage,
  }) {
    return WorkInfoState(
      isLoading: isLoading ?? this.isLoading,
      isEditing: isEditing ?? this.isEditing,
      isSaving: isSaving ?? this.isSaving,
      hasEditPermission: hasEditPermission ?? this.hasEditPermission,
      hasChanges: hasChanges ?? this.hasChanges,

      employeeDetails: employeeDetails ?? this.employeeDetails,
      addressDetails: addressDetails ?? this.addressDetails,
      addressList: addressList ?? this.addressList,
      locationList: locationList ?? this.locationList,
      expenseList: expenseList ?? this.expenseList,
      workingHoursList: workingHoursList ?? this.workingHoursList,
      timeZoneList: timeZoneList ?? this.timeZoneList,
      orgChartList: orgChartList ?? this.orgChartList,
      selectedAddressId: isAddress
          ? null
          : selectedAddressId ?? this.selectedAddressId,
      selectedLocationId: isLocation
          ? null
          : selectedLocationId ?? this.selectedLocationId,
      selectedExpenseId: isExpense
          ? null
          : selectedExpenseId ?? this.selectedExpenseId,
      selectedWorkingHoursId:
      isWorkHour
          ? null
          : selectedWorkingHoursId ?? this.selectedWorkingHoursId,
      selectedTzId: isTz
          ? null
          : selectedTzId ?? this.selectedTzId,
      errorMessage: errorMessage,
      warningMessage: warningMessage,
      successMessage: successMessage,
    );
  }
}

class WorkInfoInitial extends WorkInfoState {}
