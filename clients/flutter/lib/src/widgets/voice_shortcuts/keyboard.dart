import 'package:flutter/material.dart';

bool shortcutInputFocused() {
  final context = FocusManager.instance.primaryFocus?.context;
  return context != null &&
      (context.widget is EditableText ||
          context.findAncestorWidgetOfExactType<EditableText>() != null);
}

bool shortcutFocusBlocked() {
  final context = FocusManager.instance.primaryFocus?.context;
  if (context == null) return false;
  bool blocked(Widget widget) =>
      widget is EditableText ||
      widget is Dialog ||
      widget is DropdownButton ||
      widget is FormField ||
      widget is PopupMenuButton ||
      widget is ButtonStyleButton ||
      widget is SwitchListTile;
  if (blocked(context.widget)) return true;
  var result = false;
  context.visitAncestorElements((element) {
    if (blocked(element.widget)) {
      result = true;
      return false;
    }
    return true;
  });
  return result;
}
