import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../CommonWidgets/core/providers/language_provider.dart';
import '../../../../../CommonWidgets/globals.dart';

/// Reusable field widget optimized for **employee detail view** (both view & edit modes).
///
/// Main differences from `InfoText` / `EmployeeCreateInfo`:
/// - Simpler view mode (column layout with "No X assigned" fallback when value is "N/A")
/// - Special handling for "Job" field (shows "No job assigned" message)
/// - No heavy container in view mode — just clean text
/// - Edit mode supports dropdown (Odoo records) or basic text input
/// - No static `selection` dropdown (unlike `InfoText`)
///
/// Used primarily in `EmployeeFormPage` edit mode for personal/work info fields.
class PersonalInfo extends StatelessWidget {
  final String? label;
  final String value;
  final bool isEditing;
  final TextEditingController? controller;
  final List<Map<String, dynamic>>? dropdownItems;
  final int? selectedId;
  final Function(Map<String, dynamic>?)? onDropdownChanged;
  final IconData? prefixIcon;
  final VoidCallback? onTapEditing;
  final List<Map<String, String>>? selection;
  final Function(String?)? onSelectionChanged;
  final Function(String?)? onTextChanged;
  final FocusNode? focusNode;

  const PersonalInfo({
    Key? key,
    this.label,
    required this.value,
    required this.isEditing,
    this.controller,
    this.dropdownItems,
    this.selectedId,
    this.onDropdownChanged,
    this.prefixIcon,
    this.onTapEditing,
    this.selection,
    this.onSelectionChanged,
    this.onTextChanged,
    this.focusNode,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Sync controller text with external value when it changes
    if (controller != null && value.isNotEmpty && controller!.text != value) {
      controller!.text = value;
    }

    final translationService = context.read<LanguageProvider>();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: isEditing
          ? (dropdownItems != null
                // ── Edit mode: Odoo-style searchable dropdown ───────────────────────
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
                            selectedItem?['name'] ?? '',
                            style: isHint
                                ? TextStyle(
                                    fontWeight: FontWeight.w400,
                                    color: isDark
                                        ? Colors.white54
                                        : Colors.grey[600],
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
                                color: isDark
                                    ? Colors.white54
                                    : Colors.grey[600],
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
                          (element) => element['id'] == selectedId,
                          orElse: () => {
                            'id': null,
                            'name':
                                "${translationService.getCached("Select")} ${translationService.getCached("$label")}",
                          },
                        ),
                        onChanged: (val) {
                          onDropdownChanged?.call(val);
                        },
                        dropdownDecoratorProps: DropDownDecoratorProps(
                          dropdownSearchDecoration: InputDecoration(
                            errorBorder: InputBorder.none,
                            focusedErrorBorder: InputBorder.none,
                            hintText:
                                "${translationService.getCached("Select")} ${translationService.getCached("$label")}",
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
                                color: isDark
                                    ? Colors.white
                                    : AppStyle.primaryColor,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                        validator: (value) => value == null
                            ? '${translationService.getCached('Please select')} $label'
                            : null,
                      ),
                    ),
                  )
                // ── Edit mode: simple text input ─────────────────────────────────────
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
                      readOnly: onTapEditing != null,
                      onTap: onTapEditing,
                      onChanged: onTextChanged,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? Colors.white70
                            : const Color(0xff000000),
                      ),
                      maxLines: 1,
                      decoration: InputDecoration(
                        errorBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                        hintText:
                            "${translationService.getCached("Enter")} ${translationService.getCached("$label")}",
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
                            color: isDark
                                ? Colors.white
                                : AppStyle.primaryColor,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ))
          : label == "Job"
          // Special handling for "Job" field
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                value == "N/A"
                    ? Text(
                        "Job",
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.white70 : Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    : SizedBox.shrink(),
                const SizedBox(height: 4),

                value == "N/A"
                    ? Text(
                        "No job assigned",
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      )
                    : Text(
                        value,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                value == "N/A"
                    ? Text(
                        label ?? "",
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.white70 : Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    : SizedBox.shrink(),

                const SizedBox(height: 4),

                value == "N/A"
                    ? Text(
                        "No ${label?.toLowerCase()} assigned",
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      )
                    : Text(
                        value,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
              ],
            ),
    );
  }
}
