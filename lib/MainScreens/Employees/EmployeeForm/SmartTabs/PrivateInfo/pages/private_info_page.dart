import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../../../CommonWidgets/core/language/translate_widget.dart';
import '../../../../../../CommonWidgets/core/navigation/data_loss_warning_dialog.dart';
import '../../../../../../CommonWidgets/core/providers/language_provider.dart';
import '../../../../../../CommonWidgets/globals.dart';
import '../../../../../../CommonWidgets/shared/widgets/snackbar.dart';
import '../bloc/private_info_bloc.dart';
import '../bloc/private_info_event.dart';
import '../bloc/private_info_state.dart';
import '../widgets/private_info_row.dart';

/// Full-screen page for viewing and editing an employee's **private/personal information**.
///
/// Features:
/// - View mode: clean read-only display with grouped sections (address, contact, citizenship, family, education, work permit)
/// - Edit mode: form fields with save button + unsaved changes warning on back
/// - File upload for work permit document (PDF/image → base64)
/// - Permission-aware editing (assumed via bloc state)
/// - Shimmer loading placeholder during initial fetch
/// - Back navigation with discard confirmation
class PrivateInfoPage extends StatefulWidget {
  final int employeeId;

  const PrivateInfoPage({super.key, required this.employeeId});

  @override
  State<PrivateInfoPage> createState() => _PrivateInfoPageState();
}

class _PrivateInfoPageState extends State<PrivateInfoPage> {
  bool _hasLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Load data only once when dependencies (e.g. bloc) are ready
    if (!_hasLoaded) {
      _hasLoaded = true;
      context.read<PrivateInfoBloc>().add(LoadPrivateInfo(widget.employeeId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return PrivateInfoView(employeeId: widget.employeeId);
  }
}

/// Stateless view widget that renders the actual UI based on [PrivateInfoState].
///
/// Handles:
/// - Loading shimmer
/// - Edit vs view mode switching
/// - Section cards (Private Contact, Citizenship, Family Status, Education, Work Permit)
/// - File upload/delete for work permit
/// - Save button + loading overlay
/// - Snackbars for success/error/warning messages
class PrivateInfoView extends StatelessWidget {
  final int employeeId;

  const PrivateInfoView({super.key, required this.employeeId});

  /// Opens file picker and uploads selected work permit document as base64.
  Future<void> _pickAndUploadWorkPermit(BuildContext context) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: true,
    );

    if (result == null || result.files.single.bytes == null) {
      return;
    }

    Uint8List fileBytes = result.files.single.bytes!;
    String base64File = base64Encode(fileBytes);

    context.read<PrivateInfoBloc>().add(
      UploadWorkPermit(employeeId, fileBytes, base64File),
    );
  }

