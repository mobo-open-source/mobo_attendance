import 'package:dropdown_search/dropdown_search.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobo_attendance/CommonWidgets/shared/widgets/snackbar.dart';
import 'dart:typed_data';

import '../../../../../../CommonWidgets/core/language/translate_widget.dart';
import '../../../../../../CommonWidgets/core/providers/language_provider.dart';
import '../../../../../../CommonWidgets/globals.dart';

/// Reusable row/field widget for displaying and editing private employee information.
///
/// Main differences from similar widgets (`InfoText`, `PersonalInfo`):
/// - Supports **file input** mode (work permit upload/view/download/delete)
/// - Supports **number input** with optional "Km" suffix
/// - Supports **date picker** integration
/// - Supports **language** dropdown (uses `code` instead of `id`)
/// - More flexible styling and behavior for private info form
///
/// Rendering modes (when `isEditing = true`):
/// 1. Odoo-style searchable dropdown (`dropdownItems` provided)
/// 2. Static selection dropdown (`selection` list provided)
/// 3. Language dropdown (`language` list provided, uses `code`)
/// 4. Number input (with optional "Km" suffix)
/// 5. Date input (with picker on tap)
/// 6. File upload/view/delete (work permit)
/// 7. Plain text input
///
/// In view mode (`isEditing = false`):
/// - Simple label:value text
/// - Special handling for file (shows icons + download/delete buttons)
/// - Number fields show "Km" suffix if `isKmInclude = true`
class PrivateInfoRow extends StatelessWidget {
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
  final FocusNode? focusNode;

