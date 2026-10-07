import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models.dart';
import '../../../theme.dart';

class TopologyTreeEntry extends StatelessWidget {
  const TopologyTreeEntry({super.key, required this.label, required this.icon, required this.selected, required this.onSelected, this.indent = 0, this.count, this.closed = false});
  final String label;
  final IconData icon;
  final bool selected, closed;
  final int indent;
  final String? count;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) => Focus(
    onKeyEvent: (_, event) {
      if (event is KeyDownEvent && (event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.space)) {
        onSelected();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    },
    child: Semantics(button: true, selected: selected, label: '$label${closed ? ', вход закрыт' : ''}', child: Material(
      color: selected ? GcColors.selected : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(onTap: onSelected, borderRadius: BorderRadius.circular(8), child: Container(
        key: key,
        constraints: const BoxConstraints(minHeight: 44),
        padding: EdgeInsets.only(left: 10 + indent.toDouble(), right: 10),
        child: Row(children: [
          Icon(icon, size: 18, color: GcColors.muted),
          const SizedBox(width: 8),
          Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)),
          if (count != null) Text(count!, style: const TextStyle(color: GcColors.textSecondary)),
          if (closed) const Padding(padding: EdgeInsets.only(left: 6), child: Icon(Icons.lock_outline, size: 16)),
        ]),
      )),
    )),
  );
}

IconData topologyChannelIcon(ChannelKind kind) => kind == ChannelKind.text ? Icons.tag : Icons.volume_up_outlined;
