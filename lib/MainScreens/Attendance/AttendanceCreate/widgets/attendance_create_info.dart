import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../../../../CommonWidgets/globals.dart';
import '../../../../CommonWidgets/core/providers/language_provider.dart';

/// A versatile attendance form field widget for Flutter.
///
/// This widget adapts based on the provided parameters:
/// - **Read-only text**: Shown when `isEditing` is false.
/// - **Dropdown selection**: Shown when `dropdownItems` is provided. Supports search and selection callbacks.
/// - **Date-time picker**: Shown when `isDateInput` is true. Returns a formatted date-time string via `onDateChanged`.
/// - **Text or number input**: Shown as default editable field.
///
/// The widget also supports:
/// - Dark/light theme adaptation.
/// - Optional prefix icons.
/// - Custom callbacks for tap events and dropdown/date selection.
class AttendanceCreateInfo extends StatelessWidget {
  final String label;
  final String value;
  final bool isEditing;
  final List<Map<String, dynamic>>? dropdownItems;
  final int? selectedId;
  final Function(Map<String, dynamic>?)? onDropdownChanged;
  final IconData? prefixIcon;
  final VoidCallback? onTapEditing;
  final bool isNumberInput;
  final bool isDateInput;
  final Function(String)? onDateChanged;

  /// Constructor for [AttendanceCreateInfo].
  /// Requires `label`, `value`, and `isEditing`. Other parameters are optional.
  const AttendanceCreateInfo({
    super.key,
    required this.label,
    required this.value,
    required this.isEditing,
    this.dropdownItems,
    this.selectedId,
    this.onDropdownChanged,
    this.prefixIcon,
    this.onTapEditing,
    this.isNumberInput = false,
    this.isDateInput = false,
    this.onDateChanged,
  });

  /// Builds the appropriate widget based on provided parameters:
  /// - Read-only text
  /// - Dropdown search
  /// - Date-time picker
  /// - Editable text/number input
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final translationService = context.read<LanguageProvider>();

    // Read-only display
    if (!isEditing) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: "${translationService.getCached("$label")}: ",
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

    // Dropdown field
    if (dropdownItems != null) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF2F4F6),
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
          key: ValueKey(selectedId),
          popupProps: PopupProps.menu(
            menuProps: MenuProps(
              backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
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
            (e) => e['id'] == selectedId,
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
                      color: isDark ? Colors.white70 : const Color(0xff7F7F7F),
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
              ? '${translationService.getCached('Please select')} $label'
              : null,
        ),
      );
    }

    // Date-time input field
    if (isDateInput) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF2F4F6),
          border: Border.all(color: Colors.transparent, width: 1),
        ),
        child: GestureDetector(
          onTap: () async {
            final DateTime initialDate =
                DateTime.tryParse(value) ?? DateTime.now();

            final DateTime? pickedDate = await showDatePicker(
              context: context,
              initialDate: initialDate,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );

            if (pickedDate == null) return;

            final TimeOfDay? pickedTime = await showTimePicker(
              context: context,
              initialTime: TimeOfDay.fromDateTime(initialDate),
            );

            if (pickedTime == null) return;

            final DateTime combined = DateTime(
              pickedDate.year,
              pickedDate.month,
              pickedDate.day,
              pickedTime.hour,
              pickedTime.minute,
            );

            final String formatted =
                "${combined.year}-${combined.month.toString().padLeft(2, '0')}-${combined.day.toString().padLeft(2, '0')} "
                "${combined.hour.toString().padLeft(2, '0')}:${combined.minute.toString().padLeft(2, '0')}";

            onDateChanged?.call(formatted);
          },
          child: AbsorbPointer(
            child: TextFormField(
              initialValue: value == 'N/A'
                  ? translationService.getCached("Choose Checkout Time")
                  : value,
              style: value == 'N/A'
                  ? TextStyle(
                      fontWeight: FontWeight.w400,
                      color: isDark ? Colors.white54 : Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    )
                  : TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : const Color(0xff000000),
                    ),
              key: ValueKey(value),
              readOnly: true,
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
                  color: isDark ? Colors.white70 : const Color(0xff7F7F7F),
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
        ),
      );
    }

    // Default text/number input
    final String? safeValue = (value == "N/A" || value.isEmpty) ? null : value;
    return TextFormField(
      key: ValueKey(safeValue),
      initialValue: safeValue,
      readOnly: onTapEditing != null,
      onTap: onTapEditing,
      keyboardType: isNumberInput ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        hintText: translationService.getCached(label),
        hintStyle: TextStyle(
          fontWeight: FontWeight.w400,
          color: isDark ? Colors.white54 : Colors.grey[600],
          fontStyle: FontStyle.italic,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        prefixIcon: prefixIcon != null
            ? Icon(
                prefixIcon,
                color: isDark ? Colors.grey[400] : Colors.grey[500],
              )
            : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
    );
  }
}
