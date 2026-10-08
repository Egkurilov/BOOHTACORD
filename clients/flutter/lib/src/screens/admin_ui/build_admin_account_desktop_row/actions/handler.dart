import '../../native_bindings.dart';
import '../../lifecycle/context.dart';
import '../../account_draft/model.dart';
import 'selection/handler.dart';
import 'keyboard/binding.dart';

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
    final popup = GlobalObjectKey<PopupMenuButtonState<String>>(focus);
    return adminMemberMenuKeyboard(
      focusKey: ValueKey('admin-member-action-focus:${account.accountId}'),
      focus: focus,
      popup: popup,
      enabled: !busy,
      changed: () {
        if (mounted) adminMutateView(() {});
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: focus.hasFocus
              ? Border.all(color: GcColors.focus, width: 2)
              : null,
        ),
        child: SizedBox(
          key: ValueKey('admin-member-actions:${account.accountId}'),
          child: PopupMenuButton<String>(
            key: popup,
            popUpAnimationStyle: MediaQuery.disableAnimationsOf(context)
                ? AnimationStyle.noAnimation
                : null,
            tooltip: 'Действия с участником ${account.displayName}',
            enabled: !busy,
            onOpened: focus.requestFocus,
            onCanceled: focus.requestFocus,
            onSelected: (action) {
              focus.requestFocus();
              adminSelectMemberAction(account, draft, action);
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
              const PopupMenuItem(
                value: 'reset',
                child: Text('Сбросить пароль'),
              ),
              const PopupMenuItem(
                value: 'timeout',
                child: Text('Голосовой тайм-аут'),
              ),
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
      ),
    );
  }
}
