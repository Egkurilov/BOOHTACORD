import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../models.dart';
import '../services/api_client.dart';
import '../theme.dart';
import '../widgets/confirmation_dialog.dart';
import '../features/admin/role_permissions/panel.dart';
import '../features/admin/guild_settings/panel.dart';
import 'admin_member_filter.dart';
import 'admin_member_filters.dart';
import '../features/admin/readiness/panel.dart';
import '../features/admin/topology/panel.dart';
import '../features/admin/audit/filter.dart';
import '../features/admin/audit/panel.dart';
import '../features/admin/layout/width_class.dart';
import '../features/admin/media_metrics/panel.dart';
import '../features/admin/members/panel.dart';
import '../features/admin/members/conflict_review.dart';
import '../features/admin/shell/section_tabs.dart';
import '../features/admin/shell/workspace_header.dart';
import '../features/admin/topology/mutation_controller.dart';

class _AdminAccountDraft {
  _AdminAccountDraft({required this.role, required this.blocked});
  String role;
  bool blocked;
}

class _AdminAccountConflict {
  _AdminAccountConflict({required this.before});
  final AdminAccount before;
  AdminAccount? current;
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
  final _channelDescription = TextEditingController();
  final _accountSearch = TextEditingController();
  final _auditActor = TextEditingController();
  String? _categoryId;
  final _collapsedTopologyCategories = <String>{};
  String? _channelId;
  String? _moveChannelId;
  String? _moveTargetCategoryId;
  String? _archiveChannelId;
  String? _closeVoiceChannelId;
  ChannelKind _channelKind = ChannelKind.voice;
  late final AdminTopologyMutationController _topologyMutations;
  bool get _busy => _topologyMutations.busy;
  String? get _status => _topologyMutations.status;
  String? get _error => _topologyMutations.error;
  AdminSection _selectedAdminSection = AdminSection.members;
  List<AdminAccount> _adminAccounts = const [];
  String _accountRoleFilter = 'ALL';
  List<AdminAccount> get _visibleAdminAccounts => filterAdminMembers(
    _adminAccounts,
    search: _accountSearch.text,
    role: _accountRoleFilter,
  );
  String? _accountCursor;
  final Map<String, _AdminAccountDraft> _accountDrafts = {};
  final Map<String, AdminAccount> _accountBaselines = {};
  final Map<String, _AdminAccountConflict> _accountConflicts = {};
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
    _topologyMutations = AdminTopologyMutationController(
      api: widget.state.api,
      topologyProvider: () => widget.state.topology,
      refreshTopology: widget.state.refreshTopology,
      confirm: (confirmation) => showConfirmationDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(confirmation.title),
          content: Text(confirmation.content),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Отмена'),
            ),
            FilledButton.tonal(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(confirmation.confirmLabel),
            ),
          ],
        ),
      ),
    )..addListener(_onTopologyMutationChanged);
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
    _topologyMutations
      ..removeListener(_onTopologyMutationChanged)
      ..dispose();
    _titleFocus.dispose();
    _categoryName.dispose();
    _categoryRename.dispose();
    _channelName.dispose();
    _channelRename.dispose();
    _channelDescription.dispose();
    _accountSearch.dispose();
    _auditActor.dispose();
    for (final focusNode in _accountSaveFocusNodes.values) {
      focusNode.dispose();
    }
    super.dispose();
  }

  void _onTopologyMutationChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _selectedAdminSection == AdminSection.media) {
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

  Future<void> _createCategory() async {
    final id = await _topologyMutations.actions.createCategory(
      _categoryName.text,
    );
    if (!mounted || id == null) return;
    _categoryName.clear();
    setState(() => _categoryId = id);
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

  Future<void> _loadAccounts({
    String? cursor,
    bool acceptDrafts = false,
  }) async {
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
          final baseline = _accountBaselines[account.accountId];
          final draft = _accountDrafts[account.accountId];
          if (baseline == null || acceptDrafts) {
            _accountBaselines[account.accountId] = account;
            _accountDrafts[account.accountId] = _AdminAccountDraft(
              role: account.role,
              blocked: account.blocked,
            );
            _accountConflicts.remove(account.accountId);
            continue;
          }
          if (draft == null || !_draftChanged(baseline, draft)) {
            _accountBaselines[account.accountId] = account;
            _accountDrafts[account.accountId] = _AdminAccountDraft(
              role: account.role,
              blocked: account.blocked,
            );
          } else if (baseline.updatedAt != account.updatedAt) {
            final conflict = _accountConflicts.putIfAbsent(
              account.accountId,
              () => _AdminAccountConflict(before: baseline),
            );
            conflict.current = account;
          } else if (_accountConflicts[account.accountId]
              case final conflict?) {
            conflict.current = account;
          }
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
    if (account.updatedAt == null) {
      setState(
        () => _accountsError =
            'Обновите список участников: серверная версия аккаунта недоступна.',
      );
      return;
    }
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
        expectedUpdatedAt: account.updatedAt,
      );
      await _loadAccounts(acceptDrafts: true);
      if (mounted) {
        setState(
          () => _accountsStatus = 'Изменения для @${account.login} сохранены.',
        );
      }
    } catch (cause) {
      if (cause is ApiFailure && cause.status == 409) {
        final conflict = _accountConflicts.putIfAbsent(
          account.accountId,
          () => _AdminAccountConflict(before: account),
        );
        conflict.current = null;
        await _loadAccounts();
        if (mounted) {
          setState(
            () => _accountsError = 'Участник изменён другим администратором. Черновик сохранён; сравните данные и повторите действие.',
          );
        }
      } else if (mounted) {
        setState(() => _accountsError = cause.toString());
      }
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

  void _selectSection(AdminSection section) {
    setState(() => _selectedAdminSection = section);
    _mediaRefreshTimer?.cancel();
    _mediaRefreshTimer = null;
    if (section == AdminSection.members && _adminAccounts.isEmpty) {
      _loadAccounts();
    }
    if (section == AdminSection.audit && _auditEvents.isEmpty) {
      _loadAudit();
    }
    if (section == AdminSection.media) {
      unawaited(_loadMediaMetrics());
      _mediaRefreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (WidgetsBinding.instance.lifecycleState ==
            AppLifecycleState.resumed) {
          unawaited(_loadMediaMetrics());
        }
      });
    }
  }

  Future<void> _createChannel() async {
    final categoryId =
        _categoryId ?? widget.state.topology?.categories.firstOrNull?.id;
    if (categoryId == null) {
      _topologyMutations.reportError('Сначала создайте категорию.');
      return;
    }
    final revision = widget.state.topology?.revision;
    if (revision == null) return;
    await _topologyMutations.actions.createChannel(
      categoryId,
      revision,
      _channelName.text,
      _channelKind,
    );
    if (!mounted || _topologyMutations.error != null) return;
    _channelName.clear();
  }

  Future<void> _renameCategory(ChannelCategory category) async {
    final revision = widget.state.topology?.revision;
    if (revision != null) {
      await _topologyMutations.actions.renameCategory(
        category,
        revision,
        _categoryRename.text,
      );
    }
  }

  Future<void> _renameChannel(GuildChannel channel) async {
    final revision = widget.state.topology?.revision;
    if (revision != null) {
      await _topologyMutations.actions.renameChannel(
        channel,
        revision,
        _channelRename.text,
      );
    }
  }

  Future<void> _saveChannelDescription(GuildChannel channel) async {
    final revision = widget.state.topology?.revision;
    if (revision != null) {
      await _topologyMutations.actions.saveDescription(
        channel,
        revision,
        _channelDescription.text,
      );
    }
  }

  Future<void> _deleteCategory(ChannelCategory category) async {
    final revision = widget.state.topology?.revision;
    if (revision != null) {
      await _topologyMutations.actions.deleteCategory(category, revision);
    }
  }

  Future<void> _reorderCategory(int direction) async {
    final topology = widget.state.topology;
    if (topology == null || _categoryId == null) return;
    await _topologyMutations.actions.reorderCategory(
      _categoryId!,
      topology.revision,
      direction,
    );
  }

  Future<void> _reorderChannel(int direction) async {
    final topology = widget.state.topology;
    final category = topology?.categories
        .where((item) => item.id == _categoryId)
        .firstOrNull;
    if (topology == null || category == null || _channelId == null) return;
    final channel = category.channels
        .where((item) => item.id == _channelId)
        .firstOrNull;
    if (channel == null) return;
    await _topologyMutations.actions.reorderChannel(
      category.id,
      channel,
      topology.revision,
      direction,
    );
  }

  Future<void> _moveChannel() async {
    final topology = widget.state.topology;
    if (topology == null ||
        _moveChannelId == null ||
        _moveTargetCategoryId == null) {
      return;
    }
    final channel = topology.categories
        .expand((category) => category.channels)
        .where((item) => item.id == _moveChannelId)
        .firstOrNull;
    if (channel == null) return;
    await _topologyMutations.actions.moveChannel(
      channel,
      topology.revision,
      _moveTargetCategoryId!,
    );
  }

  Future<void> _archiveTextChannel(List<GuildChannel> channels) async {
    final channel = channels
        .where(
          (item) =>
              item.id == _archiveChannelId && item.kind == ChannelKind.text,
        )
        .firstOrNull;
    final revision = widget.state.topology?.revision;
    if (channel == null || revision == null) return;
    await _topologyMutations.actions.archiveTextChannel(channel, revision);
  }

  Future<void> _closeVoiceAdmission(List<GuildChannel> channels) async {
    final channel = channels
        .where(
          (item) =>
              item.id == _closeVoiceChannelId && item.kind == ChannelKind.voice,
        )
        .firstOrNull;
    final revision = widget.state.topology?.revision;
    if (channel == null || revision == null || channel.admissionClosed) return;
    await _topologyMutations.actions.closeVoiceAdmission(channel, revision);
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
    final selectedId = categories.any((item) => item.id == _categoryId)
        ? _categoryId
        : categories.firstOrNull?.id;
    final selectedCategory = categories
        .where((item) => item.id == selectedId)
        .firstOrNull;
    final expandedCategoryId =
        selectedId != null && !_collapsedTopologyCategories.contains(selectedId)
        ? selectedId
        : null;
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
          AdminWorkspaceHeader(
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
                          child: AdminSectionTabs(
                            selectedSection: _selectedAdminSection,
                            onSelected: _selectSection,
                            compactLabel: width < 600,
                            wideSpacing: width > 1023,
                            channelsSelected:
                                _selectedAdminSection == AdminSection.channels,
                            onRefreshChannels: widget.state.refreshTopology,
                            refreshDisabled: _busy,
                          ),
                        ),
                        Expanded(
                          child: _selectedAdminSection == AdminSection.guild
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
                              : _selectedAdminSection == AdminSection.roles
                              ? RolePermissionsPanel(
                                  api: widget.state.api,
                                  onSaved: widget.state.permissions.refresh,
                                )
                              : _selectedAdminSection == AdminSection.audit
                              ? _buildAuditPanel()
                              : _selectedAdminSection == AdminSection.media
                              ? _buildMediaPanel()
                              : _selectedAdminSection == AdminSection.readiness
                              ? AdminReadinessPanel(api: widget.state.api)
                              : _selectedAdminSection == AdminSection.members
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
                                          TopologyTree(
                                            categories: categories,
                                            selectedCategoryId:
                                                expandedCategoryId,
                                            selectedChannelId: _channelId,
                                            onCategorySelected: (category) =>
                                                setState(() {
                                                  _categoryId = category.id;
                                                  if (!_collapsedTopologyCategories
                                                      .add(category.id)) {
                                                    _collapsedTopologyCategories
                                                        .remove(category.id);
                                                  }
                                                  _categoryRename.text =
                                                      category.name;
                                                  _channelId = null;
                                                  _channelRename.clear();
                                                  _channelDescription.clear();
                                                }),
                                            onChannelSelected: (channel) =>
                                                setState(() {
                                                  _categoryId =
                                                      selectedCategory?.id;
                                                  if (selectedCategory !=
                                                      null) {
                                                    _collapsedTopologyCategories
                                                        .remove(
                                                          selectedCategory.id,
                                                        );
                                                  }
                                                  _channelId = channel.id;
                                                  _channelRename.text =
                                                      channel.name;
                                                  _channelDescription.text =
                                                      channel.description ?? '';
                                                }),
                                          ),
                                          const SizedBox(height: 16),
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
                                                    _channelDescription.clear();
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
                                                      _channelDescription.text =
                                                          channels
                                                              .where(
                                                                (item) =>
                                                                    item.id ==
                                                                    value,
                                                              )
                                                              .firstOrNull
                                                              ?.description ??
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
                                              TextField(
                                                controller: _channelDescription,
                                                enabled: !_busy,
                                                maxLength: 200,
                                                maxLines: 2,
                                                decoration:
                                                    const InputDecoration(
                                                      labelText:
                                                          'Описание канала',
                                                      hintText: 'Кратко объясните назначение канала',
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
                                              Align(
                                                alignment: Alignment.centerLeft,
                                                child: OutlinedButton(
                                                  onPressed: _busy
                                                      ? null
                                                      : () =>
                                                            _saveChannelDescription(
                                                              selectedChannel,
                                                            ),
                                                  child: const Text(
                                                    'Сохранить описание',
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

  Widget _buildMediaPanel() => AdminMediaMetricsPanel(
    headerPadding: _adminSectionHeaderPadding,
    listPadding: _adminSectionListPadding,
    loading: _mediaLoading,
    samples: _mediaSamples,
    error: _mediaError,
    lastSuccessfulAt: _mediaLastSuccessfulAt,
    lastSeenAt: _mediaLastSeenAt,
    onRefresh: _loadMediaMetrics,
    formatDate: _auditDate,
  );

  Widget _buildAuditPanel() => AdminAuditPanel(
    headerPadding: _adminSectionHeaderPadding,
    listPadding: _adminSectionListPadding,
    events: _auditEvents,
    loading: _auditLoading,
    error: _auditError,
    cursor: _auditCursor,
    scope: _auditScope,
    eventType: _auditEventType,
    from: _auditFrom,
    to: _auditTo,
    actor: _auditActor,
    onRefresh: _loadAudit,
    onScopeChanged: (value) => setState(() => _auditScope = value),
    onEventTypeChanged: (value) => setState(() => _auditEventType = value),
    onActorChanged: () => setState(() {}),
    onPickFrom: () => _pickAuditDate(from: true),
    onPickTo: () => _pickAuditDate(from: false),
    onClearFilters: () => setState(() {
      _auditScope = AdminAuditScope.all;
      _auditEventType = null;
      _auditActor.clear();
      _auditFrom = null;
      _auditTo = null;
    }),
    onLoadMore: () => _loadAudit(before: _auditCursor),
    filters: _auditFilters,
    formatDate: _auditDate,
  );

  Widget _buildMembersPanel() => AdminMembersPanel(
    headerPadding: _adminSectionHeaderPadding,
    listPadding: _adminSectionListPadding,
    accountsCount: _adminAccounts.length,
    loading: _accountsLoading,
    accountsEmpty: _adminAccounts.isEmpty,
    error: _accountsError,
    filters: AdminMemberFilters(
      search: _accountSearch,
      role: _accountRoleFilter,
      onSearchChanged: () => setState(() {}),
      onRoleChanged: (value) => setState(() => _accountRoleFilter = value),
    ),
    resetCard: _resetLink == null ? null : _buildResetLinkCard(),
    conflictCards: [
      for (final entry in _accountConflicts.entries)
        _buildAccountConflictCard(entry.key, entry.value),
    ],
    accountCards: [
      for (final account in _visibleAdminAccounts)
        _buildAdminAccountCard(account),
    ],
    search: _accountSearch.text,
    roleFilter: _accountRoleFilter,
    cursor: _accountCursor,
    status: _accountsStatus,
    loadingState: _adminLoadingState(
      'Загружаем список участников…',
      'admin-members-loading',
    ),
    onRefresh: _loadAccounts,
    onLoadMore: () => _loadAccounts(cursor: _accountCursor),
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 16,
              height: 20 / 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            '@${account.login}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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

  Widget _buildAccountConflictCard(
    String accountId,
    _AdminAccountConflict conflict,
  ) {
    final account = _adminAccounts
        .where((item) => item.accountId == accountId)
        .firstOrNull;
    final draft = _accountDrafts[accountId];
    if (account == null || draft == null) return const SizedBox.shrink();
    return AdminMemberConflictReview(
      login: account.login,
      before: _accountSummary(conflict.before.role, conflict.before.blocked),
      current: conflict.current == null
          ? null
          : _accountSummary(conflict.current!.role, conflict.current!.blocked),
      proposed: _accountSummary(draft.role, draft.blocked),
      busy: _busyAccountIds.contains(accountId) || _accountsLoading,
      onRefresh: _loadAccounts,
      onDiscard: () => setState(() {
        final current = conflict.current;
        if (current == null) return;
        _accountBaselines[accountId] = current;
        _accountDrafts[accountId] = _AdminAccountDraft(
          role: current.role,
          blocked: current.blocked,
        );
        _accountConflicts.remove(accountId);
        _accountsStatus = 'Приняты актуальные данные @$account.login.';
      }),
      onApply: () => setState(() {
        final current = conflict.current;
        if (current == null) return;
        _accountBaselines[accountId] = current;
        _accountConflicts.remove(accountId);
        _accountsStatus =
            'Сравнение @${account.login} подтверждено. Нажмите «Сохранить».';
      }),
    );
  }

  bool _draftChanged(AdminAccount baseline, _AdminAccountDraft draft) =>
      baseline.role != draft.role || baseline.blocked != draft.blocked;

  String _accountSummary(String role, bool blocked) =>
      '${role == 'ADMINISTRATOR' ? 'Администратор' : 'Пользователь'}; '
      '${blocked ? 'заблокирован' : 'доступ открыт'}';

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

  String _auditDate(DateTime date) {
    final local = date.toLocal();
    return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}.${local.year} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}
