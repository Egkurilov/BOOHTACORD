part of 'panel.dart';

extension _RolePermissionActions on RolePermissionsPanelState {
  Future<void> _refreshConflict() => _load(reset: false);

  void _acceptServer() {
    setState(() {
      draft = Map.of(baseline);
      conflictReview = null;
      error = null;
      status = 'Приняты актуальные разрешения с сервера.';
    });
  }

  void _setDefaults() {
    if (selected?.editable != true || role != GuildRole.member || saving || loading) return;
    final values = {
      for (final key in GuildPermission.values) key: !_deleteKeys.contains(key),
    };
    setState(() {
      draft = values;
      status = 'Значения по умолчанию загружены в черновик.';
      if (conflictReview case final review?) {
        conflictReview = review.withProposed(values, revision);
      }
    });
  }

  void _setPermission(GuildPermission permission, bool value) {
    if (selected?.editable != true || role != GuildRole.member || saving || loading) return;
    setState(() {
      draft = Map.of(draft)..[permission] = value;
      if (conflictReview case final review?) {
        conflictReview = review.withProposed(draft, revision);
      }
      error = null;
      status = null;
    });
  }

  Future<bool> _confirmDeleteGrants() async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Выдать участникам право удаления?'),
          content: const Text('Разрешение удаления действует на любые каналы.'),
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

  Future<void> _save({bool reviewedConflict = false}) async {
    if (role != GuildRole.member || selected?.editable != true || saving || loading) return;
    final review = conflictReview;
    if (review != null &&
        (!reviewedConflict || !review.ready || review.revision != revision)) return;
    final newDeletes = _deleteKeys.any(
      (key) => baseline[key] != true && draft[key] == true,
    );
    if (newDeletes && !await _confirmDeleteGrants()) return;

    final before = Map<GuildPermission, bool>.of(baseline);
    final proposed = Map<GuildPermission, bool>.of(draft);
    setState(() {
      saving = true;
      error = null;
      status = null;
    });
    try {
      await widget.api.saveMemberRolePolicy(
        revision: revision,
        values: proposed,
        confirmDeleteGrants: newDeletes,
      );
      await _load(reset: true);
      await widget.onSaved();
      if (mounted) setState(() => status = 'Разрешения сохранены.');
    } catch (cause) {
      if (cause is ApiFailure && cause.status == 409) {
        if (mounted) {
          setState(() {
            conflictReview = _PermissionConflict(
              before: before,
              current: Map.of(baseline),
              proposed: proposed,
              revision: revision,
            );
          });
        }
        await _load(reset: false);
      } else if (mounted) {
        setState(() => error = cause.toString());
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }
}
