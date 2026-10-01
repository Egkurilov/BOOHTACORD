import '../models.dart';

enum ComposerDraftKind { channel, directMessage }

class ComposerDraft<TReply> {
  const ComposerDraft({
    required this.body,
    required this.replyTarget,
    required this.attachments,
    required this.mentionUserIds,
  });

  final String body;
  final TReply? replyTarget;
  final List<MessageAttachment> attachments;
  final List<String> mentionUserIds;
}

/// Holds unsent composer state while the authenticated workspace stays open.
/// Drafts are scoped by account, conversation type, and conversation ID.
abstract final class ComposerDraftMemory {
  static final Map<String, ComposerDraft<Object?>> _drafts = {};
  static int _epoch = 0;

  static int get epoch => _epoch;

  static String _key(
    String accountId,
    ComposerDraftKind kind,
    String conversationId,
  ) => '$accountId\u0000${kind.name}\u0000$conversationId';

  static ComposerDraft<TReply>? load<TReply>(
    String accountId,
    ComposerDraftKind kind,
    String conversationId,
  ) {
    final draft = _drafts[_key(accountId, kind, conversationId)];
    if (draft == null) return null;
    return ComposerDraft<TReply>(
      body: draft.body,
      replyTarget: draft.replyTarget as TReply?,
      attachments: List.unmodifiable(draft.attachments),
      mentionUserIds: List.unmodifiable(draft.mentionUserIds),
    );
  }

  static void save<TReply>(
    String accountId,
    ComposerDraftKind kind,
    String conversationId,
    ComposerDraft<TReply> draft,
  ) {
    final key = _key(accountId, kind, conversationId);
    if (draft.body.isEmpty &&
        draft.replyTarget == null &&
        draft.attachments.isEmpty &&
        draft.mentionUserIds.isEmpty) {
      _drafts.remove(key);
      return;
    }
    _drafts[key] = ComposerDraft<Object?>(
      body: draft.body,
      replyTarget: draft.replyTarget,
      attachments: List.unmodifiable(draft.attachments),
      mentionUserIds: List.unmodifiable(draft.mentionUserIds),
    );
  }

  static void clear() {
    _epoch++;
    _drafts.clear();
  }
}
