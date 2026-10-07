import 'dart:async';
import 'dart:ui' show SemanticsRole;

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../services/api_client.dart';
import '../theme.dart';
import '../widgets/confirmation_dialog.dart';
import '../features/admin/role_permissions/panel.dart';
import '../features/admin/guild_settings/panel.dart';
import '../features/admin/readiness/panel.dart';
import '../features/admin/topology/panel.dart';
import '../features/admin/topology/actions.dart';
import '../features/admin/audit/controller.dart';
import '../features/admin/audit/panel.dart';
import '../features/admin/media_metrics/panel.dart';
import '../features/admin/layout/width_class.dart';
import '../features/admin/members/controller.dart';
import '../features/admin/members/panel.dart';

enum _AdminSection { members, roles, channels, audit, media, guild, readiness }

class AdminScreen extends StatefulWidget {
  const AdminScreen({
    super.key,
    required this.state,
    this.onToggleNavigation,
    this.onClose,
  });

  final AppState state;
  final VoidCallback? onToggleNavigation;
  final VoidCallback? onClose;

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final _rolePermissionsKey = GlobalKey<RolePermissionsPanelState>();
  final _titleFocus = FocusNode(debugLabel: 'admin-screen-title');
  final _categoryName = TextEditingController();
  final _categoryRename = TextEditingController();
  final _channelName = TextEditingController();
  final _channelRename = TextEditingController();
  final _channelDescription = TextEditingController();
  bool _busy = false;
  String? _status;
  String? _error;
  _AdminSection _selectedAdminSection = _AdminSection.members;
  late final AdminMembersController _members;
  late final _auditController = AdminAuditController(
    ({String? before}) => widget.state.api.listAdminAudit(before: before),
  );

