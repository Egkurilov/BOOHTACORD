import '../../native_bindings.dart';
import '../../lifecycle/context.dart';
import '../../account_draft/model.dart';

extension RenderAdminMemberActionsAction on AdminScreenStateContext {
  Widget renderAdminMemberActions(
    AdminAccount account,
    bool busy,
    AdminAccountDraft? draft,
    bool sameVoiceParticipant,
  ) {
    final focus = adminAccountActionFocusNodes.putIfAbsent(
      account.accountId,
      FocusNode.new,
    );
    return Focus(
      key: ValueKey('admin-member-action-focus:${account.accountId}'),
      focusNode: focus,
      skipTraversal: true,
      onFocusChange: (_) {
        if (mounted) adminMutateView(() {});
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: focus.hasFocus
              ? Border.all(color: GcColors.focus, width: 2)
              : null,
        ),
        child: PopupMenuButton<String>(
          key: ValueKey('admin-member-actions:${account.accountId}'),
          popUpAnimationStyle: MediaQuery.disableAnimationsOf(context)
              ? AnimationStyle.noAnimation
              : null,
          tooltip: 'Действия с участником ${account.displayName}',
          enabled: !busy,
          onOpened: focus.requestFocus,
          onCanceled: focus.requestFocus,
          onSelected: (action) {
            focus.requestFocus();
            switch (action) {
              case 'role':
                if (draft != null) {
                  adminMutateView(
                    () => draft.role = draft.role == 'ADMINISTRATOR'
                        ? 'MEMBER'
                        : 'ADMINISTRATOR',
                  );
                }
                break;
              case 'blocked':
                if (draft != null) {
                  adminMutateView(() => draft.blocked = !draft.blocked);
                }
                break;
              case 'save':
                adminSaveAccount(account);
                break;
              case 'reset':
                adminCreateResetLink(account);
                break;
              case 'kick':
                adminKickVoiceParticipant(account);
                break;
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'role',
              child: Text(
                draft?.role == 'ADMINISTRATOR'
                    ? 'Назначить участником'
                    : 'Назначить администратором',
              ),
            ),
            PopupMenuItem(
              value: 'blocked',
              child: Text(
                draft?.blocked == true ? 'Снять блокировку' : 'Заблокировать',
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'save',
              enabled: draft != null && adminDraftChanged(account, draft),
              child: const Text('Сохранить'),
            ),
            const PopupMenuItem(value: 'reset', child: Text('Сбросить пароль')),
            if (sameVoiceParticipant &&
                account.accountId != widget.state.user?.accountId)
              const PopupMenuItem(
                value: 'kick',
                child: Text('Отключить от голоса'),
              ),
          ],
          child: const SizedBox.square(
            dimension: 44,
            child: Center(child: Icon(Icons.more_horiz)),
          ),
        ),
      ),
    );
  }
}
