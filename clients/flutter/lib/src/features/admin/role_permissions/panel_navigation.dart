part of 'panel.dart';

extension _RolePermissionNavigation on RolePermissionsPanelState {
  Future<void> _changeRole(GuildRole next) async {
    if (next == role) return;
    if (role == GuildRole.member && hasPendingChanges) {
      final keepDraft = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Сохранить черновик?'),
          content: Text(conflictReview == null
              ? 'Черновик останется локально, пока вы смотрите другую роль.'
              : 'Черновик и сравнение конфликта останутся локально.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Остаться'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Перейти, сохранив черновик'),
            ),
          ],
        ),
      );
      if (keepDraft != true || !mounted) return;
    }
    setState(() => role = next);
  }

  Future<bool> _confirmBeforeLeaving() async {
    if (!hasPendingChanges) return true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Несохранённые изменения'),
        content: const Text('При выходе черновик и сравнение конфликта будут удалены.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Остаться в редакторе'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить черновик и продолжить'),
          ),
        ],
      ),
    );
    return leave == true;
  }

  Future<void> _confirmRoutePop() async {
    if (!await _confirmBeforeLeaving() || !mounted) return;
    setState(() => _allowPop = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) await Navigator.of(context).maybePop();
  }
}
