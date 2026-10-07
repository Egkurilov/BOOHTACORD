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
import '../features/admin/audit/filter.dart';
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

class _AdminScreenState extends State<AdminScreen> with WidgetsBindingObserver {
  final _rolePermissionsKey = GlobalKey<RolePermissionsPanelState>();
  final _titleFocus = FocusNode(debugLabel: 'admin-screen-title');
  final _categoryName = TextEditingController();
  final _categoryRename = TextEditingController();
  final _channelName = TextEditingController();
  final _channelRename = TextEditingController();
  final _channelDescription = TextEditingController();
  final _auditActor = TextEditingController();
  bool _busy = false;
  String? _status;
  String? _error;
  _AdminSection _selectedAdminSection = _AdminSection.members;
  late final AdminMembersController _members;
  List<AdminAuditEvent> _auditEvents = const [];
  String? _auditCursor;
  bool _auditLoading = false;
  String? _auditError;
  AdminAuditScope _auditScope = AdminAuditScope.all;
  String? _auditEventType;
  DateTime? _auditFrom;
  DateTime? _auditTo;
  Timer? _mediaRefreshTimer;
  bool _mediaLoading = false;
  List<AdminScreenSample> _mediaSamples = const [];
  String? _mediaError;
  DateTime? _mediaLastSuccessfulAt;
  DateTime? _mediaLastSeenAt;