  /// Returns a full-screen shimmer placeholder that mimics the layout of the page.
  Widget _shimmerPlaceholder(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(
          8,
          (_) => const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBox(height: 18, width: 140),
                SizedBox(height: 16),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      ShimmerBox(height: 14, width: double.infinity),
                      SizedBox(height: 8),
                      ShimmerBox(height: 14, width: double.infinity),
                      SizedBox(height: 8),
                      ShimmerBox(height: 14, width: 200),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the editable address section (street, city, state, country)
  Widget _buildAddressEditSection(
    BuildContext context,
    PrivateInfoState state,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        tr(
          'Street',
          style: TextStyle(
            fontWeight: FontWeight.w400,
            color: isDark ? Colors.white70 : const Color(0xff7F7F7F),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF2F4F6),
            border: Border.all(color: Colors.transparent, width: 1),
          ),
          child: TextFormField(
            decoration: _inputDecoration('Enter Street', isDark, context),
            controller: state.privateStreetController,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : const Color(0xff000000),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            tr(
              'Street 2',
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
              child: TextFormField(
                decoration: _inputDecoration('Enter Street 2', isDark, context),
                controller: state.privateStreet2Controller,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : const Color(0xff000000),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            tr(
              'City',
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
              child: TextFormField(
                decoration: _inputDecoration('Enter City', isDark, context),
                controller: state.privateCityController,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : const Color(0xff000000),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            tr(
              'State',
              style: TextStyle(
                fontWeight: FontWeight.w400,
                color: isDark ? Colors.white70 : const Color(0xff7F7F7F),
              ),
            ),
            const SizedBox(height: 8),
            PrivateInfoRow(
              label: "State",
              value: (() {
                if (state.selectedPrivateStateId == null) return 'N/A';
                final country = state.states.firstWhere(
                  (c) => c['id'] == state.selectedPrivateStateId,
                  orElse: () => {},
                );
                return country?['name'] ?? 'N/A';
              })(),
              isEditing: state.isEditing,
              dropdownItems: state.states,
              selectedId: state.selectedPrivateStateId,
              onDropdownChanged: (val) {
                FocusScope.of(context).requestFocus(state.dropdownFocusNode);

                context.read<PrivateInfoBloc>().add(
                  UpdateField('privateState', val?['id']),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            tr(
              'Country',
              style: TextStyle(
                fontWeight: FontWeight.w400,
                color: isDark ? Colors.white70 : const Color(0xff7F7F7F),
              ),
            ),
            const SizedBox(height: 8),
            PrivateInfoRow(
              label: "Country",
              value: (() {
                if (state.selectedPrivateCountryId == null) return 'N/A';
                final country = state.countries.firstWhere(
                  (c) => c['id'] == state.selectedPrivateCountryId,
                  orElse: () => {},
                );
                return country?['name'] ?? 'N/A';
              })(),
              isEditing: state.isEditing,
              dropdownItems: state.countries,
              selectedId: state.selectedPrivateCountryId,
              onDropdownChanged: (val) {
                FocusScope.of(context).requestFocus(state.dropdownFocusNode);

                context.read<PrivateInfoBloc>().add(
                  UpdateField('privateCountry', val?['id']),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  /// Reusable input decoration for text fields (consistent styling)
  InputDecoration _inputDecoration(
    String label,
    bool isDark,
    BuildContext context,
  ) {
    final translationService = Provider.of<LanguageProvider>(
      context,
      listen: false,
    );

    return InputDecoration(
      errorBorder: InputBorder.none,
      focusedErrorBorder: InputBorder.none,
      hintText: translationService.getCached(label),
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

  /// Formats full private address from details map (multi-line, right-aligned)
  Widget _formatFullAddress(Map<String, dynamic>? details, bool isDark) {
    if (details == null) return const Text('N/A', textAlign: TextAlign.right);

    final street = _safe(details['private_street']);
    final street2 = _safe(details['private_street2']);
    final city = _safe(details['private_city']);

    final state =
        (details['private_state_id'] is List &&
            details['private_state_id'].length > 1)
        ? _safe(details['private_state_id'][1])
        : '';

    final country =
        (details['private_country_id'] is List &&
            details['private_country_id'].length > 1)
        ? _safe(details['private_country_id'][1])
        : '';

    final parts = [
      street,
      street2,
      city,
      state,
      country,
    ].where((e) => e.isNotEmpty).toList();

    if (parts.isEmpty) return const Text('N/A', textAlign: TextAlign.right);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: parts.map((part) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text(
            part,
            softWrap: true,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontWeight: FontWeight.normal,
            ),
          ),
        );
      }).toList(),
    );
  }

  /// Safe string extraction (handles null/false → empty string)
  String _safe(dynamic v) {
    if (v == null || v == false) return '';
    return v.toString().trim();
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

  /// Handles back navigation with unsaved changes check
  Future<bool> _handleBack(BuildContext context) async {
    final bloc = context.read<PrivateInfoBloc>();
    final state = bloc.state;

    if (!state.isEditing) {
      return true;
    } else {
      final discard = await _showUnsavedChangesDialog(context);
      if (discard) bloc.add(CancelEdit());
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return WillPopScope(
      onWillPop: () => _handleBack(context),
      child: Scaffold(
        backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
        appBar: AppBar(
          backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
          title: BlocBuilder<PrivateInfoBloc, PrivateInfoState>(
            builder: (context, state) {
              return Text(
                state.isEditing
                    ? catchTranslate(context, 'Edit Private Info')
                    : catchTranslate(context, 'Private Information'),
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
              color: isDark ? Colors.white : Colors.black,
              size: 28,
            ),
            onPressed: () async {
              final state = context.read<PrivateInfoBloc>().state;

              if (!state.isEditing) {
                Navigator.pop(context);
              } else {
                final discard = await _showUnsavedChangesDialog(context);
                if (discard) context.read<PrivateInfoBloc>().add(CancelEdit());
              }
            },
          ),
          actions: [
            BlocBuilder<PrivateInfoBloc, PrivateInfoState>(
              builder: (context, state) {
                if (!state.isEditing) {
                  return IconButton(
                    onPressed: () =>
                        context.read<PrivateInfoBloc>().add(ToggleEditMode()),
                    tooltip: 'Edit',
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
        body: BlocConsumer<PrivateInfoBloc, PrivateInfoState>(
          listener: (context, state) {
            if (state.showError && state.errorMessage != null) {
              CustomSnackbar.showError(context, state.errorMessage!);
              context.read<PrivateInfoBloc>().emit(
                state.copyWith(showError: false, errorMessage: null),
              );
            }
            if (state.showWarning && state.warningMessage != null) {
              CustomSnackbar.showWarning(context, state.warningMessage!);
              context.read<PrivateInfoBloc>().emit(
                state.copyWith(showWarning: false, errorMessage: null),
              );
            }
            if (state.showSuccess && state.successMessage != null) {
              CustomSnackbar.showSuccess(context, state.successMessage!);
              context.read<PrivateInfoBloc>().emit(
                state.copyWith(showSuccess: false, errorMessage: null),
              );
            }
          },
          builder: (context, state) {
            if (state.isLoading || state.employeeDetails == null) {
              return _shimmerPlaceholder(isDark);
            }

            final details = state.employeeDetails;
            if (state.isEditing) {
              return Stack(
                children: [
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                          child: Column(
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
                                  "Private Contact",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.white
                                        : Colors.grey[900],
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ),
                              Divider(
                                height: 1,
                                color: isDark
                                    ? Colors.grey[700]
                                    : Colors.grey[200],
                              ),
                              Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildAddressEditSection(
                                      context,
                                      state,
                                      isDark,
                                    ),
                                    const SizedBox(height: 12),

                                    tr(
                                      'Email',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w400,
                                        color: isDark
                                            ? Colors.white70
                                            : const Color(0xff7F7F7F),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    PrivateInfoRow(
                                      label: "Email",
                                      value:
                                          (state
                                                  .privateEmailController
                                                  .text
                                                  ?.isNotEmpty ??
                                              false)
                                          ? state.privateEmailController.text
                                          : 'N/A',
                                      isEditing: state.isEditing,
                                      controller: state.privateEmailController,
                                    ),

                                    const SizedBox(height: 12),

                                    tr(
                                      'Phone',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w400,
                                        color: isDark
                                            ? Colors.white70
                                            : const Color(0xff7F7F7F),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    PrivateInfoRow(
                                      label: "Phone",
                                      value:
                                          (state
                                                  .privatePhoneController
                                                  .text
                                                  ?.isNotEmpty ??
                                              false)
                                          ? state.privatePhoneController.text
                                          : 'N/A',
                                      isEditing: state.isEditing,
                                      controller: state.privatePhoneController,
                                    ),

                                    const SizedBox(height: 12),

                                    tr(
                                      'Bank Account Number',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w400,
                                        color: isDark
                                            ? Colors.white70
                                            : const Color(0xff7F7F7F),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    PrivateInfoRow(
                                      label: "Bank Account Number",
                                      value:
                                          (details!['bank_account_id']
                                                  is List &&
                                              details!['bank_account_id']
                                                      .length >
                                                  1)
                                          ? details!['bank_account_id'][1]
                                          : 'N/A',
                                      isEditing: state.isEditing,
                                      dropdownItems: state.banks,
                                      selectedId: state.selectedPrivateBankId,
                                      onDropdownChanged: (val) {
                                        FocusScope.of(
                                          context,
                                        ).requestFocus(state.dropdownFocusNode);
                                        context.read<PrivateInfoBloc>().add(
                                          UpdateField(
                                            'privateBank',
                                            val?['id'],
                                          ),
                                        );
                                      },
                                    ),

                                    const SizedBox(height: 12),

                                    tr(
                                      'Language',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w400,
                                        color: isDark
                                            ? Colors.white70
                                            : const Color(0xff7F7F7F),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    PrivateInfoRow(
                                      label: "Language",
                                      value: (() {
                                        final langCode = details['lang'];
                                        final lang = state.languages.firstWhere(
                                          (l) => l['code'] == langCode,
                                          orElse: () => {'name': 'N/A'},
                                        );
                                        return lang['name'];
                                      })(),
                                      isEditing: state.isEditing,
                                      language: state.languages,
                                      selectedKey: state.selectedPrivateLangId,
                                      onSelectionChanged: (code) {
                                        FocusScope.of(
                                          context,
                                        ).requestFocus(state.dropdownFocusNode);
                                        context.read<PrivateInfoBloc>().add(
                                          UpdateField('privateLang', code),
                                        );
                                      },
                                    ),

                                    const SizedBox(height: 12),

                                    tr(
                                      'Home-Work Distance',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w400,
                                        color: isDark
                                            ? Colors.white70
                                            : const Color(0xff7F7F7F),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    PrivateInfoRow(
                                      label: "Home-Work Distance",
                                      value:
                                          (state
                                                  .kmHomeWorkController
                                                  .text
                                                  ?.isNotEmpty ??
                                              false)
                                          ? state.kmHomeWorkController.text
                                          : '0',
                                      isEditing: state.isEditing,
                                      isNumberInput: true,
                                      controller: state.kmHomeWorkController,
                                    ),

                                    const SizedBox(height: 12),

                                    tr(
                                      'Private Car Plate',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w400,
                                        color: isDark
                                            ? Colors.white70
                                            : const Color(0xff7F7F7F),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    PrivateInfoRow(
                                      label: "Private Car Plate",
                                      value:
                                          (state
                                                  .privateCarPlateController
                                                  .text
                                                  ?.isNotEmpty ??
                                              false)
                                          ? state.privateCarPlateController.text
                                          : 'N/A',
                                      isEditing: state.isEditing,
                                      controller:
                                          state.privateCarPlateController,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
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
                          child: Column(
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
                                  "Citizenship",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.white
                                        : Colors.grey[900],
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ),
                              Divider(
                                height: 1,
                                color: isDark
                                    ? Colors.grey[700]
                                    : Colors.grey[200],
                              ),
                              Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    tr(
                                      'Nationality (Country)',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w400,
                                        color: isDark
                                            ? Colors.white70
                                            : const Color(0xff7F7F7F),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    PrivateInfoRow(
                                      label: "Nationality (Country)",
                                      value:
                                          (details['country_id'] is List &&
                                              details['country_id'].length > 1)
                                          ? details['country_id'][1]
                                          : 'N/A',
                                      isEditing: state.isEditing,
                                      dropdownItems: state.countries,
                                      selectedId: state.selectedCountryId,
                                      onDropdownChanged: (val) {
                                        FocusScope.of(
                                          context,
                                        ).requestFocus(state.dropdownFocusNode);
                                        context.read<PrivateInfoBloc>().add(
                                          UpdateField('country', val?['id']),
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 12),

                                    tr(
                                      'Identification No',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w400,
                                        color: isDark
                                            ? Colors.white70
                                            : const Color(0xff7F7F7F),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    PrivateInfoRow(
                                      label: "Identification No",
                                      value:
                                          (state
                                                  .identificationIdController
                                                  .text
                                                  ?.isNotEmpty ??
                                              false)
                                          ? state
                                                .identificationIdController
                                                .text
                                          : 'N/A',
                                      isEditing: state.isEditing,
                                      controller:
                                          state.identificationIdController,
                                    ),

                                    const SizedBox(height: 12),

                                    tr(
                                      'SSN No',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w400,
                                        color: isDark
                                            ? Colors.white70
                                            : const Color(0xff7F7F7F),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    PrivateInfoRow(
                                      label: "SSN No",
                                      value:
                                          (state
                                                  .ssnIdController
                                                  .text
                                                  ?.isNotEmpty ??
                                              false)
                                          ? state.ssnIdController.text
                                          : 'N/A',
                                      isEditing: state.isEditing,
                                      controller: state.ssnIdController,
                                    ),

                                    const SizedBox(height: 12),

                                    tr(
                                      'Passport No',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w400,
                                        color: isDark
                                            ? Colors.white70
                                            : const Color(0xff7F7F7F),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    PrivateInfoRow(
                                      label: "Passport No",
                                      value:
                                          (state
                                                  .passportIdController
                                                  .text
                                                  ?.isNotEmpty ??
                                              false)
                                          ? state.passportIdController.text
                                          : 'N/A',
                                      isEditing: state.isEditing,
                                      controller: state.passportIdController,
                                    ),

                                    const SizedBox(height: 12),

                                    tr(
                                      'Date of Birth',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w400,
                                        color: isDark
                                            ? Colors.white70
                                            : const Color(0xff7F7F7F),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    PrivateInfoRow(
                                      label: "Date of Birth",
                                      value:
                                          (state
                                                  .birthdayController
                                                  .text
                                                  ?.isNotEmpty ??
                                              false)
                                          ? state.birthdayController.text
                                          : 'N/A',
                                      isEditing: state.isEditing,
                                      isDateInput: true,
                                      controller: state.birthdayController,
                                    ),

                                    const SizedBox(height: 12),

                                    tr(
                                      'Gender',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w400,
                                        color: isDark
                                            ? Colors.white70
                                            : const Color(0xff7F7F7F),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    PrivateInfoRow(
                                      label: "Gender",
                                      value: (() {
                                        final g = details['gender'];
                                        return {
                                              'male': 'Male',
                                              'female': 'Female',
                                              'other': 'Other',
                                            }[g] ??
                                            'N/A';
                                      })(),
                                      isEditing: state.isEditing,
                                      selection: const [
                                        {"id": "male", "name": "Male"},
                                        {"id": "female", "name": "Female"},
                                        {"id": "other", "name": "Other"},
                                      ],
                                      selectedKey: state.selectedGender,
                                      onSelectionChanged: (val) {
                                        FocusScope.of(
                                          context,
                                        ).requestFocus(state.dropdownFocusNode);
                                        context.read<PrivateInfoBloc>().add(
                                          UpdateField('gender', val),
                                        );
                                      },
                                    ),

                                    const SizedBox(height: 12),

                                    tr(
                                      'Place of Birth',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w400,
                                        color: isDark
                                            ? Colors.white70
                                            : const Color(0xff7F7F7F),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    PrivateInfoRow(
                                      label: "Place of Birth",
                                      value:
                                          (state
                                                  .placeOfBirthController
                                                  .text
                                                  ?.isNotEmpty ??
                                              false)
                                          ? state.placeOfBirthController.text
                                          : 'N/A',
                                      isEditing: state.isEditing,
                                      controller: state.placeOfBirthController,
                                    ),

                                    const SizedBox(height: 12),

                                    tr(
                                      'Country of Birth',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w400,
                                        color: isDark
                                            ? Colors.white70
                                            : const Color(0xff7F7F7F),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    PrivateInfoRow(
                                      label: "Country of Birth",
                                      value:
                                          (details['country_of_birth']
                                                  is List &&
                                              details['country_of_birth']
                                                      .length >
                                                  1)
                                          ? details['country_of_birth'][1]
                                          : 'N/A',
                                      isEditing: state.isEditing,
                                      dropdownItems: state.countries,
                                      selectedId: state.selectedBirthCountryId,
                                      onDropdownChanged: (val) {
                                        FocusScope.of(
                                          context,
                                        ).requestFocus(state.dropdownFocusNode);
                                        context.read<PrivateInfoBloc>().add(
                                          UpdateField(
                                            'birthCountry',
                                            val?['id'],
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
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
                          child: Column(
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
                                  "Family Status",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.white
                                        : Colors.grey[900],
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ),
                              Divider(
                                height: 1,
                                color: isDark
                                    ? Colors.grey[700]
                                    : Colors.grey[200],
                              ),
                              Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    tr(
                                      'Marital Status',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w400,
                                        color: isDark
                                            ? Colors.white70
                                            : const Color(0xff7F7F7F),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    PrivateInfoRow(
                                      label: "Marital Status",
                                      value: (() {
                                        final m = details['marital'];
                                        return {
                                              'single': 'Single',
                                              'married': 'Married',
                                              'cohabitant': 'Legal Cohabitant',
                                              'widower': 'Widower',
                                              'divorced': 'Divorced',
                                            }[m] ??
                                            'N/A';
                                      })(),
                                      isEditing: state.isEditing,
                                      selection: const [
                                        {"id": "single", "name": "Single"},
                                        {"id": "married", "name": "Married"},
                                        {
                                          "id": "cohabitant",
                                          "name": "Legal Cohabitant",
                                        },
                                        {"id": "widower", "name": "Widower"},
                                        {"id": "divorced", "name": "Divorced"},
                                      ],
                                      selectedKey: state.selectedMarital,
                                      onSelectionChanged: (val) {
                                        FocusScope.of(
                                          context,
                                        ).requestFocus(state.dropdownFocusNode);
                                        context.read<PrivateInfoBloc>().add(
                                          UpdateField('marital', val),
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 12),

                                    tr(
                                      'Spouse Complete Name',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w400,
                                        color: isDark
                                            ? Colors.white70
                                            : const Color(0xff7F7F7F),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    PrivateInfoRow(
                                      label: "Spouse Complete Name",
                                      value:
                                          (state
                                                  .spouseNameController
                                                  .text
                                                  ?.isNotEmpty ??
                                              false)
                                          ? state.spouseNameController.text
                                          : 'N/A',
                                      isEditing: state.isEditing,
                                      controller: state.spouseNameController,
                                    ),

                                    const SizedBox(height: 12),

                                    tr(
                                      'Spouse Birthdate',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w400,
                                        color: isDark
                                            ? Colors.white70
                                            : const Color(0xff7F7F7F),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    PrivateInfoRow(
                                      label: "Spouse Birthdate",
                                      value:
                                          (state
                                                  .spouseBirthdayController
                                                  .text
                                                  ?.isNotEmpty ??
                                              false)
                                          ? state.spouseBirthdayController.text
                                          : 'N/A',
                                      isEditing: state.isEditing,
                                      isDateInput: true,
                                      controller:
                                          state.spouseBirthdayController,
                                    ),

                                    const SizedBox(height: 12),

                                    tr(
                                      'Number of Dependent Children',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w400,
                                        color: isDark
                                            ? Colors.white70
                                            : const Color(0xff7F7F7F),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    PrivateInfoRow(
                                      label: "Number of Dependent Children",
                                      value:
                                          (state
                                                  .childrenController
                                                  .text
                                                  ?.isNotEmpty ??
                                              false)
                                          ? state.childrenController.text
                                          : 'N/A',
                                      isEditing: state.isEditing,
                                      isNumberInput: true,
                                      isKmInclude: false,
                                      controller: state.childrenController,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
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
                          child: Column(
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
                                  "Education",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.white
                                        : Colors.grey[900],
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ),
                              Divider(
                                height: 1,
                                color: isDark
                                    ? Colors.grey[700]
                                    : Colors.grey[200],
                              ),
                              Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    tr(
                                      'Certificate Level',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w400,
                                        color: isDark
                                            ? Colors.white70
                                            : const Color(0xff7F7F7F),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    PrivateInfoRow(
                                      label: "Certificate Level",
                                      value: (() {
                                        final c = details['certificate'];
                                        return {
                                              'graduate': 'Graduate',
                                              'bachelor': 'Bachelor',
                                              'master': 'Master',
                                              'doctor': 'Doctor',
                                              'other': 'Other',
                                            }[c] ??
                                            'N/A';
                                      })(),
                                      isEditing: state.isEditing,
                                      selection: const [
                                        {"id": "graduate", "name": "Graduate"},
                                        {"id": "bachelor", "name": "Bachelor"},
                                        {"id": "master", "name": "Master"},
                                        {"id": "doctor", "name": "Doctor"},
                                        {"id": "other", "name": "Other"},
                                      ],
                                      selectedKey: state.selectedCertificate,
                                      onSelectionChanged: (val) {
                                        FocusScope.of(
                                          context,
                                        ).requestFocus(state.dropdownFocusNode);
                                        context.read<PrivateInfoBloc>().add(
                                          UpdateField('certificate', val),
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 12),

                                    tr(
                                      'Field of Study',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w400,
                                        color: isDark
                                            ? Colors.white70
                                            : const Color(0xff7F7F7F),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    PrivateInfoRow(
                                      label: "Field of Study",
                                      value:
                                          (state
                                                  .studyFieldController
                                                  .text
                                                  ?.isNotEmpty ??
                                              false)
                                          ? state.studyFieldController.text
                                          : 'N/A',
                                      isEditing: state.isEditing,
                                      controller: state.studyFieldController,
                                    ),

                                    const SizedBox(height: 12),

                                    tr(
                                      'School',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w400,
                                        color: isDark
                                            ? Colors.white70
                                            : const Color(0xff7F7F7F),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    PrivateInfoRow(
                                      label: "School",
                                      value:
                                          (state
                                                  .studySchoolController
                                                  .text
                                                  ?.isNotEmpty ??
                                              false)
                                          ? state.studySchoolController.text
                                          : 'N/A',
                                      isEditing: state.isEditing,
                                      controller: state.studySchoolController,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
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
                          child: Column(
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
                                  "Work Permit",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.white
                                        : Colors.grey[900],
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ),
                              Divider(
                                height: 1,
                                color: isDark
                                    ? Colors.grey[700]
                                    : Colors.grey[200],
                              ),
                              Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    tr(
                                      'Visa No',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w400,
                                        color: isDark
                                            ? Colors.white70
                                            : const Color(0xff7F7F7F),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    PrivateInfoRow(
                                      label: "Visa No",
                                      value:
                                          (state
                                                  .visaNoController
                                                  .text
                                                  ?.isNotEmpty ??
                                              false)
                                          ? state.visaNoController.text
                                          : 'N/A',
                                      isEditing: state.isEditing,
                                      controller: state.visaNoController,
                                    ),
                                    const SizedBox(height: 12),

                                    tr(
                                      'Work Permit No',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w400,
                                        color: isDark
                                            ? Colors.white70
                                            : const Color(0xff7F7F7F),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    PrivateInfoRow(
                                      label: "Work Permit No",
                                      value:
                                          (state
                                                  .permitNoController
                                                  .text
                                                  ?.isNotEmpty ??
                                              false)
                                          ? state.permitNoController.text
                                          : 'N/A',
                                      isEditing: state.isEditing,
                                      controller: state.permitNoController,
                                    ),

                                    const SizedBox(height: 12),

                                    tr(
                                      'Visa Expiration Date',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w400,
                                        color: isDark
                                            ? Colors.white70
                                            : const Color(0xff7F7F7F),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    PrivateInfoRow(
                                      label: "Visa Expiration Date",
                                      value:
                                          (state
                                                  .visaExpireController
                                                  .text
                                                  ?.isNotEmpty ??
                                              false)
                                          ? state.visaExpireController.text
                                          : 'N/A',
                                      isEditing: state.isEditing,
                                      isDateInput: true,
                                      controller: state.visaExpireController,
                                    ),

                                    const SizedBox(height: 12),

                                    tr(
                                      'Work Permit Expiration Date',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w400,
                                        color: isDark
                                            ? Colors.white70
                                            : const Color(0xff7F7F7F),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    PrivateInfoRow(
                                      label: "Work Permit Expiration Date",
                                      value:
                                          (state
                                                  .workPermitExpireController
                                                  .text
                                                  ?.isNotEmpty ??
                                              false)
                                          ? state
                                                .workPermitExpireController
                                                .text
                                          : 'N/A',
                                      isEditing: state.isEditing,
                                      isDateInput: true,
                                      controller:
                                          state.workPermitExpireController,
                                    ),

                                    const SizedBox(height: 12),
                                    tr(
                                      'Work Permit',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w400,
                                        color: isDark
                                            ? Colors.white70
                                            : const Color(0xff7F7F7F),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    PrivateInfoRow(
                                      label: "Work Permit",
                                      value: state.workPermitBytes != null
                                          ? "Yes"
                                          : "No",
                                      isEditing: state.isEditing,
                                      isFileInput: true,

                                      fileBytes: state.workPermitBytes,
                                      employeeName:
                                          details['name'] ?? 'Employee',
                                      onFileUpload: () =>
                                          _pickAndUploadWorkPermit(context),
                                      onFileDelete: () => context
                                          .read<PrivateInfoBloc>()
                                          .add(DeleteWorkPermit(employeeId)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: (state.isSaving)
                                ? null
                                : () => context.read<PrivateInfoBloc>().add(
                                    SavePrivateInfo(employeeId),
                                  ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark
                                  ? Colors.white
                                  : AppStyle.primaryColor,
                              foregroundColor: isDark
                                  ? Colors.black
                                  :Colors.white,
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
                    ),
                  ),
                  if (state.isSaving)
                    Center(
                      child: LoadingAnimationWidget.fourRotatingDots(
                        color: isDark ? Colors.white : AppStyle.primaryColor,
                        size: 60,
                      ),
                    ),
                ],
              );
            } else {
              return Stack(
                children: [
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                tr(
                                  "Private Contact",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF1A1A1A),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        tr(
                                          "Private Address",
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.grey[400]
                                                : Colors.grey[600],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Expanded(
                                          child: _formatFullAddress(
                                            details,
                                            isDark,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        tr(
                                          "Email",
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.grey[400]
                                                : Colors.grey[600],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            (state
                                                        .privateEmailController
                                                        .text
                                                        ?.isNotEmpty ??
                                                    false)
                                                ? state
                                                      .privateEmailController
                                                      .text
                                                : 'N/A',
                                            style: TextStyle(
                                              color: isDark
                                                  ? Colors.white
                                                  : Colors.black,
                                              fontWeight: FontWeight.normal,
                                              fontSize: 14,
                                            ),
                                            textAlign: TextAlign.end,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        tr(
                                          "Phone",
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.grey[400]
                                                : Colors.grey[600],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          (state
                                                      .privatePhoneController
                                                      .text
                                                      ?.isNotEmpty ??
                                                  false)
                                              ? state
                                                    .privatePhoneController
                                                    .text
                                              : 'N/A',
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black,
                                            fontWeight: FontWeight.normal,
                                            fontSize: 14,
                                          ),
                                          textAlign: TextAlign.end,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        tr(
                                          "Bank Account Number",
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.grey[400]
                                                : Colors.grey[600],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          (details!['bank_account_id']
                                                      is List &&
                                                  details!['bank_account_id']
                                                          .length >
                                                      1)
                                              ? details!['bank_account_id'][1]
                                              : 'N/A',
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black,
                                            fontWeight: FontWeight.normal,
                                            fontSize: 14,
                                          ),
                                          textAlign: TextAlign.end,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        tr(
                                          "Language",
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.grey[400]
                                                : Colors.grey[600],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          () {
                                            final code = details['lang'];
                                            if (code == null ||
                                                state.languages.isEmpty)
                                              return 'N/A';

                                            final lang = state.languages
                                                .firstWhere(
                                                  (l) =>
                                                      l['code']?.toString() ==
                                                      code.toString(),
                                                  orElse: () => const {},
                                                );

                                            final name = lang['name'];
                                            return name == null ||
                                                    name.toString().isEmpty
                                                ? 'N/A'
                                                : name.toString();
                                          }(),
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black,
                                            fontWeight: FontWeight.normal,
                                            fontSize: 14,
                                          ),
                                          textAlign: TextAlign.end,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        tr(
                                          "Home-Work Distance",
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.grey[400]
                                                : Colors.grey[600],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          (state
                                                      .kmHomeWorkController
                                                      .text
                                                      ?.isNotEmpty ??
                                                  false)
                                              ? state.kmHomeWorkController.text
                                              : '0',
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black,
                                            fontWeight: FontWeight.normal,
                                            fontSize: 14,
                                          ),
                                          textAlign: TextAlign.end,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        tr(
                                          "Private Car Plate",
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.grey[400]
                                                : Colors.grey[600],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          (state
                                                      .privateCarPlateController
                                                      .text
                                                      ?.isNotEmpty ??
                                                  false)
                                              ? state
                                                    .privateCarPlateController
                                                    .text
                                              : 'N/A',
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black,
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
                          ),
                        ),
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
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                tr(
                                  "Citizenship",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF1A1A1A),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        tr(
                                          "Nationality (Country)",
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.grey[400]
                                                : Colors.grey[600],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          (details['country_id'] is List &&
                                                  details['country_id'].length >
                                                      1)
                                              ? details['country_id'][1]
                                              : 'N/A',
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black,
                                            fontWeight: FontWeight.normal,
                                            fontSize: 14,
                                          ),
                                          textAlign: TextAlign.end,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),

                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        tr(
                                          "Identification No",
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.grey[400]
                                                : Colors.grey[600],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          (state
                                                      .identificationIdController
                                                      .text
                                                      ?.isNotEmpty ??
                                                  false)
                                              ? state
                                                    .identificationIdController
                                                    .text
                                              : 'N/A',
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black,
                                            fontWeight: FontWeight.normal,
                                            fontSize: 14,
                                          ),
                                          textAlign: TextAlign.end,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),

                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        tr(
                                          "SSN No",
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.grey[400]
                                                : Colors.grey[600],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          (state
                                                      .ssnIdController
                                                      .text
                                                      ?.isNotEmpty ??
                                                  false)
                                              ? state.ssnIdController.text
                                              : 'N/A',
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black,
                                            fontWeight: FontWeight.normal,
                                            fontSize: 14,
                                          ),
                                          textAlign: TextAlign.end,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),

                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        tr(
                                          "Passport No",
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.grey[400]
                                                : Colors.grey[600],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          (state
                                                      .passportIdController
                                                      .text
                                                      ?.isNotEmpty ??
                                                  false)
                                              ? state.passportIdController.text
                                              : 'N/A',
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black,
                                            fontWeight: FontWeight.normal,
                                            fontSize: 14,
                                          ),
                                          textAlign: TextAlign.end,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),

                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        tr(
                                          "Date of Birth",
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.grey[400]
                                                : Colors.grey[600],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          (state
                                                      .birthdayController
                                                      .text
                                                      ?.isNotEmpty ??
                                                  false)
                                              ? state.birthdayController.text
                                              : 'N/A',
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black,
                                            fontWeight: FontWeight.normal,
                                            fontSize: 14,
                                          ),
                                          textAlign: TextAlign.end,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),

                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        tr(
                                          "Gender",
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.grey[400]
                                                : Colors.grey[600],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          (() {
                                            final g = details['gender'];
                                            return {
                                                  'male': 'Male',
                                                  'female': 'Female',
                                                  'other': 'Other',
                                                }[g] ??
                                                'N/A';
                                          })(),
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black,
                                            fontWeight: FontWeight.normal,
                                            fontSize: 14,
                                          ),
                                          textAlign: TextAlign.end,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),

                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        tr(
                                          "Place of Birth",
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.grey[400]
                                                : Colors.grey[600],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          (state
                                                      .placeOfBirthController
                                                      .text
                                                      ?.isNotEmpty ??
                                                  false)
                                              ? state
                                                    .placeOfBirthController
                                                    .text
                                              : 'N/A',
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black,
                                            fontWeight: FontWeight.normal,
                                            fontSize: 14,
                                          ),
                                          textAlign: TextAlign.end,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),

                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        tr(
                                          "Country of Birth",
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.grey[400]
                                                : Colors.grey[600],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          (details['country_of_birth']
                                                      is List &&
                                                  details['country_of_birth']
                                                          .length >
                                                      1)
                                              ? details['country_of_birth'][1]
                                              : 'N/A',
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black,
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
                          ),
                        ),
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
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                tr(
                                  "Family Status",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF1A1A1A),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        tr(
                                          "Marital Status",
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.grey[400]
                                                : Colors.grey[600],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          (() {
                                            final m = details['marital'];
                                            return {
                                                  'single': 'Single',
                                                  'married': 'Married',
                                                  'cohabitant':
                                                      'Legal Cohabitant',
                                                  'widower': 'Widower',
                                                  'divorced': 'Divorced',
                                                }[m] ??
                                                'N/A';
                                          })(),
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black,
                                            fontWeight: FontWeight.normal,
                                            fontSize: 14,
                                          ),
                                          textAlign: TextAlign.end,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),

                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        tr(
                                          "Spouse Complete Name",
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.grey[400]
                                                : Colors.grey[600],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          (state
                                                      .spouseNameController
                                                      .text
                                                      ?.isNotEmpty ??
                                                  false)
                                              ? state.spouseNameController.text
                                              : 'N/A',
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black,
                                            fontWeight: FontWeight.normal,
                                            fontSize: 14,
                                          ),
                                          textAlign: TextAlign.end,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),

                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        tr(
                                          "Spouse Birthdate",
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.grey[400]
                                                : Colors.grey[600],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          (state
                                                      .spouseBirthdayController
                                                      .text
                                                      ?.isNotEmpty ??
                                                  false)
                                              ? state
                                                    .spouseBirthdayController
                                                    .text
                                              : 'N/A',
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black,
                                            fontWeight: FontWeight.normal,
                                            fontSize: 14,
                                          ),
                                          textAlign: TextAlign.end,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),

                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        tr(
                                          "Number of Dependent Children",
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.grey[400]
                                                : Colors.grey[600],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          (state
                                                      .childrenController
                                                      .text
                                                      ?.isNotEmpty ??
                                                  false)
                                              ? state.childrenController.text
                                              : 'N/A',
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black,
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
                          ),
                        ),
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
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                tr(
                                  "Education",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF1A1A1A),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        tr(
                                          "Certificate Level",
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.grey[400]
                                                : Colors.grey[600],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          (() {
                                            final c = details['certificate'];
                                            return {
                                                  'graduate': 'Graduate',
                                                  'bachelor': 'Bachelor',
                                                  'master': 'Master',
                                                  'doctor': 'Doctor',
                                                  'other': 'Other',
                                                }[c] ??
                                                'N/A';
                                          })(),
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black,
                                            fontWeight: FontWeight.normal,
                                            fontSize: 14,
                                          ),
                                          textAlign: TextAlign.end,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),

                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        tr(
                                          "Field of Study",
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.grey[400]
                                                : Colors.grey[600],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          (state
                                                      .studyFieldController
                                                      .text
                                                      ?.isNotEmpty ??
                                                  false)
                                              ? state.studyFieldController.text
                                              : 'N/A',
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black,
                                            fontWeight: FontWeight.normal,
                                            fontSize: 14,
                                          ),
                                          textAlign: TextAlign.end,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),

                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        tr(
                                          "School",
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.grey[400]
                                                : Colors.grey[600],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          (state
                                                      .studySchoolController
                                                      .text
                                                      ?.isNotEmpty ??
                                                  false)
                                              ? state.studySchoolController.text
                                              : 'N/A',
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black,
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
                          ),
                        ),
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
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                tr(
                                  "Work Permit",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF1A1A1A),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        tr(
                                          "Visa No",
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.grey[400]
                                                : Colors.grey[600],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          (state
                                                      .visaNoController
                                                      .text
                                                      ?.isNotEmpty ??
                                                  false)
                                              ? state.visaNoController.text
                                              : 'N/A',
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black,
                                            fontWeight: FontWeight.normal,
                                            fontSize: 14,
                                          ),
                                          textAlign: TextAlign.end,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),

                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        tr(
                                          "Work Permit No",
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.grey[400]
                                                : Colors.grey[600],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          (state
                                                      .permitNoController
                                                      .text
                                                      ?.isNotEmpty ??
                                                  false)
                                              ? state.permitNoController.text
                                              : 'N/A',
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black,
                                            fontWeight: FontWeight.normal,
                                            fontSize: 14,
                                          ),
                                          textAlign: TextAlign.end,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),

                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        tr(
                                          "Visa Expiration Date",
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.grey[400]
                                                : Colors.grey[600],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          (state
                                                      .visaExpireController
                                                      .text
                                                      ?.isNotEmpty ??
                                                  false)
                                              ? state.visaExpireController.text
                                              : 'N/A',
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black,
                                            fontWeight: FontWeight.normal,
                                            fontSize: 14,
                                          ),
                                          textAlign: TextAlign.end,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),

                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        tr(
                                          "Work Permit Expiration Date",
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.grey[400]
                                                : Colors.grey[600],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          (state
                                                      .workPermitExpireController
                                                      .text
                                                      ?.isNotEmpty ??
                                                  false)
                                              ? state
                                                    .workPermitExpireController
                                                    .text
                                              : 'N/A',
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black,
                                            fontWeight: FontWeight.normal,
                                            fontSize: 14,
                                          ),
                                          textAlign: TextAlign.end,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),

                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        tr(
                                          "Work Permit",
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.grey[400]
                                                : Colors.grey[600],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          state.workPermitBytes != null
                                              ? "Yes"
                                              : "No",
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black,
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
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }
          },
        ),
      ),
    );
  }
}

/// Reusable shimmering rectangle placeholder for loading states.
class ShimmerBox extends StatelessWidget {
  final double height;
  final double width;

  const ShimmerBox({
    super.key,
    required this.height,
    this.width = double.infinity,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
}
