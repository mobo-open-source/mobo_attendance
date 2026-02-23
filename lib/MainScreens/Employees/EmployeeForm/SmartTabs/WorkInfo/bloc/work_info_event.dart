part of 'work_info_bloc.dart';

abstract class WorkInfoEvent {}

class LoadWorkInfo extends WorkInfoEvent {
  final int employeeId;
  LoadWorkInfo(this.employeeId);
}

class LoadWorkInfoDetails extends WorkInfoEvent {
  LoadWorkInfoDetails();
}

class ToggleEditMode extends WorkInfoEvent {}

class CancelEdit extends WorkInfoEvent {}

class UpdateSelectedAddressWithDetails extends WorkInfoEvent {
  final int? addressId;
  final Map<String, dynamic>? fullAddressDetails;

  UpdateSelectedAddressWithDetails(this.addressId, this.fullAddressDetails);
}

class UpdateSelectedLocation extends WorkInfoEvent {
  final int? locationId;
  UpdateSelectedLocation(this.locationId);
}

class UpdateSelectedExpense extends WorkInfoEvent {
  final int? expenseId;
  UpdateSelectedExpense(this.expenseId);
}

class UpdateSelectedWorkingHours extends WorkInfoEvent {
  final int? workingHoursId;
  UpdateSelectedWorkingHours(this.workingHoursId);
}

class UpdateSelectedTimezone extends WorkInfoEvent {
  final String? timezoneCode;
  UpdateSelectedTimezone(this.timezoneCode);
}

class SaveWorkInfo extends WorkInfoEvent {}