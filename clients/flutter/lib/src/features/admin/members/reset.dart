import 'state.dart';

mixin AdminMembersReset on AdminMembersState {
  Future<void> createResetLink(String id) async {
    AdminAccount? account;
    for (final candidate in accounts) {
      if (candidate.accountId == id) account = candidate;
    }
    if (account == null || busyAccountIds.contains(id)) return;
    resetResult = null;
    busyAccountIds.add(id);
    error = null;
    status = null;
    emit();
    try {
      final link = await api.createAdminPasswordResetLink(id);
      resetResult = AdminMemberResetResult(account, link);
    } catch (cause) {
      error = cause.toString();
    } finally {
      busyAccountIds.remove(id);
      emit();
    }
  }

  void dismissResetLink() {
    resetResult = null;
    emit();
  }
}
