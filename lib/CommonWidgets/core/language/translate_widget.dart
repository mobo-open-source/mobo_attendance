import 'package:flutter/material.dart';
import 'package:mobo_attendance/CommonWidgets/core/providers/language_provider.dart';
import 'package:provider/provider.dart';

/// Translation helper widget.
///
/// Wraps [Text] with [LanguageProvider] consumer and automatically
/// replaces text with translated value when available.
///
/// Behavior:
/// • If language service is initializing → shows original text
/// • If current language is English → shows original text
/// • Otherwise → tries cached translated value
///
/// Usage:
/// ```dart
/// tr("Hello World")
/// ```
///
/// With style:
/// ```dart
/// tr(
///   "Welcome",
///   style: TextStyle(fontSize: 16),
/// )
/// ```
Widget tr(
  String textValue, {
  TextStyle? style,
  TextAlign? textAlign,
  TextOverflow? overflow,
  bool softWrap = true,
  int? maxLines,
}) {
  return Consumer<LanguageProvider>(
    builder: (context, service, child) {
      /// If language system still loading OR language is English
      /// → No translation needed
      if (service.isInitializing || service.currentCode == 'en') {
        return Text(
          textValue,
          style: style,
          textAlign: textAlign,
          overflow: overflow,
          softWrap: softWrap,
          maxLines: maxLines,
        );
      }

      /// Try to get cached translated value
      /// Fallback → original text
      return Text(
        service.getCached(textValue) ?? textValue,
        style: style,
        textAlign: textAlign,
        overflow: overflow,
        softWrap: softWrap,
        maxLines: maxLines,
      );
    },
  );
}
