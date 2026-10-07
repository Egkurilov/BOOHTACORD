import 'dart:async';

import 'package:flutter/material.dart';

import '../../../services/api_client.dart';
import '../../authorization/permissions/model.dart';
import 'conflict_review.dart';
import 'model.dart';

class RolePermissionsPanel extends StatefulWidget {
  const RolePermissionsPanel({
    super.key,
    required this.api,
    required this.onSaved,
  });
  final ApiClient api;
  final Future<void> Function() onSaved;
  @override
  State<RolePermissionsPanel> createState() => _RolePermissionsPanelState();
}

class _RolePermissionsPanelState extends State<RolePermissionsPanel> {
  static const labels = {
    GuildPermission.textCreate: 'Создавать текстовые каналы',
    GuildPermission.textDelete: 'Удалять текстовые каналы',
    GuildPermission.voiceCreate: 'Создавать голосовые каналы',
    GuildPermission.voiceDelete: 'Закрывать голосовые каналы',
    GuildPermission.categoryCreate: 'Создавать категории',
    GuildPermission.categoryDelete: 'Удалять пустые категории',
  };
  static const deleteKeys = {
    GuildPermission.textDelete,
    GuildPermission.voiceDelete,
    GuildPermission.categoryDelete,
  };
  GuildRole role = GuildRole.member;
  int revision = 0;
  bool loading = true;
  bool saving = false;
  String? error;
  String? status;
  bool conflict = false;
  Map<GuildPermission, bool>? conflictBefore;
  Map<GuildPermission, bool>? conflictCurrent;
  List<RolePolicy> roles = const [];
  Map<GuildPermission, bool> baseline = {};
  Map<GuildPermission, bool> draft = {};
  bool get dirty =>
      GuildPermission.values.any((key) => baseline[key] != draft[key]);
  RolePolicy? get selected =>
      roles.where((item) => item.role == role).firstOrNull;
  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({required bool reset}) async {
    setState(() {
      loading = true;
      error = null;
      status = null;
    });
    try {
      final page = await widget.api.loadRolePolicies();
      final member = page.roles.firstWhere(
        (item) => item.role == GuildRole.member,
      );
      if (!mounted) return;
      setState(() {
        roles = page.roles;
        revision = page.revision;
        baseline = Map.of(member.permissions);
        if (reset) draft = Map.of(member.permissions);
        if (reset) {
          conflict = false;
          conflictBefore = null;
          conflictCurrent = null;
        }
      });
    } catch (cause) {
      if (mounted) setState(() => error = cause.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _defaults() => setState(() {
    draft = {
      for (final key in GuildPermission.values) key: !deleteKeys.contains(key),
    };
    status = 'Значения по умолчанию загружены в черновик.';
  });
  Future<void> _save() async {
    final before = Map<GuildPermission, bool>.of(baseline);
    final newDeletes = deleteKeys.any(
      (key) => baseline[key] != true && draft[key] == true,
    );
    if (newDeletes && !await _confirmDeletes()) return;
    setState(() {
      saving = true;
      error = null;
      status = null;
      conflict = false;
    });
    try {
      await widget.api.saveMemberRolePolicy(
        revision: revision,
        values: draft,
        confirmDeleteGrants: newDeletes,
      );
      await _load(reset: true);
      await widget.onSaved();
      if (mounted) setState(() => status = 'Разрешения сохранены.');
    } catch (cause) {
      if (cause is ApiFailure && cause.status == 409) {
        setState(() {
          conflict = true;
          conflictBefore = before;
          error = 'Настройки уже изменены. Проверьте актуальные значения и решите, применять ли черновик.';
        });
        await _load(reset: false);
        if (mounted) {
          setState(() {
            conflictCurrent = Map<GuildPermission, bool>.of(baseline);
            error = 'Настройки уже изменены. Проверьте актуальные значения и решите, применять ли черновик.';
          });
        }
      } else if (mounted) {
        setState(() => error = cause.toString());
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<bool> _confirmDeletes() async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Выдать права удаления?'),
          content: const Text(
            'Участники смогут удалять объекты гильдии во всех каналах.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Выдать'),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _changeRole(GuildRole next) async {
    if (next == role) return;
    if (dirty) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Сохранить черновик?'),
          content: const Text(
            'При смене роли текущий черновик останется сохранённым локально.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Остаться'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Продолжить'),
            ),
          ],
        ),
      );
      if (discard != true || !mounted) return;
    }
    setState(() => role = next);
  }

  static const _permissionGroups = [
    (
      label: 'Текстовые каналы',
      hint: 'Создание и архивирование текстовой истории.',
      create: GuildPermission.textCreate,
      delete: GuildPermission.textDelete,
    ),
    (
      label: 'Голосовые каналы',
      hint: 'Создание и закрытие доступа к голосовым каналам.',
      create: GuildPermission.voiceCreate,
      delete: GuildPermission.voiceDelete,
    ),
    (
      label: 'Разделы',
      hint: 'Создание и удаление только пустых категорий.',
      create: GuildPermission.categoryCreate,
      delete: GuildPermission.categoryDelete,
    ),
  ];

  Widget _permissionMatrix(Map<GuildPermission, bool> values, double width) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (width >= 600)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: [
                  Expanded(child: Text('Объект')),
                  SizedBox(width: 140, child: Text('Создавать')),
                  SizedBox(width: 140, child: Text('Удалять')),
                ],
              ),
            ),
          for (final group in _permissionGroups)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: width < 600
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            group.label,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text(group.hint, style: const TextStyle(fontSize: 12)),
                        _permissionTile(values, group.create),
                        _permissionTile(values, group.delete),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: Material(
                            color: Colors.transparent,
                            child: ListTile(
                              title: Text(group.label),
                              subtitle: Text(group.hint),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 140,
                          child: _permissionTile(values, group.create),
                        ),
                        SizedBox(
                          width: 140,
                          child: _permissionTile(values, group.delete),
                        ),
                      ],
                    ),
            ),
        ],
      );

  Widget _permissionTile(
    Map<GuildPermission, bool> values,
    GuildPermission permission,
  ) => Material(
    color: Colors.transparent,
    child: CheckboxListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      title: Text(labels[permission]!),
      value: values[permission] ?? false,
      onChanged: role == GuildRole.administrator || saving
          ? null
          : (value) => setState(() => draft[permission] = value ?? false),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final values = role == GuildRole.member
        ? draft
        : selected?.permissions ?? const <GuildPermission, bool>{};
    return PopScope(
      canPop: !dirty,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final contentInset = constraints.maxWidth < 1024 ? 0.0 : 24.0;
          return ListView(
            padding: EdgeInsets.fromLTRB(contentInset, 0, contentInset, 24),
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Роли и разрешения',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: loading ? null : () => _load(reset: false),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Обновить'),
                  ),
                ],
              ),
              SegmentedButton<GuildRole>(
                segments: const [
                  ButtonSegment(
                    value: GuildRole.member,
                    label: Text('Пользователь'),
                  ),
                  ButtonSegment(
                    value: GuildRole.administrator,
                    label: Text('Администратор'),
                  ),
                ],
                selected: {role},
                onSelectionChanged: (value) =>
                    unawaited(_changeRole(value.single)),
              ),
              const SizedBox(height: 12),
              if (loading && roles.isEmpty)
                const Center(child: CircularProgressIndicator())
              else
                LayoutBuilder(
                  builder: (context, constraints) =>
                      _permissionMatrix(values, constraints.maxWidth),
                ),
              if (role == GuildRole.administrator)
                const Text(
                  'Разрешения администратора обязательны и не изменяются.',
                ),
              if (role == GuildRole.member)
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: saving ? null : _defaults,
                      child: const Text('По умолчанию'),
                    ),
                    TextButton(
                      onPressed: !dirty || saving
                          ? null
                          : () => setState(() => draft = Map.of(baseline)),
                      child: const Text('Отмена'),
                    ),
                    FilledButton(
                      onPressed: !dirty || saving ? null : _save,
                      child: Text(saving ? 'Сохраняем…' : 'Сохранить'),
                    ),
                  ],
                ),
              if (role == GuildRole.member && dirty)
                Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Semantics(
                    liveRegion: true,
                    label: 'Есть несохранённые изменения',
                    child: Text(
                      'Есть несохранённые изменения',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              if (status != null)
                Semantics(
                  liveRegion: true,
                  child: Text(
                    status!,
                    style: const TextStyle(color: Colors.green),
                  ),
                ),
              if (error != null)
                Semantics(
                  liveRegion: true,
                  child: Text(
                    error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              if (conflict && conflictBefore != null && conflictCurrent != null)
                RolePermissionsConflictReview(
                  before: conflictBefore!,
                  current: conflictCurrent!,
                  proposed: draft,
                  busy: saving || loading,
                  onRefresh: () => _load(reset: false),
                  onAcceptCurrent: () => setState(() {
                    baseline = Map.of(conflictCurrent!);
                    draft = Map.of(conflictCurrent!);
                    conflict = false;
                    conflictBefore = null;
                    conflictCurrent = null;
                    error = null;
                    status = 'Серверные значения приняты в черновик.';
                  }),
                  onKeepDraft: () => setState(() {
                    baseline = Map.of(conflictCurrent!);
                    conflict = false;
                    conflictBefore = null;
                    conflictCurrent = null;
                    error = null;
                    status = 'Черновик сохранён. Нажмите «Сохранить» ещё раз.';
                  }),
                ),
            ],
          );
        },
      ),
    );
  }
}
