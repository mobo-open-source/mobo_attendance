import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../../../CommonWidgets/globals.dart';
import '../../../../CommonWidgets/core/language/translate_widget.dart';
import '../../../../CommonWidgets/core/providers/language_provider.dart';

/// Reusable form field widget for the absence/leave request creation screen.
///
/// Dynamically renders different input types based on parameters:
/// - Dropdown (single select) for leave types / selections
/// - Text field (number, date, general)
/// - File picker for supporting documents
///
/// Features:
/// - Dark/light theme support
/// - Localization via [translate_widget]
/// - Prefix icons
/// - Validation support
/// - Custom styling (rounded, shadow-free border)
class AbsenceCreateInfo extends StatelessWidget {
  final String label;
  final String value;
  final bool isEditing;
  final TextEditingController? controller;
  final List<Map<String, dynamic>>? dropdownItems;
  final int? selectedId;
  final String? selectedKey;
  final Function(Map<String, dynamic>?)? onDropdownChanged;
  final IconData? prefixIcon;
  final List<Map<String, String>>? selection;
  final Function(String?)? onSelectionChanged;
  final bool isNumberInput;
  final bool isDateInput;
  final bool isDaysInclude;
  final Function(String)? onDateChanged;
  final String? Function(dynamic)? validator;
  final bool isFileInput;
  final Function(PlatformFile)? onFilePicked;
  final Function(String?)? onTextChanged;