  const PrivateInfoRow({
    Key? key,
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
    this.focusNode,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final translationService = context.read<LanguageProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Sync controller with external value when it changes
    if (controller != null) {
      if (value.isEmpty || value == "N/A") {
        controller!.clear();
      } else if (controller!.text != value) {
        controller!.text = value;
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: isEditing
          ? (dropdownItems != null
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
                          if (selectedItem == null) {
                            return Text(
                              "${translationService.getCached("Select")} ${translationService.getCached('$label')}",
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w400,
                                color: isDark
                                    ? Colors.white54
                                    : Colors.grey[600],
                                fontStyle: FontStyle.italic,
                              ),
                            );
                          }

                          return Text(
                            (label == "Bank Account Number")
                                ? selectedItem['display_name']
                                : (selectedItem['name'] ?? ''),
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
                        selectedItem: (selectedId == null || selectedId == 0)
                            ? null
                            : dropdownItems!
                                  .cast<Map<String, dynamic>?>()
                                  .firstWhere(
                                    (e) => e?['id'] == selectedId,
                                    orElse: () => null,
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
                    ),
                  )
                : isFileInput
                // ── File input (work permit upload) ────────────────────────────────
                ? Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: isDark
                          ? const Color(0xFF2A2A2A)
                          : const Color(0xFFF2F4F6),
                      border: Border.all(color: Colors.transparent, width: 1),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: GestureDetector(
                        onTap: onFileUpload,
                        child: Row(
                          children: [
                            Icon(
                              Icons.upload_file,
                              color: isDark ? Colors.white54 : Colors.grey[600],
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                (fileBytes == null || fileBytes!.isEmpty)
                                    ? "${translationService.getCached("Upload")} ${translationService.getCached("$label")} ${translationService.getCached("File")}"
                                    : translationService.getCached(
                                            "Change File",
                                          ) ??
                                          "Change File",
                                style: (fileBytes == null || fileBytes!.isEmpty)
                                    ? TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w400,
                                        color: isDark
                                            ? Colors.white54
                                            : Colors.grey[600],
                                        fontStyle: FontStyle.italic,
                                      )
                                    : TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? Colors.white70
                                            : Color(0xff000000),
                                        fontStyle: FontStyle.italic,
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                : isNumberInput
                // ── Number input (with optional Km suffix) ────────────────────────
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
                              border: Border.all(
                                color: Colors.transparent,
                                width: 1,
                              ),
                            ),
                            child: TextField(
                              controller: controller,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                errorBorder: InputBorder.none,
                                focusedErrorBorder: InputBorder.none,
                                hintText:
                                    "${translationService.getCached("Enter")} ${translationService.getCached('$label')}",
                                hintStyle: TextStyle(
                                  fontWeight: FontWeight.w400,
                                  color: isDark
                                      ? Colors.white54
                                      : Colors.grey[600],
                                  fontStyle: FontStyle.italic,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
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
                : isDateInput
                // ── Date input (with picker) ──────────────────────────────────────
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
                      child: GestureDetector(
                        onTap: () async {
                          FocusManager.instance.primaryFocus?.unfocus();

                          DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime(1950),
                            lastDate: DateTime(2100),
                          );

                          if (picked != null) {
                            controller?.text =
                                "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
                          }
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (focusNode != null &&
                                focusNode!.canRequestFocus) {
                              FocusScope.of(context).requestFocus(focusNode!);
                            }
                          });
                        },
                        child: AbsorbPointer(
                          child: TextFormField(
                            controller: controller,
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
                                fontSize: 15,
                                fontWeight: FontWeight.w400,
                                color: isDark
                                    ? Colors.white54
                                    : Colors.grey[600],
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
                            readOnly: true,
                          ),
                        ),
                      ),
                    ),
                  )
                : selection != null
                // ── Static selection dropdown ─────────────────────────────────────
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

                          final bool isHint = text == '';

                          return Text(
                            text.isEmpty
                                ? "${translationService.getCached('Select')} ${translationService.getCached('$label')}"
                                : text,
                            style: isHint
                                ? TextStyle(
                                    fontSize: 15,
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
                        items: selection!
                            .map((item) => item['name'] as String? ?? '')
                            .toList(),

                        selectedItem: selectedKey == null
                            ? null
                            : selection!
                                  .map((e) => e['name'])
                                  .firstWhere(
                                    (e) => e == selectedKey,
                                    orElse: () => null,
                                  ),

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
                      ),
                    ),
                  )
                : language != null
                // ── Language dropdown (uses code as value) ────────────────────────
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
                          if (selectedItem == null) {
                            return Text(
                              "${translationService.getCached("Select")} ${translationService.getCached('$label')}",
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w400,
                                color: isDark
                                    ? Colors.white54
                                    : Colors.grey[600],
                                fontStyle: FontStyle.italic,
                              ),
                            );
                          }

                          return Text(
                            selectedItem,
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
                        items: language!
                            .map((item) => item['name'] as String? ?? '')
                            .toList(),

                        selectedItem: selectedKey == null
                            ? null
                            : language!
                                  .map((e) => e['name'])
                                  .firstWhere(
                                    (e) => e == selectedKey,
                                    orElse: () => null,
                                  ),

                        onChanged: (selectedName) {
                          FocusScope.of(context).requestFocus(focusNode);
                          if (onSelectionChanged != null) {
                            final selectedItem = language!.firstWhere(
                              (item) => item['name'] == selectedName,
                            );
                            onSelectionChanged!(selectedItem['code']);
                          }
                        },
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
                      ),
                    ),
                  )
                // ── Plain text input ────────────────────────────────────────────────
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
                      inputFormatters: isNumberInput
                          ? [FilteringTextInputFormatter.digitsOnly]
                          : [],
                      maxLines: label == 'Note' ? 5 : 1,
                      decoration: InputDecoration(
                        errorBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                        hintText:
                            "${translationService.getCached("Enter")} ${translationService.getCached('$label')}",
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
          // ── View mode ──────────────────────────────────────────────────────────
          : RichText(
              text: TextSpan(
                children: [
                  if (fileBytes == null)
                    TextSpan(
                      text: "$label:   ",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  isNumberInput
                      ? TextSpan(
                          text: isKmInclude ? "$value Km" : value,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        )
                      : (fileBytes != null && fileBytes!.isNotEmpty)
                      // ── Work permit file display with actions ────────────────────────
                      ? WidgetSpan(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                "$label:   ",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                              TextButton(
                                onPressed: () async {
                                  if (fileBytes == null || fileBytes!.isEmpty)
                                    return;

                                  String extension = "";
                                  if (fileBytes!.length > 4) {
                                    if (fileBytes![0] == 0x25 &&
                                        fileBytes![1] == 0x50 &&
                                        fileBytes![2] == 0x44 &&
                                        fileBytes![3] == 0x46) {
                                      extension = "pdf";
                                    } else if (fileBytes![0] == 0x89 &&
                                        fileBytes![1] == 0x50 &&
                                        fileBytes![2] == 0x4E &&
                                        fileBytes![3] == 0x47) {
                                      extension = "png";
                                    } else if (fileBytes![0] == 0xFF &&
                                        fileBytes![1] == 0xD8) {
                                      extension = "jpg";
                                    } else {
                                      extension = "bin";
                                    }
                                  }
                                },
                                child: Row(
                                  children: [
                                    Icon(
                                      HugeIcons.strokeRoundedFile01,
                                      size: 18,
                                      color: isDark
                                          ? Colors.white70
                                          : AppStyle.primaryColor,
                                    ),
                                    tr(
                                      "Work Permit",
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w400,
                                        color: isDark
                                            ? Colors.white70
                                            : AppStyle.primaryColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (isEditing || onFileUpload != null)
                                GestureDetector(
                                  onTap: onFileUpload,
                                  child: Icon(
                                    HugeIcons.strokeRoundedEdit03,
                                    size: 18,
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black87,
                                  ),
                                ),
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: () async {
                                  try {
                                    if (fileBytes == null ||
                                        fileBytes!.isEmpty) {
                                      CustomSnackbar.showError(
                                        context,
                                        "No file available to download",
                                      );
                                      return;
                                    }

                                    final Uint8List pdfBytes = fileBytes!;

                                    final String fileName =
                                        "work_permit_${employeeName!}.pdf";

                                    final String? savedPath = await FilePicker
                                        .platform
                                        .saveFile(
                                          dialogTitle: "Save Work Permit",
                                          fileName: fileName,
                                          bytes: pdfBytes,
                                          type: FileType.custom,
                                          allowedExtensions: [
                                            'pdf',
                                            'jpg',
                                            'png',
                                          ],
                                        );

                                    if (savedPath != null) {
                                      CustomSnackbar.showSuccess(
                                        context,
                                        "File downloaded successfully",
                                      );
                                    }
                                  } catch (e) {}
                                },
                                child: Icon(
                                  HugeIcons.strokeRoundedDownload02,
                                  size: 18,
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.black87,
                                ),
                              ),

                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: () {
                                  if (onFileDelete != null) {
                                    onFileDelete!();
                                  }
                                },
                                child: Icon(
                                  HugeIcons.strokeRoundedDelete03,
                                  size: 18,
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        )
                      : TextSpan(
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
