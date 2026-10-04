import 'package:flutter/material.dart';

import '../../../theme.dart';

class WorkspaceNavigationTabs extends StatelessWidget {
  const WorkspaceNavigationTabs({
    super.key,
    required this.channelsSelected,
    required this.onChannels,
    required this.onDirectMessages,
  });

  final bool channelsSelected;
  final VoidCallback onChannels;
  final VoidCallback onDirectMessages;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('navigation-tabs'),
    height: 40,
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: GcColors.canvas,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        Expanded(
          child: _NavigationTab(
            key: const ValueKey('navigation-tab-channels'),
            label: 'Каналы',
            selected: channelsSelected,
            onTap: onChannels,
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: _NavigationTab(
            label: 'Личные',
            selected: !channelsSelected,
            onTap: onDirectMessages,
          ),
        ),
      ],
    ),
  );
}

class _NavigationTab extends StatelessWidget {
  const _NavigationTab({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? GcColors.raised : Colors.transparent,
    borderRadius: BorderRadius.circular(6),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: selected ? GcColors.text : GcColors.muted,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    ),
  );
}
