import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../../../CommonWidgets/core/language/translate_widget.dart';
import '../../../../../../CommonWidgets/core/navigation/data_loss_warning_dialog.dart';
import '../../../../../../CommonWidgets/core/providers/language_provider.dart';
import '../../../../../../CommonWidgets/globals.dart';
import '../../../../../../CommonWidgets/shared/widgets/snackbar.dart';
import '../bloc/work_info_bloc.dart';
import '../services/work_info_service.dart';
import '../widgets/organization_chart.dart';
import '../widgets/work_info_row.dart';

/// Full-screen page for viewing and editing an employee's **work-related information**.
///
/// Features:
/// - View mode: clean read-only display with grouped sections (location, approvers, schedule, org chart)
/// - Edit mode: form fields with save button + unsaved changes warning on back
/// - Permission-aware edit button (only shown if `hasEditPermission`)
/// - Shimmer loading placeholder during initial fetch
/// - Back navigation with discard confirmation
/// - Organization chart visualization (if data available)
class WorkInfoPage extends StatefulWidget {
  final int employeeId;

  const WorkInfoPage({super.key, required this.employeeId});

  @override
  State<WorkInfoPage> createState() => _WorkInfoPageState();
}

class _WorkInfoPageState extends State<WorkInfoPage> {
  bool _hasDispatched = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Load data only once when dependencies (e.g. bloc) are ready
    if (!_hasDispatched) {
      _hasDispatched = true;
      context.read<WorkInfoBloc>().add(LoadWorkInfo(widget.employeeId));
    }
  }

  /// Helper to get translated string with fallback to key
  String catchTranslate(BuildContext context, String key) {
    final service = Provider.of<LanguageProvider>(context, listen: false);
    return service.getCached(key) ?? key;
  }

  /// Shows confirmation dialog before discarding unsaved changes
  Future<bool> _showUnsavedChangesDialog(context) async {
    final result = await DataLossWarningDialog.show(
      context: context,
      title: catchTranslate(context, 'Discard Changes?'),
      message: catchTranslate(
        context,
        'You have unsaved changes. Do you want to discard them?',
      ),
      confirmText: catchTranslate(context, 'Discard'),
      cancelText: catchTranslate(context, 'Keep Editing'),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final translationService = context.read<LanguageProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocBuilder<WorkInfoBloc, WorkInfoState>(
      builder: (context, state) {
        return WillPopScope(
          // Handle back button with unsaved changes check
          onWillPop: () async {
            if (!state.isEditing) {
              return true;
            } else if (state.isEditing && !state.hasChanges) {
              context.read<WorkInfoBloc>().add(CancelEdit());
            } else {
              final discard = await _showUnsavedChangesDialog(context);

              if (discard) {
                context.read<WorkInfoBloc>().add(CancelEdit());
              }
            }
            return false;
          },
          child: Scaffold(
            backgroundColor: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey[900]
                : Colors.grey[50],
            appBar: AppBar(
              backgroundColor: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey[900]
                  : Colors.grey[50],
              title: BlocBuilder<WorkInfoBloc, WorkInfoState>(
                builder: (context, state) {
                  return Text(
                    state.isEditing
                        ? catchTranslate(context, 'Edit Work Information')
                        : catchTranslate(context, 'Work Information'),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  );
                },
              ),
              leading: IconButton(
                icon: Icon(
                  HugeIcons.strokeRoundedArrowLeft01,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : Colors.black,
                  size: 28,
                ),
                onPressed: () async {
                  final state = context.read<WorkInfoBloc>().state;

                  if (!state.isEditing) {
                    Navigator.pop(context);
                  } else if (state.isEditing && !state.hasChanges) {
                    context.read<WorkInfoBloc>().add(CancelEdit());
                  } else {
                    final discard = await _showUnsavedChangesDialog(context);
                    if (discard) context.read<WorkInfoBloc>().add(CancelEdit());
                  }
                },
              ),
              actions: [
                BlocBuilder<WorkInfoBloc, WorkInfoState>(
                  builder: (context, state) {
                    if (state.hasEditPermission && !state.isEditing) {
                      return IconButton(
                        onPressed: () {
                          context.read<WorkInfoBloc>().add(ToggleEditMode());
                        },
                        tooltip: translationService.getCached('Edit Employee'),
                        icon: Icon(
                          HugeIcons.strokeRoundedPencilEdit02,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
            body: BlocConsumer<WorkInfoBloc, WorkInfoState>(
              listener: (context, state) {
                if (state.errorMessage != null) {
                  CustomSnackbar.showError(context, state.errorMessage!);
                }
                if (state.warningMessage != null) {
                  CustomSnackbar.showWarning(context, state.warningMessage!);
                }
                if (state.successMessage != null) {
                  CustomSnackbar.showSuccess(context, state.successMessage!);
                }
              },
              builder: (context, state) {
                if (state.isLoading) {
                  return _buildShimmer(context);
                }

                return Stack(
                  children: [
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Location Card (work address + location)
                          Container(
                            margin: const EdgeInsets.only(bottom: 24),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.grey[850] : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: isDark
                                      ? Colors.black.withOpacity(0.18)
                                      : Colors.black.withOpacity(0.06),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: _buildLocationSection(context, state),
                          ),
                          // Approvers Card (only in view mode)
                          if (!state.isEditing) ...[
                            Container(
                              margin: const EdgeInsets.only(bottom: 24),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.grey[850] : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: isDark
                                        ? Colors.black.withOpacity(0.18)
                                        : Colors.black.withOpacity(0.06),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: _buildApproversSection(context, state),
                            ),
                          ],
                          // Schedule Card (working hours + timezone)
                          Container(
                            margin: const EdgeInsets.only(bottom: 24),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.grey[850] : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: isDark
                                      ? Colors.black.withOpacity(0.18)
                                      : Colors.black.withOpacity(0.06),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: _buildScheduleSection(context, state),
                          ),
                          // Organization Chart (if available)
                          if (state.orgChartList != []) ...[
                            Container(
                              margin: const EdgeInsets.only(bottom: 24),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.grey[850] : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: isDark
                                        ? Colors.black.withOpacity(0.18)
                                        : Colors.black.withOpacity(0.06),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(20.0),
                                child: OrganizationChart(
                                  chain: state.orgChartList,
                                ),
                              ),
                            ),
                          ],
                          // Save Button (only in edit mode)
                          if (state.isEditing) ...[
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: (state.isSaving || !state.hasChanges)
                                    ? null
                                    : () {
                                        context.read<WorkInfoBloc>().add(
                                          SaveWorkInfo(),
                                        );
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isDark
                                      ? Colors.white
                                      : AppStyle.primaryColor,
                                  foregroundColor: isDark
                                      ? Colors.black
                                      : Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                    horizontal: 16,
                                  ),
                                  elevation: 0,
                                  shadowColor: Colors.transparent,
                                  disabledBackgroundColor: isDark
                                      ? Colors.grey[700]!
                                      : Colors.grey[400]!,
                                ),
                                child: tr(
                                  "Save Changes",
                                  style: TextStyle(
                                    color: isDark ? Colors.black : Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Loading overlay during save
                    if (state.isSaving)
                      Center(
                        child: LoadingAnimationWidget.fourRotatingDots(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : AppStyle.primaryColor,
                          size: 60,
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  /// Builds the Location section (work address dropdown + display, work location)
  Widget _buildLocationSection(BuildContext context, WorkInfoState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final street = getField(state.addressDetails, "street");
    final street2 = getField(state.addressDetails, "street2");
    final city = getField(state.addressDetails, "city");
    final zip = getField(state.addressDetails, "zip");
    final cityZip = "${city ?? ''} ${zip ?? ''}".trim();
    final country = getField(state.addressDetails, "country_id");
    final translationService = context.read<LanguageProvider>();

    if (state.isEditing)
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: tr(
              "Location",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.grey[900],
                letterSpacing: -0.3,
              ),
            ),
          ),
          Divider(
            height: 1,
            color: isDark ? Colors.grey[700] : Colors.grey[200],
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                tr(
                  'Work Address',
                  style: TextStyle(
                    fontWeight: FontWeight.w400,
                    color: isDark ? Colors.white70 : const Color(0xff7F7F7F),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: isDark
                        ? const Color(0xFF2A2A2A)
                        : const Color(0xFFF2F4F6),
                    border: Border.all(color: Colors.transparent, width: 1),
                  ),
                  child: DropdownSearch<Map<String, dynamic>>(
                    dropdownBuilder: (context, selectedItem) {
                      if (selectedItem == null) {
                        return Text(
                          "${translationService.getCached("Select")} ${translationService.getCached("Employee")}",
                          style: TextStyle(
                            fontWeight: FontWeight.w400,
                            color: isDark ? Colors.white54 : Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        );
                      }

                      return Text(
                        selectedItem['name'] ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? Colors.white70
                              : const Color(0xff000000),
                        ),
                      );
                    },

                    popupProps: PopupProps.menu(
                      showSearchBox: true,
                      menuProps: MenuProps(
                        backgroundColor: isDark
                            ? Colors.grey[900]
                            : Colors.grey[50],
                        elevation: 12,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      searchFieldProps: TextFieldProps(
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          errorBorder: InputBorder.none,
                          focusedErrorBorder: InputBorder.none,
                          hintText: "Search Employee",
                          hintStyle: TextStyle(
                            fontWeight: FontWeight.w400,
                            color: isDark ? Colors.white54 : Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    items: state.addressList,
                    itemAsString: (item) => item['name'] ?? '',
                    selectedItem: state.selectedAddressId == null
                        ? null
                        : state.addressList
                              .cast<Map<String, dynamic>?>()
                              .firstWhere(
                                (e) => e?['id'] == state.selectedAddressId,
                                orElse: () => null,
                              ),

                    onChanged: (value) async {
                      if (value?['id'] == null) {
                        context.read<WorkInfoBloc>().add(
                          UpdateSelectedAddressWithDetails(null, null),
                        );
                        return;
                      }
                      try {
                        await WorkInfoService().initializeClient();
                        final fullAddress = await WorkInfoService()
                            .loadFullAddress(value?['id']);

                        context.read<WorkInfoBloc>().add(
                          UpdateSelectedAddressWithDetails(
                            value?['id'],
                            fullAddress,
                          ),
                        );
                      } catch (e) {
                        context.read<WorkInfoBloc>().add(
                          UpdateSelectedAddressWithDetails(value?['id'], null),
                        );
                      }
                    },
                    dropdownDecoratorProps: DropDownDecoratorProps(
                      dropdownSearchDecoration: _dropdownDecoration(
                        context,
                        "Select Work Address",
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (street != null)
                        Text(street, style: _valueStyle(context)),
                      if (street2 != null)
                        Text(street2, style: _valueStyle(context)),
                      if (cityZip.isNotEmpty)
                        Text(cityZip, style: _valueStyle(context)),
                      if (country != null &&
                          country is List &&
                          country.length > 1)
                        Text(country[1], style: _valueStyle(context)),
                    ],
                  ),
                ),
                SizedBox(height: 12),
                tr(
                  'Work Location',
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                WorkInfoRow(
                  label: "Work Location",
                  value:
                      (state.employeeDetails?['work_location_id'] is List &&
                          (state.employeeDetails?['work_location_id'] as List)
                                  .length >
                              1)
                      ? state.employeeDetails!['work_location_id'][1]
                      : '',
                  isEditing: state.isEditing,
                  dropdownItems: state.locationList,
                  selectedId: state.selectedLocationId,
                  onDropdownChanged: (value) {
                    context.read<WorkInfoBloc>().add(
                      UpdateSelectedLocation(value?['id']),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      );
    else
      return Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            tr(
              "Location",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,

                  children: [
                    tr(
                      "Work Address",
                      style: TextStyle(
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Expanded(
                      child: formatFullAddress(state.addressDetails, isDark),
                    ),
                  ],
                ),
                SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    tr(
                      "Work Location",
                      style: TextStyle(
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      (state.employeeDetails?['work_location_id'] is List &&
                              (state.employeeDetails?['work_location_id']
                                          as List)
                                      .length >
                                  1)
                          ? state.employeeDetails!['work_location_id'][1]
                          : 'N/A',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontWeight: FontWeight.normal,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.end,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      );
  }

  /// Builds the Approvers section (attendance manager)
  Widget _buildApproversSection(BuildContext context, WorkInfoState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (state.isEditing)
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: tr(
              "Approvers",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.grey[900],
                letterSpacing: -0.3,
              ),
            ),
          ),
          Divider(
            height: 1,
            color: isDark ? Colors.grey[700] : Colors.grey[200],
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                tr(
                  'Attendance',
                  style: TextStyle(
                    fontWeight: FontWeight.w400,
                    color: isDark ? Colors.white70 : const Color(0xff7F7F7F),
                  ),
                ),
                const SizedBox(height: 8),
                WorkInfoRow(
                  label: "Attendance",
                  value:
                      (state.employeeDetails?['attendance_manager_id']
                              is List &&
                          (state.employeeDetails?['attendance_manager_id']
                                      as List)
                                  .length >
                              1)
                      ? state.employeeDetails!['attendance_manager_id'][1]
                      : 'N/A',
                  isEditing: state.isEditing,
                  dropdownItems: state.expenseList,
                  selectedId: state.selectedExpenseId,
                  onDropdownChanged: (value) {
                    context.read<WorkInfoBloc>().add(
                      UpdateSelectedExpense(value?['id']),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      );
    else
      return Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            tr(
              "Approvers",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                tr(
                  "Attendance",
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  (state.employeeDetails?['attendance_manager_id'] is List &&
                          (state.employeeDetails?['attendance_manager_id']
                                      as List)
                                  .length >
                              1)
                      ? state.employeeDetails!['attendance_manager_id'][1]
                      : 'N/A',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontWeight: FontWeight.normal,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.end,
                ),
              ],
            ),
          ],
        ),
      );
  }

  /// Builds the Schedule section (working hours + timezone)
  Widget _buildScheduleSection(BuildContext context, WorkInfoState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (state.isEditing) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: tr(
              "Schedule",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.grey[900],
                letterSpacing: -0.3,
              ),
            ),
          ),
          Divider(
            height: 1,
            color: isDark ? Colors.grey[700] : Colors.grey[200],
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                tr(
                  'Working Hours',
                  style: TextStyle(
                    fontWeight: FontWeight.w400,
                    color: isDark ? Colors.white70 : const Color(0xff7F7F7F),
                  ),
                ),
                const SizedBox(height: 8),
                WorkInfoRow(
                  label: "Working Hours",
                  value:
                      (state.employeeDetails?['resource_calendar_id'] is List &&
                          (state.employeeDetails?['resource_calendar_id']
                                      as List)
                                  .length >
                              1)
                      ? state.employeeDetails!['resource_calendar_id'][1]
                      : 'N/A',
                  isEditing: state.isEditing,
                  dropdownItems: state.workingHoursList,
                  selectedId: state.selectedWorkingHoursId,
                  onDropdownChanged: (value) {
                    context.read<WorkInfoBloc>().add(
                      UpdateSelectedWorkingHours(value?['id']),
                    );
                  },
                ),
                SizedBox(height: 12),
                tr(
                  'Timezone',
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                WorkInfoRow(
                  label: "Timezone",
                  value: state.employeeDetails?['tz'] ?? 'N/A',
                  isEditing: state.isEditing,
                  dropdownItems: state.timeZoneList,
                  selectedKey: state.selectedTzId,
                  onDropdownChanged: (value) {
                    final selected = state.timeZoneList.firstWhere(
                      (tz) => tz['name'] == value?['name'],
                      orElse: () => {'code': 'UTC'},
                    );
                    context.read<WorkInfoBloc>().add(
                      UpdateSelectedTimezone(selected['code']),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      );
    } else {
      return Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            tr(
              "Schedule",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,

                  children: [
                    tr(
                      "Working Hours",
                      style: TextStyle(
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      (state.employeeDetails?['resource_calendar_id'] is List &&
                              (state.employeeDetails?['resource_calendar_id']
                                          as List)
                                      .length >
                                  1)
                          ? state.employeeDetails!['resource_calendar_id'][1]
                          : 'N/A',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontWeight: FontWeight.normal,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.end,
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    tr(
                      "Timezone",
                      style: TextStyle(
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      state.employeeDetails?['tz'] ?? 'N/A',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontWeight: FontWeight.normal,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.end,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      );
    }
  }

  /// Reusable input decoration for dropdowns (consistent styling)
  InputDecoration _dropdownDecoration(BuildContext context, String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InputDecoration(
      hintText: label,
      hintStyle: TextStyle(
        fontWeight: FontWeight.w400,
        color: isDark ? Colors.white54 : Colors.grey[600],
        fontStyle: FontStyle.italic,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.transparent, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: isDark ? Colors.white : AppStyle.primaryColor,
          width: 2,
        ),
      ),
    );
  }

  /// Text style for address lines in edit mode
  TextStyle _valueStyle(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: isDark ? Colors.white70 : Colors.black,
    );
  }

  /// Full-screen shimmer placeholder that mimics the layout of the page
  Widget _buildShimmer(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _shimmerBox(height: 18, width: 120, isDark: isDark),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _shimmerBox(height: 14, width: 180, isDark: isDark),
                const SizedBox(height: 10),
                _shimmerBox(height: 14, width: double.infinity, isDark: isDark),
                const SizedBox(height: 6),
                _shimmerBox(height: 14, width: double.infinity, isDark: isDark),
                const SizedBox(height: 6),
                _shimmerBox(height: 14, width: 150, isDark: isDark),
              ],
            ),
          ),
          const SizedBox(height: 30),
          _shimmerBox(height: 18, width: 140, isDark: isDark),
          const SizedBox(height: 10),
          _shimmerBox(height: 46, width: double.infinity, isDark: isDark),
          const SizedBox(height: 30),
          _shimmerBox(height: 18, width: 110, isDark: isDark),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _shimmerBox(height: 18, width: 140, isDark: isDark),
                const SizedBox(height: 10),
                _shimmerBox(height: 46, isDark: isDark),
              ],
            ),
          ),
          const SizedBox(height: 30),
          _shimmerBox(height: 18, width: 110, isDark: isDark),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _shimmerBox(height: 18, width: 160, isDark: isDark),
                const SizedBox(height: 10),
                _shimmerBox(height: 46, isDark: isDark),
                const SizedBox(height: 16),
                _shimmerBox(height: 18, width: 100, isDark: isDark),
                const SizedBox(height: 10),
                _shimmerBox(height: 46, isDark: isDark),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _shimmerBox(height: 200, width: double.infinity, isDark: isDark),
        ],
      ),
    );
  }

  /// Reusable shimmering rectangle placeholder
  Widget _shimmerBox({
    required double height,
    double? width,
    required bool isDark,
  }) {
    final baseColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = isDark ? Colors.grey[700]! : Colors.grey[100]!;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    );
  }

  /// Formats full work address from address details map (multi-line, right-aligned)
  Widget formatFullAddress(Map<String, dynamic>? address, bool isDark) {
    if (address == null)
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          tr(
            "N/A",
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontWeight: FontWeight.normal,
              fontSize: 14,
            ),
            textAlign: TextAlign.end,
          ),
        ],
      );

    final name = address['name'] ?? "";
    final street = getField(address, "street") ?? "";
    final street2 = getField(address, "street2") ?? "";
    final cityZip =
        "${getField(address, "city") ?? ""} ${getField(address, "zip") ?? ""}"
            .trim();
    final country = getField(address, "country_id");
    final countryName = (country is List && country.length > 1)
        ? country[1]
        : "";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (name.isNotEmpty) ...[_addressText(name, isDark), SizedBox(height: 5)],
        if (street.isNotEmpty) ...[
          _addressText(street, isDark),
          SizedBox(height: 5),
        ],
        if (street2.isNotEmpty) ...[
          _addressText(street2, isDark),
          SizedBox(height: 5),
        ],
        if (cityZip.isNotEmpty) ...[
          _addressText(cityZip, isDark),
          SizedBox(height: 5),
        ],
        if (countryName.isNotEmpty) _addressText(countryName, isDark),
      ],
    );
  }

  /// Helper text widget for address lines
  Widget _addressText(String text, bool isDark) {
    return Text(
      text,
      style: TextStyle(
        color: isDark ? Colors.white : Colors.black,
        fontWeight: FontWeight.normal,
        fontSize: 14,
      ),
      textAlign: TextAlign.end,
    );
  }

  /// Safe field extractor (handles null/false → null)
  dynamic getField(Map<String, dynamic>? data, String key) {
    if (data == null) return null;
    final value = data[key];
    if (value == null || value == false) return null;
    return value;
  }
}
