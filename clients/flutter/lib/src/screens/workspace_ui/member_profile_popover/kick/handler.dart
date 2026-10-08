import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceMemberProfilePopoverStateWorkspaceKickBinding
    on WorkspaceMemberProfilePopoverStateContext {
  @override
  Future<void> workspaceKick(RemoteParticipant participant) {
    return executeWorkspaceMemberProfilePopoverStateWorkspaceKick(participant);
  }
}

extension WorkspaceMemberProfilePopoverStateWorkspaceKickAction
    on WorkspaceMemberProfilePopoverStateContext {
  Future<void> executeWorkspaceMemberProfilePopoverStateWorkspaceKick(
    RemoteParticipant participant,
  ) async {
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
    if (confirmed != true || !mounted) return;
    workspaceMutateView(() {
      workspaceKicking = true;
      workspaceError = null;
      workspaceStatus = null;
    });
    try {
      final revoked = await widget.state.api.kickAdminVoiceParticipant(
        widget.memberId,
      );
      if (mounted) {
        workspaceMutateView(
          () => workspaceStatus = revoked > 0
              ? 'Подключение отозвано.'
              : 'Активное голосовое подключение не найдено.',
        );
      }
    } catch (cause) {
      if (mounted) workspaceMutateView(() => workspaceError = cause.toString());
    } finally {
      if (mounted) workspaceMutateView(() => workspaceKicking = false);
    }
  }
}
