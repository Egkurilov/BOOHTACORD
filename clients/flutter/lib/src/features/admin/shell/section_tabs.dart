import 'dart:ui' show SemanticsRole;

import 'package:flutter/material.dart';

import '../../../theme.dart';

enum AdminSection { members, roles, channels, audit, media, guild, readiness }

/// The admin tab strip owns tab semantics and responsive spacing while the
/// screen retains selection/loading state. This prevents feature panels from
/// having to know anything about the surrounding workspace chrome.
class AdminSectionTabs extends StatelessWidget {
  const AdminSectionTabs({
    super.key,
    required this.selectedSection,
    required this.onSelected,
    required this.compactLabel,
    required this.wideSpacing,
    required this.channelsSelected,
    required this.onRefreshChannels,
    required this.refreshDisabled,
  });

  final AdminSection selectedSection;
  final ValueChanged<AdminSection> onSelected;
  final bool compactLabel;
  final bool wideSpacing;
  final bool channelsSelected;
  final VoidCallback? onRefreshChannels;
  final bool refreshDisabled;

  Widget _tab(String label, AdminSection section) {
    final selected = selectedSection == section;
    return Semantics(
      key: ValueKey('admin-section-tab-${section.name}'),
      button: true,
      selected: selected,
      role: SemanticsRole.tab,
      onTap: () => onSelected(section),
      child: ExcludeSemantics(
        child: InkWell(
          onTap: () => onSelected(section),
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
              label,
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
    );
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: GcColors.borderSubtle)),
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              key: const ValueKey('admin-section-tabs-scroll'),
              scrollDirection: Axis.horizontal,
              child: Semantics(
                key: const ValueKey('admin-section-tabs-semantics'),
                container: true,
                explicitChildNodes: true,
                role: SemanticsRole.tabBar,
                label: 'Разделы администрирования',
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _tab('Гильдия', AdminSection.guild),
                    _tab('Участники', AdminSection.members),
                    if (wideSpacing) const SizedBox(width: 8),
                    _tab('Роли', AdminSection.roles),
                    if (wideSpacing) const SizedBox(width: 8),
                    _tab('Каналы', AdminSection.channels),
                    if (wideSpacing) const SizedBox(width: 8),
                    _tab('Аудит', AdminSection.audit),
                    if (wideSpacing) const SizedBox(width: 8),
                    _tab('Медиа', AdminSection.media),
                    if (wideSpacing) const SizedBox(width: 8),
                    _tab(
                      compactLabel ? 'Статус' : 'Готовность',
                      AdminSection.readiness,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (channelsSelected)
            IconButton(
              tooltip: 'Обновить список каналов',
              onPressed: refreshDisabled ? null : onRefreshChannels,
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
    ),
  );
}
