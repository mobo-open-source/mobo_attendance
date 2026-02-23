import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../CommonWidgets/core/providers/language_provider.dart';
import '../../../../../CommonWidgets/globals.dart';

/// Reusable read-only / editable field widget used in employee detail view (view & edit modes).
///
/// Unlike `EmployeeCreateInfo` (used during creation), this widget:
/// - Supports **view mode** (simple RichText label + value)
/// - Supports **edit mode** (dropdown, selection, or text input)
/// - Is optimized for displaying existing data with minimal decoration
/// - Uses simpler styling (no heavy containers in view mode)
/// - Handles focus nodes for keyboard navigation in edit mode
///
/// Rendering modes:
/// 1. **View mode** (`isEditing = false`): RichText label:value pair
/// 2. **Edit mode** (`isEditing = true`):
///    - Odoo-style searchable dropdown (`dropdownItems` provided)
///    - Static selection dropdown (`selection` list provided)
///    - Text input (with optional controller, onTap, multi-line for notes)
class InfoText extends StatelessWidget {
  final String label;
  final String value;
  final bool isEditing;
  final TextEditingController? controller;
  final List<Map<String, dynamic>>? dropdownItems;
  final int? selectedId;
  final String? selectedKey;
  final Function(Map<String, dynamic>?)? onDropdownChanged;
  final IconData? prefixIcon;
  final VoidCallback? onTapEditing;
  final List<Map<String, String>>? selection;
  final Function(String?)? onSelectionChanged;
  final FocusNode? focusNode;
  final Function(String?)? onTextChanged;

  const InfoText({
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
    this.onTapEditing,
    this.selection,
    this.onSelectionChanged,
    this.focusNode,
    this.onTextChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final translationService = context.read<LanguageProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Sync controller with external value when it changes
    if (controller != null && value.isNotEmpty && controller!.text != value) {
      controller!.text = value;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: isEditing
          ? (dropdownItems != null
                // ── Odoo-style searchable dropdown ────────────────────────────────
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
                        (element) => element['id'] == selectedId,
                        orElse: () => {
                          'id': null,
                          'name':
                              "${translationService.getCached("Select")} ${translationService.getCached('$label')}",
                        },
                      ),
                      onChanged: onDropdownChanged,
                      dropdownDecoratorProps: DropDownDecoratorProps(
                        dropdownSearchDecoration: InputDecoration(
                          errorBorder: InputBorder.none,
                          focusedErrorBorder: InputBorder.none,
                          hintText:
                              "${translationService.getCached("Select")} ${translationService.getCached('$label')}",
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
                  )
                : selection != null
                // ── Static selection dropdown (gender, marital, type, etc.) ────────
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
                      child: DropdownSearch<String>(
                        dropdownBuilder: (context, selectedItem) {
                          final String text = selectedItem ?? '';

                          final bool isHint = text.startsWith("Select");

                          return Text(
                            selectedItem ?? '',
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
                              hintText:
                                  '${translationService.getCached("Search")} ${translationService.getCached('$label')}',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        items: selection!
                            .map((item) => item['name'] ?? '')
                            .toList(),
                        selectedItem: selection!.firstWhere(
                          (item) => item['id'] == selectedKey,
                          orElse: () => {
                            'name':
                                "${translationService.getCached("Select")} ${translationService.getCached('$label')}",
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
                                color: isDark
                                    ? Colors.white
                                    : AppStyle.primaryColor,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                // ── Text input (single or multi-line) ────────────────────────────────
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
                        color: isDark
                            ? Colors.white70
                            : const Color(0xff000000),
                      ),
                      readOnly: onTapEditing != null,
                      onTap: onTapEditing,
                      onChanged: onTextChanged,
                      maxLines: label == 'Note' ? 5 : 1,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        hintText:
                            '${translationService.getCached('Enter')} ${translationService.getCached(label)}',
                        hintStyle: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: isDark ? Colors.white54 : Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                        prefixIcon: prefixIcon != null
                            ? Icon(
                                prefixIcon,
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[500],
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
          // ── View mode: simple label + value ──────────────────────────────────────
          : RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: "$label:   ",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  TextSpan(
                    text: value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
