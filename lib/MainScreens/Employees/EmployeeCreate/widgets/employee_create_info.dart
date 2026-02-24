import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../../CommonWidgets/globals.dart';
import '../../../../CommonWidgets/core/providers/language_provider.dart';

/// Reusable form field widget used across the employee creation/editing screen.
///
/// Dynamically renders one of several input types based on parameters:
/// 1. **DropdownSearch** (for Odoo records: departments, jobs, countries, etc.)
/// 2. **Simple Dropdown** (for static selections: gender, marital status, employee type)
/// 3. **Date picker field** (read-only TextFormField + showDatePicker)
/// 4. **Number input** (with optional "Km" suffix for distance)
/// 5. **General text field** (single-line, optional prefix icon)
///
/// Features:
/// - Dark/light theme support
/// - Localization via [translate_widget] and [LanguageProvider]
/// - Focus node support (for keyboard navigation)
/// - Prefix icons (HugeIcons)
/// - Hint / placeholder text
/// - Custom styling (rounded container, transparent border, primary color focus)
class EmployeeCreateInfo extends StatelessWidget {
  final String? label;
  final String value;
  final TextEditingController? controller;
  final List<Map<String, dynamic>>? dropdownItems;
  final List<Map<String, dynamic>>? dropdownSelectionItems;
  final int? selectedId;
  final String? selectedKey;
  final Function(Map<String, dynamic>?)? onDropdownChanged;
  final IconData? prefixIcon;
  final VoidCallback? onTapEditing;
  final List<Map<String, String>>? selection;
  final Function(String?)? onSelectionChanged;
  final Function(String?)? onTextChanged;
  final bool isDateInput;
  final bool isNumberInput;
  final bool isKmInclude;
  final FocusNode? focusNode;

