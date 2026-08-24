import 'package:flutter/material.dart';

/// Moves keyboard focus to [node] — the single canonical way this app
/// advances focus between fields (used by every auto-advance chain).
void advanceFocus(BuildContext context, FocusNode node) {
  FocusScope.of(context).requestFocus(node);
}
