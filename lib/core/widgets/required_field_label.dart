import 'package:flutter/material.dart';

/// Renders a field label whose trailing '*' (required-field marker) is
/// shown in red, while the rest of the label keeps its normal styling.
///
/// Pass [style] when used as a standalone label (e.g. above a field);
/// leave it null when used as `InputDecoration.label` so it inherits the
/// decorator's own dynamic (focused/error) label styling.
Widget requiredFieldLabel(
  String text, {
  TextStyle? style,
  Color asteriskColor = Colors.red,
}) {
  final trimmed = text.trimRight();
  if (!trimmed.endsWith('*')) {
    return Text(text, style: style);
  }
  final base = trimmed.substring(0, trimmed.length - 1).trimRight();
  return Text.rich(
    TextSpan(
      text: base,
      style: style,
      children: [
        TextSpan(text: ' *', style: TextStyle(color: asteriskColor)),
      ],
    ),
  );
}
