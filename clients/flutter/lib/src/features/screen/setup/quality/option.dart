import 'package:flutter/material.dart';

import '../../../../theme.dart';

class QualityOption extends StatelessWidget {
  const QualityOption({
    super.key,
    required this.label,
    required this.selectorKey,
    required this.compact,
    required this.selected,
    required this.values,
    required this.labelFor,
    required this.onSelectionChanged,
  });
  final String label;
  final Key selectorKey;
  final bool compact;
  final int selected;
  final List<int> values;
  final Widget Function(int) labelFor;
  final ValueChanged<Set<int>> onSelectionChanged;
  @override
  Widget build(BuildContext context) {
    final selector = SizedBox(
      key: selectorKey,
      width: double.infinity,
      child: SegmentedButton<int>(
        // On phone-width dialogs, the selected icon competes with short labels
        // (for example, "720p" and "15 FPS") for each segment's limited width.
        // The selected background and semantics still indicate the active value.
        showSelectedIcon: !compact,
        style: ButtonStyle(
          textStyle: WidgetStatePropertyAll(
            TextStyle(fontSize: compact ? 13 : 14),
          ),
          padding: WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: compact ? 6 : 12, vertical: 12),
          ),
        ),
        segments: [
          for (final value in values)
            ButtonSegment(value: value, label: labelFor(value)),
        ],
        selected: {selected},
        onSelectionChanged: onSelectionChanged,
      ),
    );
    final description = Text(
      label,
      style: const TextStyle(color: GcColors.textSecondary, fontSize: 13),
    );
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [description, const SizedBox(height: 6), selector],
      );
    }
    return Row(
      children: [
        SizedBox(width: 104, child: description),
        Expanded(child: selector),
      ],
    );
  }
}