  @override
  void initState() {
    super.initState();
    _members = AdminMembersController(widget.state.api);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _titleFocus.requestFocus();
        unawaited(_members.load());
      }
    });
  }

  @override
  void dispose() {
    _titleFocus.dispose();
    _categoryName.dispose();
    _categoryRename.dispose();
    _channelName.dispose();
    _channelRename.dispose();
    _channelDescription.dispose();
    _members.dispose();
    _auditController.dispose();
    super.dispose();
  }

  Future<String?> _createCategory(String name) async {
    setState(() {
      _busy = true;
      _status = null;
      _error = null;
    });
    try {
      await widget.state.api.createCategory(name);
      await widget.state.refreshTopology();
      if (!mounted) return;
      final id = widget.state.topology?.categories.lastOrNull?.id;
      setState(() {
        _status = 'Категория создана. Топология обновлена.';
      });
      return id;
    } catch (cause) {
      await _recoverTopology(cause);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    return null;
  }

  Future<void> _selectSection(_AdminSection section) async {
    if (section == _selectedAdminSection) return;
    final roleEditor = _rolePermissionsKey.currentState;
    if (_selectedAdminSection == _AdminSection.roles &&
        roleEditor != null &&
        !await roleEditor.confirmBeforeLeaving()) {
      return;
    }
    if (!mounted) return;
    setState(() => _selectedAdminSection = section);
    if (section == _AdminSection.members && !_members.hasLoadedDirectory) {
      unawaited(_members.load());
    }
    if (section == _AdminSection.audit &&
        _auditController.events.isEmpty &&
        !_auditController.isLoading) {
      unawaited(_auditController.load());
    }

  }

  Future<void> _closeAdminPanel() async {
    final roleEditor = _rolePermissionsKey.currentState;
    if (roleEditor != null && !await roleEditor.confirmBeforeLeaving()) return;
    if (!mounted) return;
    (widget.onClose ??
            () => widget.state.toggleWorkspacePanel(WorkspacePanel.none))
        .call();
  }

  Widget _adminSectionTab(String label, _AdminSection section) {
    final selected = _selectedAdminSection == section;
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

  Future<void> _createChannel(String categoryId, int revision, String name, ChannelKind kind) async {
    if (!await _validateTopologyRevision(revision)) return;
    if (_currentCategory(categoryId) == null) {
      await _recoverStaleTopology();
      return;
    }
    setState(() {
      _busy = true;
      _status = null;
      _error = null;
    });
    try {
      await widget.state.api.createChannel(
        categoryId: categoryId,
        name: name,
        kind: kind,
      );
      await widget.state.refreshTopology();
      if (!mounted) return;
      setState(() => _status = 'Канал создан. Топология обновлена.');
    } catch (cause) {
      await _recoverTopology(cause);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _renameCategory(ChannelCategory category, int revision, String name) async {
    if (!await _validateTopologyRevision(revision)) return;
    final current = _currentCategory(category.id);
    if (current == null) return _recoverStaleTopology();
    await _mutate(
      'Категория переименована. Топология обновлена.',
      () => widget.state.api.renameCategory(
        categoryId: current.id,
        name: name,
        expectedRevision: revision,
      ),
      revisionBound: true,
    );
  }

  Future<void> _renameChannel(GuildChannel channel, int revision, String name) async {
    if (!await _validateTopologyRevision(revision)) return;
    final current = _currentChannel(channel.id);
    if (current == null) return _recoverStaleTopology();
    await _mutate(
      'Канал переименован. Топология обновлена.',
      () => widget.state.api.renameChannel(
        channelId: current.id,
        name: name,
        expectedRevision: revision,
      ),
      revisionBound: true,
    );
  }

  Future<void> _saveChannelDescription(GuildChannel channel, int revision, String description) async {
    if (!await _validateTopologyRevision(revision)) return;
    final current = _currentChannel(channel.id);
    if (current == null) return _recoverStaleTopology();
    await _mutate(
      'Описание канала сохранено. Топология обновлена.',
      () => widget.state.api.updateChannelDescription(
        channelId: current.id,
        description: description,
        expectedRevision: revision,
      ),
      revisionBound: true,
    );
  }

  Future<void> _deleteCategory(ChannelCategory category, int revision) async {
    if (!await _validateTopologyRevision(revision)) return;
    final current = _currentCategory(category.id);
    if (current == null) return _recoverStaleTopology();
    if (current.channels.isNotEmpty) return;
    final approved = await showConfirmationDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить категорию?'),
        content: Text('Удалить пустую категорию «${current.name}»?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          FilledButton.tonal(onPressed: () => Navigator.pop(context, true), child: const Text('Удалить')),
        ],
      ),
    );
    if (approved != true || !await _validateTopologyRevision(revision)) return;
    final latest = _currentCategory(category.id);
    if (latest == null) return _recoverStaleTopology();
    if (latest.channels.isNotEmpty) return;
    await _mutate('Пустая категория удалена. Топология обновлена.', () => widget.state.api.deleteEmptyCategory(categoryId: latest.id, expectedRevision: revision), revisionBound: true);
  }

  Future<void> _reorderCategory(String categoryId, int revision, int direction) async {
    if (!await _validateTopologyRevision(revision)) return;
    final topology = widget.state.topology;
    if (topology == null) return _recoverStaleTopology();
    final index = topology.categories.indexWhere((item) => item.id == categoryId);
    final target = index + direction;
    if (index < 0 || target < 0 || target >= topology.categories.length) return;
    final ids = topology.categories.map((item) => item.id).toList();
    final moved = ids[index];
    ids[index] = ids[target];
    ids[target] = moved;
    await _mutate('Порядок категорий сохранён. Топология обновлена.', () => widget.state.api.reorderCategories(categoryIds: ids, expectedRevision: revision), revisionBound: true);
  }

  Future<void> _reorderChannel(String categoryId, GuildChannel channel, int revision, int direction) async {
    if (!await _validateTopologyRevision(revision)) return;
    final topology = widget.state.topology;
    final category = _currentCategory(categoryId);
    if (topology == null || category == null) return _recoverStaleTopology();
    final index = category.channels.indexWhere((item) => item.id == channel.id);
    final target = index + direction;
    if (index < 0 || target < 0 || target >= category.channels.length) return;
    final ids = category.channels.map((item) => item.id).toList();
    final moved = ids[index];
    ids[index] = ids[target];
    ids[target] = moved;
    await _mutate('Порядок каналов сохранён. Топология обновлена.', () => widget.state.api.reorderChannels(categoryId: category.id, channelIds: ids, expectedRevision: revision), revisionBound: true);
  }

  Future<void> _moveChannel(GuildChannel channel, int revision, String targetId) async {
    if (!await _validateTopologyRevision(revision)) return;
    final topology = widget.state.topology;
    final current = _currentChannel(channel.id);
    final target = _currentCategory(targetId);
    if (topology == null || current == null || target == null) return _recoverStaleTopology();
    final source = topology.categories.where((category) => category.channels.any((item) => item.id == current.id)).firstOrNull;
    if (source == null || source.id == target.id) return;
    await _mutate('Канал перенесён. Топология обновлена.', () => widget.state.api.moveChannel(channelId: current.id, categoryId: target.id, expectedRevision: revision), revisionBound: true);
  }

  Future<void> _archiveTextChannel(GuildChannel channel, int revision) async {
    if (!await _validateTopologyRevision(revision)) return;
    final current = _currentChannel(channel.id);
    if (current == null || current.kind != ChannelKind.text) return _recoverStaleTopology();
    final approved = await showConfirmationDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Подтверждение архивации'),
        content: Text('Архивировать текстовый канал «${current.name}»? История сообщений сохранится, канал исчезнет из навигации.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          FilledButton.tonal(onPressed: () => Navigator.pop(context, true), child: const Text('Архивировать канал')),
        ],
      ),
    );
    if (approved != true || !await _validateTopologyRevision(revision)) return;
    final latest = _currentChannel(channel.id);
    if (latest == null || latest.kind != ChannelKind.text) return _recoverStaleTopology();
    await _mutate('Канал архивирован. Топология обновлена.', () => widget.state.api.archiveTextChannel(channelId: latest.id, expectedRevision: revision), revisionBound: true);
  }

  Future<void> _closeVoiceAdmission(GuildChannel channel, int revision) async {
    if (!await _validateTopologyRevision(revision)) return;
    final current = _currentChannel(channel.id);
    if (current == null || current.kind != ChannelKind.voice || current.admissionClosed) return;
    final approved = await showConfirmationDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Подтверждение закрытия'),
        content: Text('Закрыть вход в голосовой канал «${current.name}»? Участникам будет отправлена причина; отзыв media-доступа в SFU может занять время.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          FilledButton.tonal(onPressed: () => Navigator.pop(context, true), child: const Text('Закрыть вход')),
        ],
      ),
    );
    if (approved != true || !await _validateTopologyRevision(revision)) return;
    final latest = _currentChannel(channel.id);
    if (latest == null || latest.kind != ChannelKind.voice || latest.admissionClosed) return _recoverStaleTopology();
    await _mutate('Вход закрыт. Отзыв media-доступа в SFU ещё подтверждается; число отозванных leases не подтверждает отключение участников.', () async {
      await widget.state.api.closeVoiceAdmission(channelId: latest.id, expectedRevision: revision);
    }, revisionBound: true);
  }

  ChannelCategory? _currentCategory(String id) => widget.state.topology?.categories.where((item) => item.id == id).firstOrNull;
  GuildChannel? _currentChannel(String id) => widget.state.topology?.categories.expand((item) => item.channels).where((item) => item.id == id).firstOrNull;
  Future<bool> _validateTopologyRevision(int revision) async {
    if (widget.state.topology?.revision == revision) return true;
    await _recoverStaleTopology();
    return false;
  }
  Future<void> _recoverStaleTopology() => _recoverTopology(const ApiFailure('Устаревшая топология', status: 409), revisionBound: true);

  Future<void> _mutate(
    String success,
    Future<void> Function() mutation, {
    bool revisionBound = false,
  }) async {
    setState(() {
      _busy = true;
      _status = null;
      _error = null;
    });
    try {
      await mutation();
      await widget.state.refreshTopology();
      if (!mounted) return;
      setState(() => _status = success);
    } catch (cause) {
      await _recoverTopology(cause, revisionBound: revisionBound);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _recoverTopology(
    Object cause, {
    bool revisionBound = false,
  }) async {
    await widget.state.refreshTopology();
    if (!mounted) return;
    setState(() {
      _error = revisionBound && cause is ApiFailure && cause.status == 409
          ? 'Топология изменилась. Список обновлён — проверьте выбор и повторите действие.'
          : cause is ApiFailure && cause.status == 403
          ? 'Недостаточно прав для управления каналами.'
          : cause.toString().replaceFirst('Exception: ', '');
    });
  }

  double get _adminContentInset =>
      adminWidthClassFor(MediaQuery.sizeOf(context).width).isCompact ? 0 : 24;

  EdgeInsets get _adminSectionHeaderPadding =>
      EdgeInsets.fromLTRB(_adminContentInset, 0, _adminContentInset, 12);

  EdgeInsets get _adminSectionListPadding =>
      EdgeInsets.fromLTRB(_adminContentInset, 0, _adminContentInset, 24);

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < GcLayout.mobileBreakpoint;
    final categories =
        widget.state.topology?.categories ?? const <ChannelCategory>[];
    return Material(
      color: GcColors.content,
      child: Column(
        children: [
          _AdminWorkspaceHeader(
            compact: compact,
            titleFocus: _titleFocus,
            onToggleNavigation: widget.onToggleNavigation,
            onClose: () => unawaited(_closeAdminPanel()),
          ),
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 880),
                child: SizedBox(
                  key: const ValueKey('admin-content-panel'),
                  width: double.infinity,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      compact ? 16 : 0,
                      compact ? 24 : 32,
                      compact ? 16 : 0,
                      0,
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 24),
                          child: SizedBox(
                            width: double.infinity,
                            child: DecoratedBox(
                              decoration: const BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: GcColors.borderSubtle,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: SingleChildScrollView(
                                      key: const ValueKey(
                                        'admin-section-tabs-scroll',
                                      ),
                                      scrollDirection: Axis.horizontal,
                                      child: Semantics(
                                        key: const ValueKey(
                                          'admin-section-tabs-semantics',
                                        ),
                                        container: true,
                                        explicitChildNodes: true,
                                        role: SemanticsRole.tabBar,
                                        label: 'Разделы администрирования',
                                        child: Row(
                                          children: [
                                            _adminSectionTab(
                                              'Гильдия',
                                              _AdminSection.guild,
                                            ),
                                            _adminSectionTab(
                                              'Участники',
                                              _AdminSection.members,
                                            ),
                                            if (MediaQuery.sizeOf(context)
                                                    .width >
                                                1023)
                                              const SizedBox(width: 8),
                                            _adminSectionTab(
                                              'Роли',
                                              _AdminSection.roles,
                                            ),
                                            if (MediaQuery.sizeOf(context)
                                                    .width >
                                                1023)
                                              const SizedBox(width: 8),
                                            _adminSectionTab(
                                              'Каналы',
                                              _AdminSection.channels,
                                            ),
                                            if (MediaQuery.sizeOf(context)
                                                    .width >
                                                1023)
                                              const SizedBox(width: 8),
                                            _adminSectionTab(
                                              'Аудит',
                                              _AdminSection.audit,
                                            ),
                                            if (MediaQuery.sizeOf(context)
                                                    .width >
                                                1023)
                                              const SizedBox(width: 8),
                                            _adminSectionTab(
                                              'Медиа',
                                              _AdminSection.media,
                                            ),
                                            _adminSectionTab(
                                              MediaQuery.sizeOf(context).width <
                                                      600
                                                  ? 'Статус'
                                                  : 'Готовность',
                                              _AdminSection.readiness,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (_selectedAdminSection ==
                                      _AdminSection.channels)
                                    IconButton(
                                      tooltip: 'Обновить список каналов',
                                      onPressed: _busy
                                          ? null
                                          : widget.state.refreshTopology,
                                      icon: const Icon(Icons.refresh),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: _selectedAdminSection == _AdminSection.guild
                              ? AdminGuildSettings(
                                  api: widget.state.api,
                                  channels:
                                      widget.state.topology?.categories
                                          .expand(
                                            (category) => category.channels,
                                          )
                                          .toList() ??
                                      [],
                                  onSaved: widget.state.guildProfile.refresh,
                                )
                              : _selectedAdminSection == _AdminSection.roles
                              ? RolePermissionsPanel(
                                  key: _rolePermissionsKey,
                                  api: widget.state.api,
                                  onSaved: widget.state.permissions.refresh,
                                )
                              : _selectedAdminSection == _AdminSection.audit
                              ? _buildAuditPanel()
                              : _selectedAdminSection == _AdminSection.media
                              ? AdminMediaMetricsPanel(api: widget.state.api)
                              : _selectedAdminSection == _AdminSection.readiness
                              ? AdminReadinessPanel(api: widget.state.api)
                              : _selectedAdminSection == _AdminSection.members
                              ? _buildMembersPanel()
                              : AdminTopologyPanel(
                                  categories: categories,
                                  revision: widget.state.topology?.revision ?? 0,
                                  busy: _busy,
                                  status: _status,
                                  error: _error,
                                  actions: TopologyActions(
                                    createCategory: _createCategory,
                                    createChannel: _createChannel,
                                    renameCategory: _renameCategory,
                                    deleteCategory: _deleteCategory,
                                    reorderCategory: _reorderCategory,
                                    renameChannel: _renameChannel,
                                    saveDescription: _saveChannelDescription,
                                    moveChannel: _moveChannel,
                                    reorderChannel: _reorderChannel,
                                    archiveTextChannel: _archiveTextChannel,
                                    closeVoiceAdmission: _closeVoiceAdmission,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuditPanel() =>
      AdminAuditPanel(controller: _auditController);

  Widget _buildMembersPanel() => AdminMembersPanel(
    controller: _members,
    currentAccountId: widget.state.user?.accountId,
    voiceParticipantIds: _voiceParticipantIds,
  );

  Set<String> get _voiceParticipantIds {
    if (widget.state.voiceChannel == null) return const {};
    final participants = widget.state.room?.remoteParticipants.values;
    if (participants == null) return const {};
    return participants
        .map((participant) => participant.metadata)
        .whereType<String>()
        .where((metadata) => metadata.startsWith('account:'))
        .map((metadata) => metadata.substring('account:'.length))
        .toSet();
  }


}

class _AdminWorkspaceHeader extends StatelessWidget {
  const _AdminWorkspaceHeader({
    required this.compact,
    required this.titleFocus,
    required this.onToggleNavigation,
    required this.onClose,
  });

  final bool compact;
  final FocusNode titleFocus;
  final VoidCallback? onToggleNavigation;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final buttonConstraints = BoxConstraints.tightFor(
      width: compact ? 44 : 36,
      height: compact ? 44 : 36,
    );
    return SizedBox(
      key: const ValueKey('admin-workspace-header'),
      height: compact ? 56 : 64,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: GcColors.borderSubtle)),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 24),
          child: Row(
            children: [
              if (compact && onToggleNavigation != null) ...[
                IconButton(
                  key: const ValueKey('admin-workspace-nav-toggle'),
                  tooltip: 'Открыть навигацию',
                  constraints: buttonConstraints,
                  padding: EdgeInsets.zero,
                  style: IconButton.styleFrom(
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    fixedSize: Size.square(compact ? 44 : 36),
                    padding: EdgeInsets.zero,
                  ),
                  visualDensity: VisualDensity.compact,
                  onPressed: onToggleNavigation,
                  icon: const Icon(Icons.menu),
                ),
                const SizedBox(width: 8),
              ],
              const Icon(
                Icons.admin_panel_settings_outlined,
                color: GcColors.muted,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Focus(
                  key: const ValueKey('admin-screen-title-focus'),
                  focusNode: titleFocus,
                  child: Semantics(
                    key: const ValueKey('admin-screen-title'),
                    header: true,
                    child: const Text(
                      'Администрирование',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                key: const ValueKey('admin-workspace-close'),
                tooltip: 'Закрыть администрирование',
                constraints: buttonConstraints,
                padding: EdgeInsets.zero,
                style: IconButton.styleFrom(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  fixedSize: Size.square(compact ? 44 : 36),
                  padding: EdgeInsets.zero,
                ),
                visualDensity: VisualDensity.compact,
                onPressed: onClose,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
