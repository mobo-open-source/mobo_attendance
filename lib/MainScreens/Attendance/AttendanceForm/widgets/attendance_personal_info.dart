import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';
import 'dart:typed_data';
import 'package:intl/intl.dart';

import '../../../../../../CommonWidgets/globals.dart';
import '../../../../CommonWidgets/core/providers/language_provider.dart';

/// A custom widget to display or edit personal attendance information for an employee.
/// Can render as a dropdown, date picker, text field, or read-only display based on provided properties.
class AttendancePersonalInfo extends StatelessWidget {
  final String? employeeName;
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
  final List<Map<String, dynamic>>? language;
  final List<Map<String, String>>? selection;
  final Function(String?)? onSelectionChanged;
  final bool isNumberInput;
  final bool isDateInput;
  final bool isKmInclude;
  final String? fileUrl;
  final VoidCallback? onFileUpload;
  final VoidCallback? onFileView;
  final bool isFileInput;
  final Uint8List? fileBytes;
  final VoidCallback? onFileDelete;
  final Function(String)? onChanged;

  const AttendancePersonalInfo({
    super.key,
    this.employeeName,
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
    this.language,
    this.selection,
    this.onSelectionChanged,
    this.isNumberInput = false,
    this.isDateInput = false,
    this.isKmInclude = true,
    this.fileUrl,
    this.onFileUpload,
    this.onFileView,
    this.isFileInput = false,
    this.fileBytes,
    this.onFileDelete,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    /// Access language translation service
    final translationService = context.read<LanguageProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    /// Update controller text if it differs from value
    if (controller != null && controller!.text != value) {
      controller!.text = value;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: isEditing
          ? (dropdownItems != null
                /// Builds a dropdown field with search and custom styling
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

                        final bool isHint = text == "Select an Employee";

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
                      itemAsString: (item) => item['name'] ?? '',
                      selectedItem: dropdownItems!.firstWhere(
                        (element) => element['id'] == selectedId,
                        orElse: () => {
                          'id': null,
                          'name': 'Select an Employee',
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
                : isDateInput
                /// Builds a read-only date picker field
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
                          TimeOfDay? pickedTime = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.now(),
                          );

                          if (pickedTime != null) {
                            final combined = DateTime(
                              pickedDate.year,
                              pickedDate.month,
                              pickedDate.day,
                              pickedTime.hour,
                              pickedTime.minute,
                            );
                            final isoValue = DateFormat(
                              'yyyy-MM-dd HH:mm',
                            ).format(combined);
                            controller?.text = isoValue;
                            onChanged?.call(isoValue);
                          }
                        }
                      },
                      child: AbsorbPointer(
                        child: TextFormField(
                          controller: controller,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? Colors.white70
                                : const Color(0xff000000),
                          ),
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            errorBorder: InputBorder.none,
                            focusedErrorBorder: InputBorder.none,
                            hintText:
                                "${translationService.getCached("Choose")} ${translationService.getCached(label)}",
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
                                color: isDark
                                    ? Colors.white
                                    : AppStyle.primaryColor,
                                width: 2,
                              ),
                            ),
                          ),
                          readOnly: true,
                        ),
                      ),
                    ),
                  )
                /// Builds a standard text field
                : TextFormField(
                    controller: controller,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : const Color(0xff000000),
                    ),
                    readOnly: onTapEditing != null,
                    onTap: onTapEditing,
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
                        borderSide: BorderSide(
                          color: isDark
                              ? Colors.white24
                              : AppStyle.primaryColor.withOpacity(0.2),
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
                  ))
          /// Builds a read-only display of the value with the label
          : RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: "${translationService.getCached("$label")}:   ",
                    style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  TextSpan(
                    text: value,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.normal,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
