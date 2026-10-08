import 'dart:ui' show SemanticsRole;

import 'package:flutter/material.dart';

import '../../../../theme.dart';

class AdminTabControl extends StatefulWidget {
  const AdminTabControl({
    super.key,
    required this.label,
    required this.section,
    required this.selected,
    required this.onSelected,
  });
  final String label, section;
  final bool selected;
  final VoidCallback onSelected;
  @override
  State<AdminTabControl> createState() => _AdminTabControlState();
}

class _AdminTabControlState extends State<AdminTabControl> {
  final focus = FocusNode();
  @override
  void dispose() {
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    return Semantics(
      key: ValueKey('admin-section-tab-${widget.section}'),
      button: true,
      selected: selected,
      role: SemanticsRole.tab,
      onTap: widget.onSelected,
      child: ExcludeSemantics(
        child: DecoratedBox(
          key: const ValueKey('admin-tab-focus-outline'),
          decoration: BoxDecoration(
            border: focus.hasFocus
                ? Border.all(color: GcColors.focus, width: 2)
                : null,
          ),
          child: InkWell(
            focusNode: focus,
            onFocusChange: (_) => setState(() {}),
            onTap: widget.onSelected,
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: selected ? GcColors.accent : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                widget.label,
                style: TextStyle(
                  color: selected ? GcColors.text : GcColors.textSecondary,
                  fontSize: 14,
                  height: 20 / 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