  const AbsenceCreateInfo({
    Key? key,
    required this.label,
    required this.value,
    required this.isEditing,
    this.controller,
    this.dropdownItems,
    this.selectedId,
    this.selectedKey,
    this.onDropdownChanged,
    this.prefixIcon,
    this.selection,
    this.onSelectionChanged,
    this.isNumberInput = false,
    this.isDateInput = false,
    this.isDaysInclude = true,
    this.onDateChanged,
    this.validator,
    this.isFileInput = false,
    this.onFilePicked,
    this.onTextChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final translationService = context.read<LanguageProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Sync controller text with value when external state changes
    if (controller != null && controller!.text != value) {
      controller!.text = value;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: dropdownItems != null
          // ── Dropdown for leave types ───────────────────────────────────────
          ? Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: isDark
                    ? const Color(0xFF2A2A2A)
                    : const Color(0xFFF2F4F6),
                border: Border.all(color: Colors.transparent, width: 1),
              ),
              child: DropdownSearch<Map<String, dynamic>>(
                dropdownBuilder: (context, selectedItem) {
                  final bool isHint = selectedItem == null;

                  return Text(
                    (selectedItem?['name'] ??
                        '${translationService.getCached('Select Time Off Type')}'),
                    style: isHint
                        ? TextStyle(
                            fontWeight: FontWeight.w400,
                            color: isDark ? Colors.white54 : Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          )
                        : TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Color(0xff000000),
                          ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  );
                },
                popupProps: PopupProps.menu(
                  menuProps: MenuProps(
                    backgroundColor: isDark
                        ? Colors.grey[900]
                        : Colors.grey[50],
                    elevation: 12,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  showSearchBox: true,
                  searchFieldProps: TextFieldProps(
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      hintText:
                          ' ${translationService.getCached("Search")} ${translationService.getCached(label)}',
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
                items: dropdownItems!,
                itemAsString: (item) => item?['name'] ?? '',
                onChanged: onDropdownChanged,
                dropdownDecoratorProps: DropDownDecoratorProps(
                  dropdownSearchDecoration: InputDecoration(
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    hintText:
                        "${translationService.getCached("Select")} ${translationService.getCached(label)}",
                    hintStyle: TextStyle(
                      fontWeight: FontWeight.w400,
                      color: isDark ? Colors.white54 : Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    prefixIcon: prefixIcon != null
                        ? Icon(
                            prefixIcon,
                            color: isDark
                                ? Colors.white70
                                : const Color(0xff7F7F7F),
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                        color: Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: isDark ? Colors.white : AppStyle.primaryColor,
                        width: 2,
                      ),
                    ),
                  ),
                ),

                validator: validator,
              ),
            )

          // ── Numeric input (duration) ───────────────────────────────────────
          : isNumberInput
          ? SizedBox(
              width: double.infinity,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: isDark
                            ? const Color(0xFF2A2A2A)
                            : const Color(0xFFF2F4F6),
                        border: Border.all(color: Colors.transparent, width: 1),
                      ),
                      child: TextField(
                        controller: controller,
                        keyboardType: TextInputType.number,
                        readOnly: true,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          hintText: translationService.getCached(label),
                          hintStyle: TextStyle(
                            fontWeight: FontWeight.w400,
                            color: isDark ? Colors.white54 : Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                          errorBorder: InputBorder.none,
                          focusedErrorBorder: InputBorder.none,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: isDark
                                  ? Colors.white
                                  : AppStyle.primaryColor,
                              width: 2,
                            ),
                          ),
                        ),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Color(0xff000000),
                        ),
                      ),
                    ),
                  ),
                  if (isDaysInclude) ...[
                    const SizedBox(width: 8),
                    tr(
                      "Days",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ],
              ),
            )

          // ── File picker ────────────────────────────────────────────────────
          : isFileInput
          ? Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: isDark
                          ? const Color(0xFF2A2A2A)
                          : const Color(0xFFF2F4F6),
                      border: Border.all(color: Colors.transparent, width: 1),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            value.isNotEmpty
                                ? value
                                : (translationService.getCached(
                                        "No file selected",
                                      ) ??
                                      "No file selected"),
                            style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.black87,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () async {
                            final result = await FilePicker.platform
                                .pickFiles();
                            if (result != null && result.files.isNotEmpty) {
                              final file = result.files.first;
                              if (onFilePicked != null) {
                                onFilePicked!(file);
                              }
                            }
                          },
                          icon: Icon(
                            Icons.attach_file,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          label: tr(
                            "Select File",
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )

          // ── Simple selection dropdown (e.g. AM/PM) ──────────────────────
          : selection != null
          ? Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: isDark
                    ? const Color(0xFF2A2A2A)
                    : const Color(0xFFF2F4F6),
                border: Border.all(color: Colors.transparent, width: 1),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButtonFormField2<String>(
                  items: selection!.map((item) {
                    return DropdownMenuItem(
                      value: item['id'],
                      child: Text(item['name'] ?? ''),
                    );
                  }).toList(),
                  value: selectedKey,
                  onChanged: (selectedId) {
                    if (onSelectionChanged != null) {
                      onSelectionChanged!(selectedId);
                    }
                  },
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Color(0xff000000),
                  ),
                  buttonStyleData: const ButtonStyleData(
                    height: 40,
                    width: 6,
                    padding: EdgeInsets.symmetric(horizontal: 12),
                  ),
                  menuItemStyleData: const MenuItemStyleData(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    height: 40,
                  ),

                  iconStyleData: const IconStyleData(iconSize: 25),
                  dropdownStyleData: DropdownStyleData(
                    maxHeight: 200,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white,
                    ),
                    offset: const Offset(0, -4),
                  ),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    hintText: translationService.getCached(label),
                    hintStyle: TextStyle(
                      fontWeight: FontWeight.w400,
                      color: isDark ? Colors.white54 : Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                        color: Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: isDark ? Colors.white : AppStyle.primaryColor,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
            )

          // ── Date picker field ──────────────────────────────────────────
          : isDateInput
          ? Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: isDark
                    ? const Color(0xFF2A2A2A)
                    : const Color(0xFFF2F4F6),
                border: Border.all(color: Colors.transparent, width: 1),
              ),
              child: GestureDetector(
                onTap: () async {
                  DateTime? pickedDate = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(1950),
                    lastDate: DateTime(2100),
                  );

                  if (pickedDate != null) {
                    final finalText =
                        "${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}";

                    controller?.text = finalText;

                    if (onDateChanged != null) {
                      onDateChanged!(finalText);
                    }
                  }
                },
                child: AbsorbPointer(
                  child: TextFormField(
                    controller: controller,
                    onChanged: onTextChanged,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      hintText: translationService.getCached(label),
                      hintStyle: TextStyle(
                        fontWeight: FontWeight.w400,
                        color: isDark ? Colors.white54 : Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                      prefixIcon: Icon(
                        HugeIcons.strokeRoundedCalendar03,
                        color: isDark
                            ? Colors.white70
                            : const Color(0xff7F7F7F),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: isDark ? Colors.white : AppStyle.primaryColor,
                          width: 2,
                        ),
                      ),
                    ),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : const Color(0xff000000),
                    ),
                    readOnly: true,
                  ),
                ),
              ),
            )

          // ── General text field (fallback) ─────────────────────────────
          : Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: isDark
                    ? const Color(0xFF2A2A2A)
                    : const Color(0xFFF2F4F6),
                border: Border.all(color: Colors.transparent, width: 1),
              ),
              child: TextFormField(
                controller: controller,
                onChanged: onTextChanged,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  hintText: translationService.getCached(label),
                  hintStyle: TextStyle(
                    fontWeight: FontWeight.w400,
                    color: isDark ? Colors.white54 : Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: isDark ? Colors.white : AppStyle.primaryColor,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