  const EmployeeCreateInfo({
    Key? key,
    this.label,
    required this.value,
    this.controller,
    this.dropdownItems,
    this.dropdownSelectionItems,
    this.selectedId,
    this.selectedKey,
    this.onDropdownChanged,
    this.prefixIcon,
    this.onTapEditing,
    this.selection,
    this.onSelectionChanged,
    this.onTextChanged,
    this.isDateInput = false,
    this.isKmInclude = false,
    this.isNumberInput = false,
    this.focusNode,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final translationService = context.read<LanguageProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Sync controller text with external value when it changes
    if (controller != null && controller!.text != value) {
      controller!.text = value;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: dropdownItems != null
          // ── Odoo-style searchable dropdown ────────────────────────────────
          ? Focus(
              focusNode: focusNode,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: isDark
                      ? const Color(0xFF2A2A2A)
                      : const Color(0xFFF2F4F6),
                  border: Border.all(color: Colors.transparent, width: 1),
                ),
                child: DropdownSearch<Map<String, dynamic>>(
                  dropdownBuilder: (context, selectedItem) {
                    final String text = selectedItem?['name'] ?? '';

                    final bool isHint = text.startsWith("Select");

                    return Text(
                      (label == "Bank Account Number")
                          ? selectedItem!['display_name']
                          : (selectedItem?['name'] ?? ''),
                      style: isHint
                          ? TextStyle(
                              fontWeight: FontWeight.w400,
                              color: isDark ? Colors.white54 : Colors.grey[600],
                              fontStyle: FontStyle.italic,
                            )
                          : TextStyle(
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? Colors.white70
                                  : Color(0xff000000),
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
                            "${translationService.getCached("Search")} ${translationService.getCached('$label')}",
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
                  selectedItem: dropdownItems!.firstWhere(
                    (element) =>
                        (selectedId != null && element['id'] == selectedId) ||
                        (selectedKey != null && element['code'] == selectedKey),
                    orElse: () => {
                      'id': null,
                      'name':
                          "${translationService.getCached('Select')} ${translationService.getCached('$label')}",
                    },
                  ),

                  onChanged: (val) {
                    FocusScope.of(context).requestFocus(focusNode);
                    onDropdownChanged?.call(val);
                  },
                  dropdownDecoratorProps: DropDownDecoratorProps(
                    dropdownSearchDecoration: InputDecoration(
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      hintText:
                          "${translationService.getCached('Select')} ${translationService.getCached('$label')}",
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
                  validator: (value) => value == null
                      ? '${translationService.getCached('Please select')} ${translationService.getCached('$label')}'
                      : null,
                ),
              ),
            )
          // ── Numeric input with optional "Km" suffix ─────────────────────────
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
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          errorBorder: InputBorder.none,
                          focusedErrorBorder: InputBorder.none,
                          hintText: translationService.getCached(label!),
                          hintStyle: TextStyle(
                            fontWeight: FontWeight.w400,
                            color: isDark ? Colors.white54 : Colors.grey[600],
                            fontStyle: FontStyle.italic,
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
                              color: isDark
                                  ? Colors.white
                                  : AppStyle.primaryColor,
                              width: 2,
                            ),
                          ),
                        ),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? Colors.white70
                              : const Color(0xff000000),
                        ),
                      ),
                    ),
                  ),
                  if (isKmInclude) ...[
                    const SizedBox(width: 8),
                    Text(
                      "Km",
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
          // ── Date picker field ──────────────────────────────────────────────
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
                  DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(1950),
                    lastDate: DateTime(2100),
                  );

                  if (picked != null) {
                    final formatted =
                        "${picked.year.toString().padLeft(4, '0')}-"
                        "${picked.month.toString().padLeft(2, '0')}-"
                        "${picked.day.toString().padLeft(2, '0')}";

                    onTextChanged?.call(formatted);
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
                      hintText:
                          "${translationService.getCached("Choose")} ${translationService.getCached(label!)}",
                      hintStyle: TextStyle(
                        fontSize: 16,
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
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : const Color(0xff000000),
                    ),
                    readOnly: true,
                  ),
                ),
              ),
            )
          // ── Simple static selection dropdown ────────────────────────────
          : selection != null
          ? Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: isDark
                    ? const Color(0xFF2A2A2A)
                    : const Color(0xFFF2F4F6),
                border: Border.all(color: Colors.transparent, width: 1),
              ),
              child: DropdownSearch<String>(
                dropdownBuilder: (context, selectedItem) {
                  final String text = selectedItem ?? '';

                  final bool isHint = text.startsWith(
                    "${translationService.getCached('Select')}",
                  );

                  return Text(
                    text.isEmpty
                        ? "${translationService.getCached('Select')} ${translationService.getCached('$label')}"
                        : text,
                    style: isHint
                        ? TextStyle(
                            fontWeight: FontWeight.w400,
                            color: isDark ? Colors.white54 : Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          )
                        : TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? Colors.white70
                                : const Color(0xff000000),
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
                          '${translationService.getCached("Search")} ${translationService.getCached('$label')}',
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
                items: selection!.map((item) => item['name'] ?? '').toList(),
                selectedItem: selection!.firstWhere(
                  (item) => item['id'] == selectedKey,
                  orElse: () => {
                    'name':
                        "${translationService.getCached('Select')} ${translationService.getCached('$label')}",
                  },
                )['name'],
                onChanged: (selectedName) {
                  if (onSelectionChanged != null) {
                    final selectedItem = selection!.firstWhere(
                      (item) => item['name'] == selectedName,
                    );
                    FocusScope.of(context).requestFocus(focusNode);
                    onSelectionChanged!(selectedItem['id']);
                  }
                },
                dropdownDecoratorProps: DropDownDecoratorProps(
                  dropdownSearchDecoration: InputDecoration(
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    hintText:
                        "${translationService.getCached('Select')} ${translationService.getCached('$label')}",
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
              ),
            )
          // ── General single-line text field (fallback) ──────────────────────
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
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : const Color(0xff000000),
                ),
                onChanged: onTextChanged,
                readOnly: onTapEditing != null,
                onTap: onTapEditing,
                maxLines: 1,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  hintText: translationService.getCached(label!),
                  hintStyle: TextStyle(
                    fontWeight: FontWeight.w400,
                    color: isDark ? Colors.white54 : Colors.grey[600],
                    fontStyle: FontStyle.italic,
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
            ),
    );
  }
}
