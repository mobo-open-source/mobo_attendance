import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../../CommonWidgets/core/providers/language_provider.dart';
import '../../../../../../CommonWidgets/globals.dart';

/// Reusable form row widget specifically designed for the **Work Information** page.
///
/// Supports both **view** and **edit** modes:
/// - View mode: Displays label + value using `RichText`
/// - Edit mode: Renders appropriate input based on configuration:
///   • Odoo-style searchable dropdown (`dropdownItems`)
///   • Static selection dropdown (`selection` list)
///   • Plain text input (with optional read-only + tap handler)
///
/// Used exclusively in `WorkInfoPage` for fields like:
/// - Work Address, Work Location, Attendance Approver, Working Hours, Timezone
class WorkInfoRow extends StatelessWidget {
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

  const WorkInfoRow({
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
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final translationService = context.read<LanguageProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Sync external value changes into controller (prevents stale text)
    if (controller != null && controller!.text != value) {
      controller!.text = value;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: isEditing
          ? (dropdownItems != null
                // ── Edit Mode: Odoo-style searchable dropdown ───────────────────────
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
                        if (selectedItem == null) {
                          return Text(
                            "${translationService.getCached("Select")} ${translationService.getCached('$label')}",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: isDark ? Colors.white54 : Colors.grey[600],
                              fontStyle: FontStyle.italic,
                            ),
                          );
                        }

                        return Text(
                          selectedItem['name'],
                          style: TextStyle(
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
                      selectedItem: (selectedId == null || selectedId == 0)
                          ? null
                          : dropdownItems!
                                .cast<Map<String, dynamic>?>()
                                .firstWhere(
                                  (e) => e?['id'] == selectedId,
                                  orElse: () => null,
                                ),

                      onChanged: onDropdownChanged,
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
                  )
                : selection != null
                // ── Edit Mode: Static selection dropdown (e.g. timezone) ─────────────
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

                        final bool isHint = text.startsWith("Select");

                        return Text(
                          isHint
                              ? "${translationService.getCached("Select")} ${translationService.getCached(label)}"
                              : text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: isHint
                                ? FontWeight.w400
                                : FontWeight.w600,
                            color: isHint
                                ? (isDark ? Colors.white54 : Colors.grey[600])
                                : (isDark
                                      ? Colors.white70
                                      : const Color(0xff000000)),
                            fontStyle: isHint
                                ? FontStyle.italic
                                : FontStyle.normal,
                          ),
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
                      items: selection!
                          .map((item) => item['name'] ?? '')
                          .toList(),
                      selectedItem: selection!.firstWhere(
                        (item) => item['id'] == selectedKey,
                        orElse: () => {'name': 'None'},
                      )['name'],
                      onChanged: (selectedName) {
                        if (onSelectionChanged != null) {
                          final selectedItem = selection!.firstWhere(
                            (item) => item['name'] == selectedName,
                          );
                          onSelectionChanged!(selectedItem['id']);
                        }
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
                    ),
                  )
                // ── Edit Mode: Plain text input (fallback) ───────────────────────────
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
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? Colors.white70
                            : const Color(0xff000000),
                      ),
                      maxLines: label == 'Note' ? 5 : 1,
                      decoration: InputDecoration(
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
                      onChanged: (value) {
                        if (label == 'Note') {}
                      },
                    ),
                  ))
          // ── View Mode: Simple label + value ─────────────────────────────────────
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
