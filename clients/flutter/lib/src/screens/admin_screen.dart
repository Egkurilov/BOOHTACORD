import 'dart:async';
import 'dart:ui' show SemanticsRole;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../models.dart';
import '../services/api_client.dart';
import '../theme.dart';
import '../widgets/confirmation_dialog.dart';
import '../features/admin/role_permissions/panel.dart';
import 'admin_member_filter.dart';
import 'admin_member_filters.dart';

enum _AdminSection { members, roles, channels, audit, media }

class _AdminAccountDraft {
  _AdminAccountDraft({required this.role, required this.blocked});
  String role;
  bool blocked;
}

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
  final _titleFocus = FocusNode(debugLabel: 'admin-screen-title');
  final _categoryName = TextEditingController();
  final _categoryRename = TextEditingController();
  final _channelName = TextEditingController();
  final _channelRename = TextEditingController();
  final _accountSearch = TextEditingController();
  String? _categoryId;
  String? _channelId;
  String? _moveChannelId;
  String? _moveTargetCategoryId;
  String? _archiveChannelId;
  String? _closeVoiceChannelId;
  ChannelKind _channelKind = ChannelKind.voice;
  bool _busy = false;
  String? _status;
  String? _error;
  _AdminSection _selectedAdminSection = _AdminSection.members;
  List<AdminAccount> _adminAccounts = const [];
  String _accountRoleFilter = 'ALL';
  List<AdminAccount> get _visibleAdminAccounts => filterAdminMembers(
    _adminAccounts,
    search: _accountSearch.text,
    role: _accountRoleFilter,
  );
  String? _accountCursor;
  final Map<String, _AdminAccountDraft> _accountDrafts = {};
  final Map<String, FocusNode> _accountSaveFocusNodes = {};
  final Set<String> _busyAccountIds = {};
  bool _accountsLoading = false;
  String? _accountsError;
  String? _accountsStatus;
  AdminPasswordResetLink? _resetLink;
  String? _resetLogin;
  List<AdminAuditEvent> _auditEvents = const [];
  String? _auditCursor;
  bool _auditLoading = false;
  String? _auditError;
  Timer? _mediaRefreshTimer;
  bool _mediaLoading = false;
  List<AdminScreenSample> _mediaSamples = const [];
  String? _mediaError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _titleFocus.requestFocus();
        _loadAccounts();
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
    _accountSearch.dispose();
    for (final focusNode in _accountSaveFocusNodes.values) {
      focusNode.dispose();
    }
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
      setState(() => _mediaSamples = samples);
    } catch (_) {
      if (!mounted) return;
      setState(() => _mediaError = 'Не удалось загрузить показатели.');
    } finally {
      if (mounted) setState(() => _mediaLoading = false);
    }
  }

  Future<void> _createCategory() async {
    setState(() {
      _busy = true;
      _status = null;
      _error = null;
    });
    try {
      await widget.state.api.createCategory(_categoryName.text);
      _categoryName.clear();
      await widget.state.refreshTopology();
      if (!mounted) return;
      setState(() {
        _categoryId = widget.state.topology?.categories.lastOrNull?.id;
        _status = 'Категория создана. Топология обновлена.';
      });
    } catch (cause) {
      await _recoverTopology(cause);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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

  Future<void> _loadAccounts({String? cursor}) async {
    if (_accountsLoading) return;
    setState(() {
      _accountsLoading = true;
      _accountsError = null;
    });
    try {
      final page = await widget.state.api.listAdminAccounts(cursor: cursor);
      if (!mounted) return;
      setState(() {
        _adminAccounts = cursor == null
            ? page.accounts
            : [..._adminAccounts, ...page.accounts];
        _accountCursor = page.nextCursor;
        for (final account in page.accounts) {
          _accountDrafts.putIfAbsent(
            account.accountId,
            () => _AdminAccountDraft(
              role: account.role,
              blocked: account.blocked,
            ),
          );
        }
      });
    } catch (cause) {
      if (mounted) setState(() => _accountsError = cause.toString());
    } finally {
      if (mounted) setState(() => _accountsLoading = false);
    }
  }

  Future<void> _saveAccount(AdminAccount account) async {
    final draft = _accountDrafts[account.accountId];
    if (draft == null || _busyAccountIds.contains(account.accountId)) return;
    setState(() {
      _busyAccountIds.add(account.accountId);
      _accountsStatus = null;
      _accountsError = null;
    });
    try {
      await widget.state.api.updateAdminAccount(
        accountId: account.accountId,
        role: draft.role,
        blocked: draft.blocked,
      );
      if (mounted) {
        setState(
          () => _accountsStatus = 'Изменения для @${account.login} сохранены.',
        );
      }
    } catch (cause) {
      if (mounted) setState(() => _accountsError = cause.toString());
    } finally {
      if (mounted) {
        setState(() => _busyAccountIds.remove(account.accountId));
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final focusNode = _accountSaveFocusNodes[account.accountId];
          if (mounted && focusNode?.context != null) focusNode!.requestFocus();
        });
      }
    }
  }

  Future<void> _createResetLink(AdminAccount account) async {
    setState(() {
      _resetLink = null;
      _resetLogin = null;
      _busyAccountIds.add(account.accountId);
      _accountsError = null;
    });
    try {
      final result = await widget.state.api.createAdminPasswordResetLink(
        account.accountId,
      );
      if (mounted) {
        setState(() {
          _resetLink = result;
          _resetLogin = account.login;
        });
      }
    } catch (cause) {
      if (mounted) setState(() => _accountsError = cause.toString());
    } finally {
      if (mounted) setState(() => _busyAccountIds.remove(account.accountId));
    }
  }

  Future<void> _kickVoiceParticipant(AdminAccount account) async {
    if (_busyAccountIds.contains(account.accountId)) return;
    final confirmed = await showConfirmationDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Отключить от голоса?'),
        content: const Text('Отключить участника от голосового канала?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Отключить'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() {
      _busyAccountIds.add(account.accountId);
      _accountsStatus = null;
      _accountsError = null;
    });
    try {
      final revoked = await widget.state.api.kickAdminVoiceParticipant(
        account.accountId,
      );
      if (mounted) {
        setState(
          () => _accountsStatus = revoked > 0
              ? 'Подключение отозвано.'
              : 'Активное голосовое подключение не найдено.',
        );
      }
    } catch (cause) {
      if (mounted) setState(() => _accountsError = cause.toString());
    } finally {
      if (mounted) setState(() => _busyAccountIds.remove(account.accountId));
    }
  }

  Future<void> _copyResetLink() async {
    final link = _resetLink;
    if (link == null) return;
    try {
      await Clipboard.setData(ClipboardData(text: link.url));
      if (mounted) setState(() => _accountsStatus = 'Ссылка скопирована.');
    } catch (cause) {
      if (mounted) setState(() => _accountsError = cause.toString());
    }
  }

  void _selectSection(_AdminSection section) {
    setState(() => _selectedAdminSection = section);
    _mediaRefreshTimer?.cancel();
    _mediaRefreshTimer = null;
    if (section == _AdminSection.members && _adminAccounts.isEmpty) {
      _loadAccounts();
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

  Widget _adminSectionTab(String label, _AdminSection section) {
    final selected = _selectedAdminSection == section;
    return Semantics(
      key: ValueKey('admin-section-tab-${section.name}'),
      button: true,
      selected: selected,
      role: SemanticsRole.tab,
      onTap: () => _selectSection(section),
      child: ExcludeSemantics(
        child: InkWell(
          onTap: () => _selectSection(section),
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

  Future<void> _createChannel() async {
    final categoryId =
        _categoryId ?? widget.state.topology?.categories.firstOrNull?.id;
    if (categoryId == null) {
      setState(() => _error = 'Сначала создайте категорию.');
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
        name: _channelName.text,
        kind: _channelKind,
      );
      _channelName.clear();
      await widget.state.refreshTopology();
      if (!mounted) return;
      setState(() => _status = 'Канал создан. Топология обновлена.');
    } catch (cause) {
      await _recoverTopology(cause);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _renameCategory(ChannelCategory category) async {
    await _mutate(
      'Категория переименована. Топология обновлена.',
      () => widget.state.api.renameCategory(
        categoryId: category.id,
        name: _categoryRename.text,
        expectedRevision: widget.state.topology!.revision,
      ),
      revisionBound: true,
    );
  }

  Future<void> _renameChannel(GuildChannel channel) async {
    await _mutate(
      'Канал переименован. Топология обновлена.',
      () => widget.state.api.renameChannel(
        channelId: channel.id,
        name: _channelRename.text,
        expectedRevision: widget.state.topology!.revision,
      ),
      revisionBound: true,
    );
  }

  Future<void> _deleteCategory(ChannelCategory category) async {
    final approved = await showConfirmationDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить категорию?'),
        content: Text('Удалить пустую категорию «${category.name}»?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (approved != true) return;
    await _mutate(
      'Пустая категория удалена. Топология обновлена.',
      () => widget.state.api.deleteEmptyCategory(
        categoryId: category.id,
        expectedRevision: widget.state.topology!.revision,
      ),
      revisionBound: true,
    );
  }

  Future<void> _reorderCategory(int direction) async {
    final topology = widget.state.topology;
    if (topology == null || _categoryId == null) return;
    final ids = topology.categories.map((item) => item.id).toList();
    final index = ids.indexOf(_categoryId!);
    final target = index + direction;
    if (index < 0 || target < 0 || target >= ids.length) return;
    final movedId = ids[index];
    ids[index] = ids[target];
    ids[target] = movedId;
    await _mutate(
      'Порядок категорий сохранён. Топология обновлена.',
      () => widget.state.api.reorderCategories(
        categoryIds: ids,
        expectedRevision: topology.revision,
      ),
      revisionBound: true,
    );
  }

  Future<void> _reorderChannel(int direction) async {
    final topology = widget.state.topology;
    final category = topology?.categories
        .where((item) => item.id == _categoryId)
        .firstOrNull;
    if (topology == null || category == null || _channelId == null) return;
    final ids = category.channels.map((item) => item.id).toList();
    final index = ids.indexOf(_channelId!);
    final target = index + direction;
    if (index < 0 || target < 0 || target >= ids.length) return;
    final movedId = ids[index];
    ids[index] = ids[target];
    ids[target] = movedId;
    await _mutate(
      'Порядок каналов сохранён. Топология обновлена.',
      () => widget.state.api.reorderChannels(
        categoryId: category.id,
        channelIds: ids,
        expectedRevision: topology.revision,
      ),
      revisionBound: true,
    );
  }

  Future<void> _moveChannel() async {
    final topology = widget.state.topology;
    if (topology == null ||
        _moveChannelId == null ||
        _moveTargetCategoryId == null) {
      return;
    }
    final source = topology.categories
        .where(
          (category) =>
              category.channels.any((channel) => channel.id == _moveChannelId),
        )
        .firstOrNull;
    if (source == null || source.id == _moveTargetCategoryId) return;
    await _mutate(
      'Канал перенесён. Топология обновлена.',
      () => widget.state.api.moveChannel(
        channelId: _moveChannelId!,
        categoryId: _moveTargetCategoryId!,
        expectedRevision: topology.revision,
      ),
      revisionBound: true,
    );
  }

  Future<void> _archiveTextChannel(List<GuildChannel> channels) async {
    final channel = channels
        .where(
          (item) =>
              item.id == _archiveChannelId && item.kind == ChannelKind.text,
        )
        .firstOrNull;
    final topology = widget.state.topology;
    if (channel == null || topology == null) return;
    final approved = await showConfirmationDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Подтверждение архивации'),
        content: Text(
          'Архивировать текстовый канал «${channel.name}»? История сообщений сохранится, канал исчезнет из навигации.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Архивировать канал'),
          ),
        ],
      ),
    );
    if (approved != true) return;
    await _mutate(
      'Канал архивирован. Топология обновлена.',
      () => widget.state.api.archiveTextChannel(
        channelId: channel.id,
        expectedRevision: topology.revision,
      ),
      revisionBound: true,
    );
  }

  Future<void> _closeVoiceAdmission(List<GuildChannel> channels) async {
    final channel = channels
        .where(
          (item) =>
              item.id == _closeVoiceChannelId && item.kind == ChannelKind.voice,
        )
        .firstOrNull;
    final topology = widget.state.topology;
    if (channel == null || topology == null || channel.admissionClosed) return;
    final approved = await showConfirmationDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Подтверждение закрытия'),
        content: Text(
          'Закрыть вход в голосовой канал «${channel.name}»? Участникам будет отправлена причина; отзыв media-доступа в SFU может занять время.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Закрыть вход'),
          ),
        ],
      ),
    );
    if (approved != true) return;
    await _mutate('Вход закрыт. Отзыв media-доступа в SFU ещё подтверждается; число отозванных leases не подтверждает отключение участников.', () async {
      await widget.state.api.closeVoiceAdmission(
        channelId: channel.id,
        expectedRevision: topology.revision,
      );
    }, revisionBound: true);
  }

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
      MediaQuery.sizeOf(context).width < GcLayout.mobileBreakpoint ? 0 : 24;

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
    final selectedId = categories.any((item) => item.id == _categoryId)
        ? _categoryId
        : categories.firstOrNull?.id;
    final selectedCategory = categories
        .where((item) => item.id == selectedId)
        .firstOrNull;
    final channels = selectedCategory?.channels ?? const <GuildChannel>[];
    final selectedChannel = channels
        .where((item) => item.id == _channelId)
        .firstOrNull;
    final moveSourceCategory = categories
        .where(
          (category) =>
              category.channels.any((channel) => channel.id == _moveChannelId),
        )
        .firstOrNull;
    final allChannels = categories
        .expand((category) => category.channels)
        .toList(growable: false);
    final textChannels = allChannels
        .where((channel) => channel.kind == ChannelKind.text)
        .toList(growable: false);
    final voiceChannels = allChannels
        .where((channel) => channel.kind == ChannelKind.voice)
        .toList(growable: false);
    return Material(
      color: GcColors.content,
      child: Column(
        children: [
          _AdminWorkspaceHeader(
            compact: compact,
            titleFocus: _titleFocus,
            onToggleNavigation: widget.onToggleNavigation,
            onClose:
                widget.onClose ??
                () => widget.state.toggleWorkspacePanel(WorkspacePanel.none),
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
                          child: _selectedAdminSection == _AdminSection.roles
                              ? RolePermissionsPanel(
                                  api: widget.state.api,
                                  onSaved: widget.state.permissions.refresh,
                                )
                              : _selectedAdminSection == _AdminSection.audit
                              ? _buildAuditPanel()
                              : _selectedAdminSection == _AdminSection.media
                              ? _buildMediaPanel()
                              : _selectedAdminSection == _AdminSection.members
                              ? _buildMembersPanel()
                              : ListView(
                                  padding: EdgeInsets.fromLTRB(
                                    _adminContentInset,
                                    0,
                                    _adminContentInset,
                                    24,
                                  ),
                                  children: [
                                    _section(
                                      title: 'Управление каналами',
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          TextField(
                                            controller: _categoryName,
                                            enabled: !_busy,
                                            maxLength: 80,
                                            decoration: const InputDecoration(
                                              labelText: 'Новая категория',
                                            ),
                                            onSubmitted: (_) =>
                                                _createCategory(),
                                          ),
                                          const SizedBox(height: 8),
                                          Align(
                                            alignment: Alignment.centerLeft,
                                            child: FilledButton.tonal(
                                              onPressed: _busy
                                                  ? null
                                                  : _createCategory,
                                              child: const Text(
                                                'Создать категорию',
                                              ),
                                            ),
                                          ),
                                          const Divider(height: 32),
                                          DropdownButtonFormField<String>(
                                            key: ValueKey(selectedId),
                                            initialValue: selectedId,
                                            decoration: const InputDecoration(
                                              labelText: 'Категория',
                                            ),
                                            items: [
                                              for (final category in categories)
                                                DropdownMenuItem(
                                                  value: category.id,
                                                  child: Text(category.name),
                                                ),
                                            ],
                                            onChanged: _busy
                                                ? null
                                                : (value) => setState(() {
                                                    _categoryId = value;
                                                    final category = categories
                                                        .where(
                                                          (item) =>
                                                              item.id == value,
                                                        )
                                                        .firstOrNull;
                                                    _categoryRename.text =
                                                        category?.name ?? '';
                                                    _channelId = null;
                                                    _channelRename.clear();
                                                  }),
                                          ),
                                          if (selectedCategory != null) ...[
                                            TextField(
                                              controller: _categoryRename,
                                              enabled: !_busy,
                                              maxLength: 80,
                                              decoration: const InputDecoration(
                                                labelText:
                                                    'Новое имя категории',
                                              ),
                                            ),
                                            Wrap(
                                              spacing: 8,
                                              children: [
                                                OutlinedButton(
                                                  onPressed: _busy
                                                      ? null
                                                      : () => _renameCategory(
                                                          selectedCategory,
                                                        ),
                                                  child: const Text(
                                                    'Переименовать категорию',
                                                  ),
                                                ),
                                                OutlinedButton(
                                                  onPressed:
                                                      _busy ||
                                                          selectedCategory
                                                              .channels
                                                              .isNotEmpty
                                                      ? null
                                                      : () => _deleteCategory(
                                                          selectedCategory,
                                                        ),
                                                  child: const Text(
                                                    'Удалить пустую категорию',
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Wrap(
                                              spacing: 8,
                                              children: [
                                                OutlinedButton(
                                                  onPressed:
                                                      _busy ||
                                                          categories.indexOf(
                                                                selectedCategory,
                                                              ) ==
                                                              0
                                                      ? null
                                                      : () => _reorderCategory(
                                                          -1,
                                                        ),
                                                  child: const Text(
                                                    'Категорию выше',
                                                  ),
                                                ),
                                                OutlinedButton(
                                                  onPressed:
                                                      _busy ||
                                                          categories.indexOf(
                                                                selectedCategory,
                                                              ) ==
                                                              categories
                                                                      .length -
                                                                  1
                                                      ? null
                                                      : () =>
                                                            _reorderCategory(1),
                                                  child: const Text(
                                                    'Категорию ниже',
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const Divider(height: 32),
                                            DropdownButtonFormField<String>(
                                              key: ValueKey(_channelId),
                                              initialValue:
                                                  channels.any(
                                                    (item) =>
                                                        item.id == _channelId,
                                                  )
                                                  ? _channelId
                                                  : null,
                                              decoration: const InputDecoration(
                                                labelText: 'Канал',
                                              ),
                                              items: [
                                                for (final channel in channels)
                                                  DropdownMenuItem(
                                                    value: channel.id,
                                                    child: Text(channel.name),
                                                  ),
                                              ],
                                              onChanged: _busy
                                                  ? null
                                                  : (value) => setState(() {
                                                      _channelId = value;
                                                      _channelRename.text =
                                                          channels
                                                              .where(
                                                                (item) =>
                                                                    item.id ==
                                                                    value,
                                                              )
                                                              .firstOrNull
                                                              ?.name ??
                                                          '';
                                                    }),
                                            ),
                                            if (selectedChannel != null) ...[
                                              TextField(
                                                controller: _channelRename,
                                                enabled: !_busy,
                                                maxLength: 80,
                                                decoration:
                                                    const InputDecoration(
                                                      labelText:
                                                          'Новое имя канала',
                                                    ),
                                              ),
                                              Align(
                                                alignment: Alignment.centerLeft,
                                                child: OutlinedButton(
                                                  onPressed: _busy
                                                      ? null
                                                      : () => _renameChannel(
                                                          selectedChannel,
                                                        ),
                                                  child: const Text(
                                                    'Переименовать канал',
                                                  ),
                                                ),
                                              ),
                                              Wrap(
                                                spacing: 8,
                                                children: [
                                                  OutlinedButton(
                                                    onPressed:
                                                        _busy ||
                                                            channels.indexOf(
                                                                  selectedChannel,
                                                                ) ==
                                                                0
                                                        ? null
                                                        : () => _reorderChannel(
                                                            -1,
                                                          ),
                                                    child: const Text(
                                                      'Канал выше',
                                                    ),
                                                  ),
                                                  OutlinedButton(
                                                    onPressed:
                                                        _busy ||
                                                            channels.indexOf(
                                                                  selectedChannel,
                                                                ) ==
                                                                channels.length -
                                                                    1
                                                        ? null
                                                        : () => _reorderChannel(
                                                            1,
                                                          ),
                                                    child: const Text(
                                                      'Канал ниже',
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ],
                                          const Divider(height: 32),
                                          TextField(
                                            controller: _channelName,
                                            enabled:
                                                !_busy && categories.isNotEmpty,
                                            maxLength: 80,
                                            decoration: const InputDecoration(
                                              labelText: 'Новый канал',
                                            ),
                                            onSubmitted: (_) =>
                                                _createChannel(),
                                          ),
                                          DropdownButtonFormField<ChannelKind>(
                                            initialValue: _channelKind,
                                            decoration: const InputDecoration(
                                              labelText: 'Тип канала',
                                            ),
                                            items: const [
                                              DropdownMenuItem(
                                                value: ChannelKind.voice,
                                                child: Text('Голосовой'),
                                              ),
                                              DropdownMenuItem(
                                                value: ChannelKind.text,
                                                child: Text('Текстовый'),
                                              ),
                                            ],
                                            onChanged: _busy
                                                ? null
                                                : (value) {
                                                    if (value != null) {
                                                      setState(
                                                        () => _channelKind =
                                                            value,
                                                      );
                                                    }
                                                  },
                                          ),
                                          const SizedBox(height: 12),
                                          Align(
                                            alignment: Alignment.centerLeft,
                                            child: FilledButton(
                                              onPressed:
                                                  _busy || categories.isEmpty
                                                  ? null
                                                  : _createChannel,
                                              child: _busy
                                                  ? const SizedBox.square(
                                                      dimension: 16,
                                                      child:
                                                          CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                          ),
                                                    )
                                                  : const Text('Создать канал'),
                                            ),
                                          ),
                                          if (categories.isNotEmpty) ...[
                                            const Divider(height: 32),
                                            DropdownButtonFormField<String>(
                                              key: ValueKey(
                                                'move-channel:$_moveChannelId',
                                              ),
                                              initialValue:
                                                  categories
                                                      .expand(
                                                        (category) =>
                                                            category.channels,
                                                      )
                                                      .any(
                                                        (channel) =>
                                                            channel.id ==
                                                            _moveChannelId,
                                                      )
                                                  ? _moveChannelId
                                                  : null,
                                              decoration: const InputDecoration(
                                                labelText: 'Перенести канал',
                                              ),
                                              items: [
                                                for (final category
                                                    in categories)
                                                  for (final channel
                                                      in category.channels)
                                                    DropdownMenuItem(
                                                      value: channel.id,
                                                      child: Text(
                                                        '${category.name} · ${channel.name}',
                                                      ),
                                                    ),
                                              ],
                                              onChanged: _busy
                                                  ? null
                                                  : (value) => setState(() {
                                                      _moveChannelId = value;
                                                      _moveTargetCategoryId =
                                                          null;
                                                    }),
                                            ),
                                            DropdownButtonFormField<String>(
                                              key: ValueKey(
                                                'move-target:$_moveTargetCategoryId',
                                              ),
                                              initialValue:
                                                  categories.any(
                                                    (item) =>
                                                        item.id ==
                                                        _moveTargetCategoryId,
                                                  )
                                                  ? _moveTargetCategoryId
                                                  : null,
                                              decoration: const InputDecoration(
                                                labelText: 'В категорию',
                                              ),
                                              items: [
                                                for (final category
                                                    in categories)
                                                  DropdownMenuItem(
                                                    value: category.id,
                                                    child: Text(category.name),
                                                  ),
                                              ],
                                              onChanged: _busy
                                                  ? null
                                                  : (value) => setState(
                                                      () =>
                                                          _moveTargetCategoryId =
                                                              value,
                                                    ),
                                            ),
                                            Align(
                                              alignment: Alignment.centerLeft,
                                              child: OutlinedButton(
                                                onPressed:
                                                    _busy ||
                                                        _moveChannelId ==
                                                            null ||
                                                        _moveTargetCategoryId ==
                                                            null ||
                                                        moveSourceCategory
                                                                ?.id ==
                                                            _moveTargetCategoryId
                                                    ? null
                                                    : _moveChannel,
                                                child: const Text(
                                                  'Перенести канал',
                                                ),
                                              ),
                                            ),
                                          ],
                                          if (textChannels.isNotEmpty) ...[
                                            const Divider(height: 32),
                                            DropdownButtonFormField<String>(
                                              key: ValueKey(
                                                'archive-channel:$_archiveChannelId',
                                              ),
                                              initialValue:
                                                  textChannels.any(
                                                    (channel) =>
                                                        channel.id ==
                                                        _archiveChannelId,
                                                  )
                                                  ? _archiveChannelId
                                                  : null,
                                              decoration: const InputDecoration(
                                                labelText: 'Текстовый канал для архивации',
                                              ),
                                              items: [
                                                for (final channel
                                                    in textChannels)
                                                  DropdownMenuItem(
                                                    value: channel.id,
                                                    child: Text(channel.name),
                                                  ),
                                              ],
                                              onChanged: _busy
                                                  ? null
                                                  : (value) => setState(
                                                      () => _archiveChannelId =
                                                          value,
                                                    ),
                                            ),
                                            Align(
                                              alignment: Alignment.centerLeft,
                                              child: OutlinedButton(
                                                onPressed:
                                                    _busy ||
                                                        _archiveChannelId ==
                                                            null
                                                    ? null
                                                    : () => _archiveTextChannel(
                                                        allChannels,
                                                      ),
                                                child: const Text(
                                                  'Архивировать канал',
                                                ),
                                              ),
                                            ),
                                          ],
                                          if (voiceChannels.any(
                                            (channel) =>
                                                !channel.admissionClosed,
                                          )) ...[
                                            DropdownButtonFormField<String>(
                                              key: ValueKey(
                                                'close-channel:$_closeVoiceChannelId',
                                              ),
                                              initialValue:
                                                  voiceChannels.any(
                                                    (channel) =>
                                                        channel.id ==
                                                        _closeVoiceChannelId,
                                                  )
                                                  ? _closeVoiceChannelId
                                                  : null,
                                              decoration: const InputDecoration(
                                                labelText: 'Голосовой канал для закрытия',
                                              ),
                                              items: [
                                                for (final channel
                                                    in voiceChannels)
                                                  DropdownMenuItem(
                                                    value: channel.id,
                                                    child: Text(
                                                      '${channel.name}${channel.admissionClosed ? ' · вход закрыт' : ''}',
                                                    ),
                                                  ),
                                              ],
                                              onChanged: _busy
                                                  ? null
                                                  : (value) => setState(
                                                      () =>
                                                          _closeVoiceChannelId =
                                                              value,
                                                    ),
                                            ),
                                            Align(
                                              alignment: Alignment.centerLeft,
                                              child: OutlinedButton(
                                                onPressed:
                                                    _busy ||
                                                        _closeVoiceChannelId ==
                                                            null ||
                                                        voiceChannels.any(
                                                          (channel) =>
                                                              channel.id ==
                                                                  _closeVoiceChannelId &&
                                                              channel
                                                                  .admissionClosed,
                                                        )
                                                    ? null
                                                    : () =>
                                                          _closeVoiceAdmission(
                                                            allChannels,
                                                          ),
                                                child: const Text(
                                                  'Закрыть вход',
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    if (_status != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 12),
                                        child: Semantics(
                                          liveRegion: true,
                                          label: _status,
                                          child: Text(
                                            _status!,
                                            style: const TextStyle(
                                              color: GcColors.success,
                                            ),
                                          ),
                                        ),
                                      ),
                                    if (_error != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 12),
                                        child: Semantics(
                                          liveRegion: true,
                                          label: _error,
                                          child: Text(
                                            _error!,
                                            style: const TextStyle(
                                              color: GcColors.danger,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
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

  Widget _section({required String title, required Widget child}) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: GcColors.surface,
      border: Border.all(color: GcColors.border),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );

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

  Widget _buildAuditPanel() => Column(
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
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
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
      if (_auditLoading && _auditEvents.isEmpty)
        _adminLoadingState('Загружаем аудит…', 'admin-audit-loading')
      else if (!_auditLoading && _auditEvents.isEmpty && _auditError == null)
        const Expanded(child: Center(child: Text('Записей пока нет.')))
      else
        Expanded(
          child: ListView(
            padding: _adminSectionListPadding,
            children: [
              for (final event in _auditEvents) _auditEventRow(event),
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

  Widget _buildMembersPanel() => Column(
    children: [
      Padding(
        padding: _adminSectionHeaderPadding,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Участники ${_adminAccounts.length}',
                    key: ValueKey('admin-members-section-title'),
                    style: const TextStyle(
                      fontSize: 20,
                      height: 28 / 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Text(
                    'Роли и доступ к этой гильдии',
                    style: TextStyle(
                      color: GcColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: _accountsLoading ? null : () => _loadAccounts(),
              icon: const Icon(Icons.refresh),
              label: const Text('Обновить'),
            ),
          ],
        ),
      ),
      AdminMemberFilters(
        search: _accountSearch,
        role: _accountRoleFilter,
        onSearchChanged: () => setState(() {}),
        onRoleChanged: (value) => setState(() => _accountRoleFilter = value),
      ),
      if (_accountsLoading && _adminAccounts.isEmpty)
        _adminLoadingState(
          'Загружаем список участников…',
          'admin-members-loading',
        )
      else if (!_accountsLoading &&
          _adminAccounts.isEmpty &&
          _accountsError == null)
        const Expanded(child: Center(child: Text('Участников пока нет.')))
      else
        Expanded(
          child: ListView(
            key: ValueKey(
              'admin-member-list:${_accountSearch.text}:$_accountRoleFilter',
            ),
            padding: _adminSectionListPadding,
            children: [
              if (_resetLink != null) _buildResetLinkCard(),
              if (_adminAccounts.isNotEmpty && _visibleAdminAccounts.isEmpty)
                const Text('По запросу участники не найдены.'),
              for (final account in _visibleAdminAccounts)
                _buildAdminAccountCard(account),
              if (_accountsLoading)
                const Center(child: CircularProgressIndicator()),
              if (_accountCursor != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: _accountsLoading
                        ? null
                        : () => _loadAccounts(cursor: _accountCursor),
                    child: const Text('Загрузить ещё'),
                  ),
                ),
              if (_accountsStatus != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      _accountsStatus!,
                      style: const TextStyle(color: GcColors.success),
                    ),
                  ),
                ),
              if (_accountsError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      _accountsError!,
                      style: const TextStyle(color: GcColors.danger),
                    ),
                  ),
                ),
            ],
          ),
        ),
    ],
  );

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

  Widget _buildAdminAccountCard(AdminAccount account) {
    final draft = _accountDrafts[account.accountId];
    final busy = _busyAccountIds.contains(account.accountId);
    final sameVoiceParticipant =
        widget.state.voiceChannel != null &&
        widget.state.room?.remoteParticipants.values.any((participant) {
              final metadata = participant.metadata;
              return metadata == 'account:${account.accountId}';
            }) ==
            true;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: GcColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: GcColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            account.displayName,
            style: const TextStyle(
              fontSize: 16,
              height: 20 / 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            '@${account.login}',
            style: const TextStyle(color: GcColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            key: ValueKey('role:${account.accountId}:${draft?.role}'),
            initialValue: draft?.role,
            decoration: InputDecoration(labelText: 'Роль: ${account.login}'),
            items: const [
              DropdownMenuItem(value: 'MEMBER', child: Text('Участник')),
              DropdownMenuItem(
                value: 'ADMINISTRATOR',
                child: Text('Администратор'),
              ),
            ],
            onChanged: busy || draft == null
                ? null
                : (value) {
                    if (value != null) setState(() => draft.role = value);
                  },
          ),
          Material(
            color: GcColors.surface,
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Заблокирован'),
              value: draft?.blocked ?? account.blocked,
              onChanged: busy || draft == null
                  ? null
                  : (value) => setState(() => draft.blocked = value),
            ),
          ),
          Wrap(
            spacing: 8,
            children: [
              FilledButton.tonal(
                key: ValueKey('save-account:${account.accountId}'),
                focusNode: _accountSaveFocusNodes.putIfAbsent(
                  account.accountId,
                  FocusNode.new,
                ),
                onPressed: busy ? null : () => _saveAccount(account),
                child: busy
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Сохранить'),
              ),
              OutlinedButton(
                key: ValueKey('reset-account:${account.accountId}'),
                onPressed: busy ? null : () => _createResetLink(account),
                child: const Text('Сбросить пароль'),
              ),
              if (sameVoiceParticipant &&
                  account.accountId != widget.state.user?.accountId)
                OutlinedButton(
                  onPressed: busy ? null : () => _kickVoiceParticipant(account),
                  child: const Text('Отключить от голоса'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResetLinkCard() => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: GcColors.surface,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: GcColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Одноразовая ссылка для @$_resetLogin',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            IconButton(
              tooltip: 'Закрыть и удалить ссылку',
              onPressed: () => setState(() {
                _resetLink = null;
                _resetLogin = null;
              }),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        const Text('После закрытия ссылка будет удалена с этого экрана.'),
        const SizedBox(height: 8),
        SelectableText(_resetLink!.url),
        const SizedBox(height: 8),
        Text('Истекает: ${_auditDate(_resetLink!.expiresAt)}'),
        TextButton.icon(
          onPressed: _copyResetLink,
          icon: const Icon(Icons.copy),
          label: const Text('Скопировать ссылку'),
        ),
      ],
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _auditTitle(event.eventType),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                _auditDate(event.createdAt),
                style: const TextStyle(
                  color: GcColors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Инициатор · $actor',
            style: const TextStyle(color: GcColors.textSecondary, fontSize: 12),
          ),
          if (target != null)
            Text(
              'Объект · $target',
              style: const TextStyle(
                color: GcColors.textSecondary,
                fontSize: 12,
              ),
            ),
        ],
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
