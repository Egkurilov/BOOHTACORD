import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models.dart';
import '../../../theme.dart';
import '../../../widgets/confirmation_dialog.dart';
import '../layout/width_class.dart';
import 'compact_cards.dart';
import 'conflict_review.dart';
import 'desktop_table.dart';
import 'filters.dart';
import 'reset_result.dart';
import 'state.dart';

class AdminMembersPanel extends StatefulWidget {
  const AdminMembersPanel({super.key, required this.controller, required this.currentAccountId, required this.voiceParticipantIds});
  final AdminMembersState controller;
  final String? currentAccountId;
  final Set<String> voiceParticipantIds;
  @override
  State<AdminMembersPanel> createState() => _AdminMembersPanelState();
}

class _AdminMembersPanelState extends State<AdminMembersPanel> {
  final _focus = <String, FocusNode>{};
  final _resetFocus = FocusNode(debugLabel: 'admin-member-reset-url');
  AdminMembersState get c => widget.controller;
  FocusNode _node(String id) => _focus.putIfAbsent(id, () => FocusNode(debugLabel: 'admin-member-actions:$id'));
  void _restore(String id) => WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted && _node(id).context != null) _node(id).requestFocus(); });
  void _focusReset() => WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted && _resetFocus.context != null) _resetFocus.requestFocus(); });
  @override
  void dispose() { for (final node in _focus.values) { node.dispose(); } _resetFocus.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: c,
    builder: (context, _) => Column(children: [
      _header(),
      AdminMembersFilters(search: c.search, role: c.roleFilter, onRoleChanged: c.setRoleFilter),
      if (c.error != null) _notice(c.error!, true),
      if (c.status != null) _notice(c.status!, false),
      Expanded(child: c.loading && c.accounts.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : c.error != null && c.accounts.isEmpty ? const Center(child: Text('Список участников недоступен.'))
          : c.accounts.isEmpty ? const Center(child: Text('Участников пока нет.')) : _list(context)),
    ]),
  );

  Widget _header() => Padding(
    padding: const EdgeInsets.fromLTRB(24, 18, 24, 14),
    child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Участники ${c.accounts.length}', key: const ValueKey('admin-members-section-title'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
        const Text('Роли и доступ к этой гильдии', style: TextStyle(color: GcColors.textSecondary, fontSize: 12)),
      ])),
      TextButton.icon(onPressed: c.loading ? null : () => c.refresh(), icon: const Icon(Icons.refresh), label: const Text('Обновить')),
    ]),
  );

  Widget _list(BuildContext context) => AdminWidthBuilder(builder: (context, width) {
    final visible = c.visibleAccounts;
    return ListView(padding: const EdgeInsets.only(bottom: 20), children: [
      if (c.resetResult case final result?) AdminMemberResetResultCard(
        result: result, focusNode: _resetFocus,
        onClose: () { c.dismissResetLink(); _restore(result.account.accountId); },
        onCopy: () async {
          try { await Clipboard.setData(ClipboardData(text: result.link.url)); }
          catch (cause) { if (!mounted) return; c.error = cause.toString(); }
          if (!mounted) return;
          c.status = 'Ссылка скопирована.';
          c.emit();
          _restore(result.account.accountId);
        },
      ),
      for (final account in visible) if (c.conflicts[account.accountId] case final conflict?)
        AdminMemberConflictReview(
          conflict: conflict, proposed: c.drafts[account.accountId]!, busy: c.busyAccountIds.contains(account.accountId),
          onRefresh: () => c.refresh(), onDiscard: () => c.resolveConflict(account.accountId, discard: true),
          onApply: () { c.resolveConflict(account.accountId, discard: false); unawaited(c.saveAccount(account.accountId)); },
        ),
      if (visible.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('По текущему фильтру участники не найдены.')))
      else if (width.isExpanded) AdminMembersDesktopTable(
        controller: c, accounts: visible, currentAccountId: widget.currentAccountId,
        voiceParticipantIds: widget.voiceParticipantIds, actionFocusNode: _node,
        onSave: (account) async { await c.saveAccount(account.accountId); _restore(account.accountId); },
        onReset: (account) async { await c.createResetLink(account.accountId); if (mounted && c.resetResult != null) _focusReset(); },
        onKick: (account) => _kick(context, account),
      ) else for (final account in visible) AdminMembersCompactCard(
        controller: c, account: account,
        canKick: widget.voiceParticipantIds.contains(account.accountId) && account.accountId != widget.currentAccountId,
        focusNode: _node(account.accountId),
        onSave: () async { await c.saveAccount(account.accountId); _restore(account.accountId); },
        onReset: () async { await c.createResetLink(account.accountId); if (mounted && c.resetResult != null) _focusReset(); },
        onKick: () => _kick(context, account),
      ),
      if (c.loading) const Center(child: CircularProgressIndicator()),
      if (c.nextCursor != null) Center(child: TextButton(onPressed: c.loading ? null : c.loadNextPage, child: const Text('Загрузить ещё'))),
    ]);
  });

  Future<void> _kick(BuildContext context, AdminAccount account) async {
    final yes = await showConfirmationDialog<bool>(context: context, builder: (context) => AlertDialog(
        title: const Text('Отключить от голоса?'),
      content: const Text('Отключить участника от голосового канала?'),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
        FilledButton.tonal(onPressed: () => Navigator.pop(context, true), child: const Text('Отключить'))],
    ));
    if (!mounted) return;
    if (yes == true) await c.kickVoiceParticipant(account.accountId);
    _restore(account.accountId);
  }

  Widget _notice(String text, bool error) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
    child: Semantics(liveRegion: true, child: Text(text, style: TextStyle(color: error ? GcColors.danger : GcColors.success))),
  );
}
