import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../globals.dart';

/// Reusable search bar with an attached filter button.
///
/// Renders a rounded, elevated search field (with a clear button once text
/// is entered) alongside a separate square filter-icon button when
/// [onFilterTap] is provided. If no [controller] is supplied, the widget
/// manages its own internally so text is preserved across parent rebuilds.
class CustomSearchTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String? hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onFilterTap;
  final String? filterTooltip;

  /// Externally owned query (e.g. from a bloc). When provided, the field
  /// shows this text initially and follows later changes to it.
  final String? text;

  const CustomSearchTextField({
    super.key,
    this.controller,
    this.hintText,
    this.onChanged,
    this.onFilterTap,
    this.filterTooltip,
    this.text,
  });

  @override
  State<CustomSearchTextField> createState() => _CustomSearchTextFieldState();
}

class _CustomSearchTextFieldState extends State<CustomSearchTextField> {
  late final TextEditingController _controller;
  bool _ownsController = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      _controller = TextEditingController();
      _ownsController = true;
    }
    if (widget.text != null && _controller.text != widget.text) {
      _controller.text = widget.text!;
    }
    _controller.addListener(_onControllerChange);
  }

  @override
  void didUpdateWidget(covariant CustomSearchTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final text = widget.text;
    if (text != null && text != oldWidget.text && _controller.text != text) {
      _controller.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
  }

  void _onControllerChange() => setState(() {});

  @override
  void dispose() {
    _controller.removeListener(_onControllerChange);
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasText = _controller.text.isNotEmpty;
    final hasFilter = widget.onFilterTap != null;

    final fieldColor = isDark ? const Color(0xFF2A2A2A) : Colors.white;
    final iconColor = isDark ? Colors.grey[400] : Colors.grey[600];
    final textColor = isDark ? Colors.white : const Color(0xFF1E1E1E);
    final shadow = [
      BoxShadow(
        color: Colors.black.withOpacity(0.08),
        blurRadius: 10,
        offset: const Offset(0, 3),
      ),
    ];

    return Row(
      children: [
        Expanded(
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: fieldColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: shadow,
            ),
            child: Row(
              children: [
                const SizedBox(width: 14),
                Icon(Icons.search_rounded, size: 20, color: iconColor),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    cursorColor: AppStyle.primaryColor,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      hintText: widget.hintText ?? 'Search',
                      hintStyle: TextStyle(
                        color: iconColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                      ),
                      suffixIcon: hasText
                          ? IconButton(
                              icon: Icon(
                                Icons.clear_rounded,
                                size: 18,
                                color: iconColor,
                              ),
                              onPressed: () {
                                _controller.clear();
                                widget.onChanged?.call('');
                              },
                            )
                          : null,
                      suffixIconConstraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                    ),
                    onChanged: widget.onChanged,
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
        if (hasFilter) ...[
          const SizedBox(width: 8),
          Tooltip(
            message: widget.filterTooltip ?? 'Filter & Group By',
            child: GestureDetector(
              onTap: widget.onFilterTap,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: fieldColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: shadow,
                ),
                child: Icon(
                  HugeIcons.strokeRoundedFilterHorizontal,
                  color: textColor,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
