import 'package:flutter/material.dart';

import '../../../services/api_client.dart';
import '../../authorization/permissions/model.dart';
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
    final newDeletes = deleteKeys.any(
      (key) => baseline[key] != true && draft[key] == true,
    );
    if (newDeletes && !await _confirmDeletes()) return;
    setState(() {
      saving = true;
      error = null;
      status = null;
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
      if (mounted) {
        setState(
          () => error = cause is ApiFailure && cause.status == 409
              ? 'Настройки уже изменены. Черновик сохранён; обновите данные.'
              : cause.toString(),
        );
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
  @override
  Widget build(BuildContext context) {
    final values = role == GuildRole.member
        ? draft
        : selected?.permissions ?? const <GuildPermission, bool>{};
    final contentInset = MediaQuery.sizeOf(context).width < 1024 ? 0.0 : 24.0;
    return PopScope(
      canPop: !dirty,
      child: ListView(
        padding: EdgeInsets.fromLTRB(contentInset, 0, contentInset, 24),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Роли и разрешения',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
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
            onSelectionChanged: (value) => setState(() => role = value.single),
          ),
          const SizedBox(height: 12),
          if (loading && roles.isEmpty)
            const Center(child: CircularProgressIndicator())
          else
            for (final key in GuildPermission.values)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(labels[key]!),
                value: values[key] ?? false,
                onChanged: role == GuildRole.administrator || saving
                    ? null
                    : (value) => setState(() => draft[key] = value ?? false),
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
          if (status != null)
            Semantics(
              liveRegion: true,
              child: Text(status!, style: const TextStyle(color: Colors.green)),
            ),
          if (error != null)
            Semantics(
              liveRegion: true,
              child: Text(error!, style: const TextStyle(color: Colors.red)),
            ),
        ],
      ),
    );
  }
}
