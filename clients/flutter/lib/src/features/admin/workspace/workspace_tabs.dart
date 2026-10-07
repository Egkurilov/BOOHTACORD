part of 'workspace.dart';

mixin _WorkspaceTabs on _AdminWorkspaceBase {
  Widget _buildNavigation(BuildContext context, double width) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: SizedBox(
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
                      _tab('Гильдия', AdminWorkspaceSection.guild),
                      _tab('Участники', AdminWorkspaceSection.members),
                      if (width > 1023) const SizedBox(width: 8),
                      _tab('Роли', AdminWorkspaceSection.roles),
                      if (width > 1023) const SizedBox(width: 8),
                      _tab('Каналы', AdminWorkspaceSection.channels),
                      if (width > 1023) const SizedBox(width: 8),
                      _tab('Аудит', AdminWorkspaceSection.audit),
                      if (width > 1023) const SizedBox(width: 8),
                      _tab('Медиа', AdminWorkspaceSection.media),
                      if (width > 1023) const SizedBox(width: 8),
                      _tab(
                        width < 600 ? 'Статус' : 'Готовность',
                        AdminWorkspaceSection.readiness,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_selected == AdminWorkspaceSection.channels)
              AnimatedBuilder(
                animation: _topology,
                builder: (context, _) => IconButton(
                  tooltip: 'Обновить список каналов',
                  onPressed: _topology.busy ? null : widget.ports.refreshTopology,
                  icon: const Icon(Icons.refresh),
                ),
              ),
          ],
        ),
      ),
    ),
  );

  Widget _tab(String label, AdminWorkspaceSection section) {
    final selected = _selected == section;
    return Semantics(
      key: ValueKey('admin-section-tab-${section.name}'),
      button: true,
      selected: selected,
      role: SemanticsRole.tab,
      onTap: () => unawaited(_selectSection(section)),
      child: ExcludeSemantics(
        child: InkWell(
          onTap: () => unawaited(_selectSection(section)),
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
}