  @override
  void initState() {
    super.initState();
    _members = AdminMembersController(widget.state.api);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _titleFocus.requestFocus();
        unawaited(_members.load());
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _mediaRefreshTimer?.cancel();
    _titleFocus.dispose();
    _categoryName.dispose();
    _categoryRename.dispose();
    _channelName.dispose();
    _channelRename.dispose();
    _channelDescription.dispose();
    _members.dispose();
    _auditActor.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _selectedAdminSection == _AdminSection.media) {
      unawaited(_loadMediaMetrics());
    }
  }

  Future<void> _loadMediaMetrics() async {
    if (_mediaLoading) return;
    setState(() {
      _mediaLoading = true;
      _mediaError = null;
    });
    try {
      final samples = await widget.state.api.listAdminScreenMetrics();
      if (!mounted) return;
      final latest = samples
          .map((sample) => sample.sampledAtUtc)
          .fold<DateTime?>(null, (current, value) {
            if (current == null || value.isAfter(current)) return value;
            return current;
          });
      setState(() {
        _mediaSamples = samples;
        _mediaLastSuccessfulAt = DateTime.now().toUtc();
        _mediaLastSeenAt = latest;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _mediaError = 'Не удалось загрузить показатели.');
    } finally {
      if (mounted) setState(() => _mediaLoading = false);
    }
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

  Future<void> _loadAudit({String? before}) async {
    if (_auditLoading) return;
    setState(() {
      _auditLoading = true;
      _auditError = null;
    });
    try {
      final page = await widget.state.api.listAdminAudit(before: before);
      if (!mounted) return;
      setState(() {
        _auditEvents = before == null
            ? page.events
            : [..._auditEvents, ...page.events];
        _auditCursor = page.nextCursor;
      });
    } catch (cause) {
      if (!mounted) return;
      setState(() => _auditError = cause.toString());
    } finally {
      if (mounted) setState(() => _auditLoading = false);
    }
  }

  Future<void> _pickAuditDate({required bool from}) async {
    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDate: (from ? _auditFrom : _auditTo) ?? DateTime.now(),
    );
    if (!mounted || selected == null) return;
    setState(() {
      if (from) {
        _auditFrom = DateTime(selected.year, selected.month, selected.day);
      } else {
        _auditTo = DateTime(
          selected.year,
          selected.month,
          selected.day,
          23,
          59,
          59,
          999,
        );
      }
    });
  }

  AdminAuditFilters get _auditFilters => AdminAuditFilters(
    scope: _auditScope,
    from: _auditFrom,
    to: _auditTo,
    eventType: _auditEventType,
    actor: _auditActor.text,
  );

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
    _mediaRefreshTimer?.cancel();
    _mediaRefreshTimer = null;
    if (section == _AdminSection.members && !_members.hasLoadedDirectory) {
      unawaited(_members.load());
    }
    if (section == _AdminSection.audit && _auditEvents.isEmpty) {
      _loadAudit();
    }
    if (section == _AdminSection.media) {
      unawaited(_loadMediaMetrics());
      _mediaRefreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (WidgetsBinding.instance.lifecycleState ==
            AppLifecycleState.resumed) {
          unawaited(_loadMediaMetrics());
        }
      });
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
                              ? _buildMediaPanel()
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

  Widget _buildMediaPanel() => Column(
    children: [
      Padding(
        padding: _adminSectionHeaderPadding,
        child: Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Показатели трансляций',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    'Последние 60 секунд · без имён и идентификаторов участников',
                    style: TextStyle(
                      color: GcColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: _mediaLoading ? null : _loadMediaMetrics,
              icon: const Icon(Icons.refresh),
              label: const Text('Обновить'),
            ),
          ],
        ),
      ),
      Expanded(
        child: ListView(
          padding: _adminSectionListPadding,
          children: [
            Text(
              'Сравните размер кадра и FPS отправки, приёма и показа: так проще найти участок потери разрешения или кадров. Данные сообщают сами клиенты; они не подтверждают содержимое кадра или аппаратный профиль.',
              style: const TextStyle(
                color: GcColors.textSecondary,
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 12),
            _mediaFreshnessSummary,
            const SizedBox(height: 12),
            if (_mediaLoading && _mediaSamples.isEmpty && _mediaError == null)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_mediaError != null)
              Semantics(
                liveRegion: true,
                child: Text(
                  _mediaError!,
                  style: const TextStyle(color: GcColors.danger),
                ),
              )
            else if (_mediaSamples.isEmpty)
              Semantics(
                liveRegion: true,
                child: Text(
                  'Свежих показателей пока нет. Откройте демонстрацию у зрителя.',
                ),
              )
            else ...[
              if (_mediaLoading) const LinearProgressIndicator(minHeight: 2),
              for (final sample in _mediaSamples) _mediaSampleCard(sample),
            ],
          ],
        ),
      ),
    ],
  );

  Widget get _mediaFreshnessSummary {
    final lastSeen = _mediaLastSeenAt;
    final age = lastSeen == null
        ? null
        : DateTime.now().toUtc().difference(lastSeen).inSeconds;
    final state = _mediaError != null
        ? 'Ошибка обновления'
        : _mediaSamples.isEmpty
        ? 'Пусто'
        : age != null && age > 15
        ? 'Устарело'
        : 'Свежие данные';
    return Semantics(
      liveRegion: true,
      child: Text(
        'Состояние: $state · свежих образцов: ${_mediaSamples.length} · последнее успешное обновление: ${_mediaLastSuccessfulAt == null ? 'нет' : _auditDate(_mediaLastSuccessfulAt!)}',
        style: TextStyle(
          color: state == 'Свежие данные' ? GcColors.success : GcColors.warning,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _mediaSampleCard(AdminScreenSample sample) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: GcColors.surface,
      border: Border.all(color: GcColors.border),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${_screenPlatformLabel(sample.platform)} · ${sample.direction == 'sender' ? 'отправка' : 'приём'}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              TimeOfDay.fromDateTime(sample.sampledAtUtc.toLocal())
                  .format(context),
              style: const TextStyle(
                color: GcColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _mediaStage(
              'Отправка',
              sample.encodedFps,
              sample.direction == 'sender',
            ),
            _mediaStage(
              'Приём',
              sample.decodedFps,
              sample.direction == 'receiver',
            ),
            _mediaStage(
              'Декодирование',
              sample.decodedFps,
              sample.direction == 'receiver',
            ),
            _mediaStage(
              'Показ',
              sample.presentedFps,
              sample.presentedFps != null,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 18,
          runSpacing: 8,
          children: [
            _mediaMetric('Состояние', _screenStateLabel(sample.state)),
            _mediaMetric(
              'Размер кадра',
              sample.frameWidth == null
                  ? 'Нет данных'
                  : '${sample.frameWidth} × ${sample.frameHeight}',
            ),
            _mediaMetric('Отправлено', _mediaValue(sample.encodedFps, 'FPS')),
            _mediaMetric('Декодировано', _mediaValue(sample.decodedFps, 'FPS')),
            _mediaMetric('Показано', _mediaValue(sample.presentedFps, 'FPS')),
            _mediaMetric('Битрейт', _mediaValue(sample.bitrateKbps, 'кбит/с')),
            _mediaMetric(
              'Потеряно пакетов',
              _integerMetric(sample.packetsLost),
            ),
            _mediaMetric(
              'Пропущено кадров',
              _integerMetric(sample.droppedFrames),
            ),
            _mediaMetric('Jitter', _mediaValue(sample.jitterMs, 'мс')),
            _mediaMetric('RTT', _mediaValue(sample.rttMs, 'мс')),
          ],
        ),
        const SizedBox(height: 4),
        Material(
          color: Colors.transparent,
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            title: const Text('Дополнительные измерения'),
            children: [
              Wrap(
                spacing: 18,
                runSpacing: 8,
                children: [
                  _mediaMetric('Состояние', _screenStateLabel(sample.state)),
                  _mediaMetric(
                    'Размер кадра',
                    sample.frameWidth == null
                        ? 'Нет данных'
                        : '${sample.frameWidth} × ${sample.frameHeight}',
                  ),
                  _mediaMetric(
                    'Отправлено',
                    _mediaValue(sample.encodedFps, 'FPS'),
                  ),
                  _mediaMetric(
                    'Декодировано',
                    _mediaValue(sample.decodedFps, 'FPS'),
                  ),
                  _mediaMetric(
                    'Показано',
                    _mediaValue(sample.presentedFps, 'FPS'),
                  ),
                  _mediaMetric(
                    'Битрейт',
                    _mediaValue(sample.bitrateKbps, 'кбит/с'),
                  ),
                  _mediaMetric(
                    'Потеряно пакетов',
                    _integerMetric(sample.packetsLost),
                  ),
                  _mediaMetric(
                    'Пропущено кадров',
                    _integerMetric(sample.droppedFrames),
                  ),
                  _mediaMetric('Jitter', _mediaValue(sample.jitterMs, 'мс')),
                  _mediaMetric('RTT', _mediaValue(sample.rttMs, 'мс')),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _mediaStage(String title, double? fps, bool applicable) => Container(
    constraints: const BoxConstraints(minWidth: 150, maxWidth: 240),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: GcColors.raised,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        Text(applicable ? _mediaValue(fps, 'FPS') : 'Нет данных'),
      ],
    ),
  );

  Widget _mediaMetric(String label, String value) =>
      SizedBox(width: 220, child: Text('$label · $value'));

  String _screenPlatformLabel(String platform) => switch (platform) {
    'ios_web' => 'iPhone/iPad · браузер',
    'android_web' => 'Android · браузер',
    'desktop_web' => 'ПК · браузер',
    'android_native' => 'Android · приложение',
    'desktop_native' => 'ПК · приложение',
    'ios_native' => 'iPhone/iPad · приложение',
    'windows_native' => 'Windows · приложение',
    'macos_native' => 'macOS · приложение',
    _ => 'Неизвестная платформа',
  };

  String _screenStateLabel(String state) => switch (state) {
    'waiting_subscription' => 'Ожидает видеодорожку',
    'waiting_first_frame' => 'Ожидает первый кадр',
    'playing' => 'Воспроизводит',
    'stalled' => 'Кадры остановились',
    _ => 'Неизвестное состояние',
  };

  String _mediaValue(double? value, String unit) {
    if (value == null) return 'Нет данных';
    final formatted = value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
    return '$formatted $unit';
  }

  String _integerMetric(int? value) => value?.toString() ?? 'Нет данных';

  Widget _buildAuditPanel() {
    final filtered = filterAdminAuditEvents(_auditEvents, _auditFilters);
    final grouped = groupAdminAuditByDay(filtered);
    final compact = MediaQuery.sizeOf(context).width < 600;
    final eventTypes =
        _auditEvents.map((event) => event.eventType).toSet().toList()..sort();
    return Column(
      children: [
        Padding(
          padding: _adminSectionHeaderPadding,
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Аудит',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'События управления без содержимого сообщений',
                      style: TextStyle(
                        color: GcColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: _auditLoading ? null : () => _loadAudit(),
                icon: const Icon(Icons.refresh),
                label: const Text('Обновить'),
              ),
            ],
          ),
        ),
        Padding(
          padding: _adminSectionListPadding.copyWith(bottom: 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: compact ? double.infinity : 180,
                child: DropdownButtonFormField<AdminAuditScope>(
                  key: const ValueKey('admin-audit-scope-filter'),
                  isExpanded: true,
                  initialValue: _auditScope,
                  decoration: const InputDecoration(labelText: 'Область'),
                  items: const [
                    DropdownMenuItem(
                      value: AdminAuditScope.all,
                      child: Text('Все события'),
                    ),
                    DropdownMenuItem(
                      value: AdminAuditScope.admin,
                      child: Text('Администрирование'),
                    ),
                    DropdownMenuItem(
                      value: AdminAuditScope.voice,
                      child: Text('Голос'),
                    ),
                  ],
                  onChanged: (value) => setState(
                    () => _auditScope = value ?? AdminAuditScope.all,
                  ),
                ),
              ),
              SizedBox(
                width: compact ? double.infinity : 220,
                child: TextField(
                  controller: _auditActor,
                  decoration: const InputDecoration(labelText: 'Инициатор'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              SizedBox(
                width: compact ? double.infinity : 220,
                child: DropdownButtonFormField<String?>(
                  key: ValueKey('admin-audit-type:$_auditEventType'),
                  isExpanded: true,
                  initialValue: _auditEventType,
                  decoration: const InputDecoration(labelText: 'Тип события'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Все типы'),
                    ),
                    for (final type in eventTypes)
                      DropdownMenuItem<String?>(value: type, child: Text(type)),
                  ],
                  onChanged: (value) => setState(() => _auditEventType = value),
                ),
              ),
              OutlinedButton(
                key: const ValueKey('admin-audit-from-filter'),
                onPressed: () => _pickAuditDate(from: true),
                child: Text(
                  _auditFrom == null
                      ? 'От даты'
                      : 'От ${_auditDate(_auditFrom!)}',
                ),
              ),
              OutlinedButton(
                key: const ValueKey('admin-audit-to-filter'),
                onPressed: () => _pickAuditDate(from: false),
                child: Text(
                  _auditTo == null ? 'До даты' : 'До ${_auditDate(_auditTo!)}',
                ),
              ),
              if (_auditFilters.active)
                TextButton(
                  onPressed: () => setState(() {
                    _auditScope = AdminAuditScope.all;
                    _auditEventType = null;
                    _auditActor.clear();
                    _auditFrom = null;
                    _auditTo = null;
                  }),
                  child: const Text('Сбросить фильтры'),
                ),
            ],
          ),
        ),
        Padding(
          padding: _adminSectionListPadding.copyWith(top: 0, bottom: 8),
          child: Text(
            'Фильтры применяются к ${_auditEvents.length} уже загруженным записям. Для более ранних событий загрузите следующую страницу.',
            style: const TextStyle(color: GcColors.textSecondary, fontSize: 12),
          ),
        ),
        if (_auditLoading && _auditEvents.isEmpty)
          _adminLoadingState('Загружаем аудит…', 'admin-audit-loading')
        else if (!_auditLoading && _auditEvents.isEmpty && _auditError == null)
          const Expanded(child: Center(child: Text('Записей пока нет.')))
        else if (!_auditLoading && filtered.isEmpty && _auditFilters.active)
          const Expanded(
            child: Center(
              child: Text('Среди загруженных записей совпадений нет.'),
            ),
          )
        else
          Expanded(
            child: ListView(
              padding: _adminSectionListPadding,
              children: [
                for (final entry in grouped.entries) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      _auditDayLabel(entry.key),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  for (final event in entry.value) _auditEventRow(event),
                ],
                if (_auditLoading)
                  const Center(child: CircularProgressIndicator()),
                if (_auditCursor != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: _auditLoading
                          ? null
                          : () => _loadAudit(before: _auditCursor),
                      child: const Text('Показать более ранние'),
                    ),
                  ),
                if (_auditError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      _auditError!,
                      style: const TextStyle(color: GcColors.danger),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  String _auditDayLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final day = DateTime(date.year, date.month, date.day);
    if (day == today) return 'Сегодня';
    if (day == yesterday) return 'Вчера';
    return '${day.day.toString().padLeft(2, '0')}.${day.month.toString().padLeft(2, '0')}.${day.year}';
  }

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

  Widget _adminLoadingState(String message, String key) => Expanded(
    child: Center(
      child: Semantics(
        key: ValueKey(key),
        liveRegion: true,
        label: message,
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: GcColors.textSecondary),
        ),
      ),
    ),
  );

  Widget _auditEventRow(AdminAuditEvent event) {
    final actor = _auditAccountLabel(
      event.actorDisplayName,
      event.actorLogin,
      fallback: event.actorUserId == null ? 'Система' : 'Удалённый аккаунт',
    );
    final target = event.targetUserId == null
        ? null
        : _auditAccountLabel(
            event.targetDisplayName,
            event.targetLogin,
            fallback: 'Удалённый аккаунт',
          );
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: GcColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: GcColors.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          title: Text(
            _auditTitle(event.eventType),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text('Инициатор · $actor'),
          trailing: Text(
            _auditDate(event.createdAt),
            style: const TextStyle(color: GcColors.textSecondary, fontSize: 11),
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Тип · ${event.eventType}'),
            ),
            if (target != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Объект · $target'),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Время · ${_auditDate(event.createdAt)}'),
            ),
          ],
        ),
      ),
    );
  }

  String _auditAccountLabel(
    String? displayName,
    String? login, {
    required String fallback,
  }) {
    final name = displayName?.trim();
    final handle = login?.trim();
    if (name?.isNotEmpty == true && handle?.isNotEmpty == true) {
      return '$name (@$handle)';
    }
    if (name?.isNotEmpty == true) return name!;
    if (handle?.isNotEmpty == true) return '@$handle';
    return fallback;
  }

  String _auditDate(DateTime date) {
    final local = date.toLocal();
    return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}.${local.year} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  String _auditTitle(String eventType) => switch (eventType) {
    'ACCOUNT_ADMIN_STATE_UPDATED' => 'Изменены роль или доступ участника',
    'ADMINISTRATOR_RECOVERED' => 'Восстановлен доступ администратора',
    'CATEGORIES_REORDERED' => 'Изменён порядок категорий',
    'CATEGORY_CREATED' => 'Создана категория',
    'CATEGORY_RENAMED' => 'Переименована категория',
    'CHANNEL_CREATED' => 'Создан канал',
    'CHANNEL_MOVED' => 'Канал перемещён',
    'CHANNEL_RENAMED' => 'Канал переименован',
    'CHANNELS_REORDERED' => 'Изменён порядок каналов',
    'EMPTY_CATEGORY_DELETED' => 'Удалена пустая категория',
    'HIDDEN_ATTACHMENT_CLEANUP' => 'Удалён скрытый файл без ссылок',
    'INITIAL_ADMINISTRATOR_CREATED' => 'Создан первый администратор',
    'LAST_ADMINISTRATOR_ACCESS_RECOVERED' =>
      'Восстановлен доступ последнего администратора',
    'PASSWORD_CHANGED' => 'Изменён пароль',
    'PASSWORD_RESET_APPLIED' => 'Завершён сброс пароля',
    'PASSWORD_RESET_CREATED' => 'Создана ссылка сброса пароля',
    'TEXT_CHANNEL_ARCHIVED' => 'Текстовый канал архивирован',
    'TEXT_MESSAGE_DELETED' => 'Удалено сообщение',
    'VOICE_CHANNEL_ADMISSION_CLOSED' => 'Вход в голосовой канал закрыт',
    'VOICE_CHANNEL_ARCHIVED' => 'Голосовой канал архивирован',
    'VOICE_LEASE_ISSUED' => 'Создано голосовое подключение',
    'VOICE_LEASE_KICKED' => 'Участник отключён от голоса',
    'VOICE_LEASE_RELEASED' => 'Голосовое подключение завершено',
    'VOICE_LEASE_TRANSFERRED' => 'Голосовое подключение перенесено',
    _ => 'Другое событие управления',
  };
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
