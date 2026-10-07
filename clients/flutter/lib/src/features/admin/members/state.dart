import 'package:flutter/material.dart';

import '../../../models.dart';
import '../../../services/api_client.dart';
import 'filter.dart';
import 'models.dart';

export 'models.dart';

abstract class AdminMembersState extends ChangeNotifier {
  AdminMembersState(this.api) {
    search.addListener(emit);
  }
  bool _disposed = false;
  void emit() { if (!_disposed) notifyListeners(); }
  final ApiClient api;
  final search = TextEditingController();
  final pages = <AdminMemberPage>[];
  List<AdminAccount> accounts = const [];
  String? nextCursor;
  String roleFilter = 'ALL';
  final baseline = <String, AdminAccount>{};
  final drafts = <String, AdminMemberDraft>{};
  final conflicts = <String, AdminMemberConflict>{};
  final busyAccountIds = <String>{};
  bool loading = false;
  String? error;
  String? status;
  AdminMemberResetResult? resetResult;

  List<AdminAccount> get visibleAccounts => filterAdminMembers(
    accounts,
    search: search.text,
    role: roleFilter,
  );

  bool get hasLoadedDirectory => pages.isNotEmpty;
  void setRoleFilter(String value) {
    roleFilter = value;
    emit();
  }

  void updateDraftRole(String id, String role) {
    final draft = drafts[id];
    if (draft == null || busyAccountIds.contains(id)) return;
    drafts[id] = draft.copyWith(role: role);
    emit();
  }

  void updateDraftBlocked(String id, bool blocked) {
    final draft = drafts[id];
    if (draft == null || busyAccountIds.contains(id)) return;
    drafts[id] = draft.copyWith(blocked: blocked);
    emit();
  }

  Future<void> loadNextPage();
  Future<bool> refresh({Set<String> resetDraftFor = const {}});
  Future<void> createResetLink(String id);
  void dismissResetLink();
  Future<void> saveAccount(String id);
  bool resolveConflict(String id, {required bool discard});
  Future<void> kickVoiceParticipant(String id);

  bool isDirty(String id) {
    final account = baseline[id];
    final draft = drafts[id];
    return account != null &&
        draft != null &&
        draft != AdminMemberDraft.fromAccount(account);
  }

  void replacePages(
    List<AdminMemberPage> next, {
    Set<String> resetDraftFor = const {},
  }) {
    pages
      ..clear()
      ..addAll(next);
    accounts = pages.expand((page) => page.accounts).toList(growable: false);
    nextCursor = pages.isEmpty ? null : pages.last.nextCursor;
    for (final account in accounts) {
      final id = account.accountId;
      final old = baseline[id];
      final draft = drafts[id];
      final conflict = conflicts[id];
      if (resetDraftFor.contains(id) || old == null || draft == null) {
        baseline[id] = account;
        drafts[id] = AdminMemberDraft.fromAccount(account);
        conflicts.remove(id);
      } else if (conflict != null) {
        conflicts[id] = conflict.withCurrent(account);
      } else if (draft != AdminMemberDraft.fromAccount(old)) {
        if (old.updatedAt != account.updatedAt) {
          conflicts[id] = AdminMemberConflict(before: old, current: account);
        }
      } else {
        baseline[id] = account;
        drafts[id] = AdminMemberDraft.fromAccount(account);
      }
    }
    emit();
  }

  @override
  void dispose() {
    _disposed = true;
    search.dispose();
    super.dispose();
  }
}
