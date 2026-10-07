import 'state.dart';

mixin AdminMembersLoad on AdminMembersState {
  Future<void> load({String? cursor}) async {
    if (loading || (cursor != null && cursor != nextCursor)) return;
    loading = true;
    error = null;
    emit();
    try {
      final page = await api.listAdminAccounts(cursor: cursor);
      final chunk = AdminMemberPage(
        cursor: cursor,
        accounts: page.accounts,
        nextCursor: page.nextCursor,
      );
      replacePages(
        cursor == null ? [chunk] : [...pages, chunk],
      );
    } catch (cause) {
      error = cause.toString();
    } finally {
      loading = false;
      emit();
    }
  }

  Future<void> loadNextPage() async {
    final cursor = nextCursor;
    if (cursor != null) await load(cursor: cursor);
  }

  Future<bool> refresh({Set<String> resetDraftFor = const {}}) async {
    if (loading) return false;
    final pageCount = pages.isEmpty ? 1 : pages.length;
    loading = true;
    error = null;
    emit();
    try {
      final refreshed = <AdminMemberPage>[];
      String? cursor;
      for (var index = 0; index < pageCount; index++) {
        final page = await api.listAdminAccounts(cursor: cursor);
        refreshed.add(
          AdminMemberPage(
            cursor: cursor,
            accounts: page.accounts,
            nextCursor: page.nextCursor,
          ),
        );
        cursor = page.nextCursor;
        if (cursor == null) break;
      }
      replacePages(refreshed, resetDraftFor: resetDraftFor);
      return true;
    } catch (cause) {
      error = cause.toString();
      return false;
    } finally {
      loading = false;
      emit();
    }
  }
}
