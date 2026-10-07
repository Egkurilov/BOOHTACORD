import '../../../core/http/api_failure.dart';
import 'load.dart';
import 'state.dart';

mixin AdminMembersSave on AdminMembersState, AdminMembersLoad {
  Future<void> saveAccount(String id) async {
    final account = baseline[id];
    final draft = drafts[id];
    if (account == null || draft == null || !isDirty(id) ||
        conflicts.containsKey(id) || busyAccountIds.contains(id)) return;
    final updatedAt = account.updatedAt;
    if (updatedAt == null) {
      error = 'Обновите список участников: серверная версия аккаунта недоступна.';
      emit();
      return;
    }
    busyAccountIds.add(id);
    error = null;
    status = null;
    emit();
    try {
      await api.updateAdminAccount(
        accountId: id,
        role: draft.role,
        blocked: draft.blocked,
        expectedUpdatedAt: updatedAt,
      );
      final reloaded = await refresh(resetDraftFor: {id});
      if (reloaded && !isDirty(id) && !conflicts.containsKey(id)) {
        status = 'Изменения для @${account.login} сохранены.';
      } else {
        error = 'Изменения отправлены, но список участников не обновился. Проверьте актуальные данные перед следующим изменением.';
      }
    } catch (cause) {
      if (cause is ApiFailure && cause.status == 409) {
        conflicts[id] = AdminMemberConflict(before: account);
        await refresh();
        error = 'Участник изменён другим администратором. Сравните данные перед повторным сохранением.';
      } else {
        error = cause.toString();
      }
    } finally {
      busyAccountIds.remove(id);
      emit();
    }
  }

  bool resolveConflict(String id, {required bool discard}) {
    final conflict = conflicts[id];
    final current = conflict?.current;
    if (conflict == null || current?.updatedAt == null) return false;
    baseline[id] = current!;
    if (discard) drafts[id] = AdminMemberDraft.fromAccount(current);
    conflicts.remove(id);
    emit();
    return true;
  }
}
