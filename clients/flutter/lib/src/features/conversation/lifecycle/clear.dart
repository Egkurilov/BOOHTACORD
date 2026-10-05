import '../../../services/composer_draft_memory.dart';
import 'controller.dart';

extension ConversationCleanup on ConversationController {
  void clear() {
    cacheGeneration++;
    invalidateSelection();
    ComposerDraftMemory.clear();
    clearText();
    clearDirect();
    sending = false;
    sendRetryIds.clear();
    blockedSendRetries.clear();
    pendingTextSends.clear();
    pendingDirectSends.clear();
    lastReadDirectMessageId = null;
    lastReadTextCursor.clear();
    pendingTextReadCursor.clear();
    pendingTextReads.clear();
  }

  void clearText() {
    invalidateSelection();
    messages = const [];
    nextMessageCursor = null;
    olderTextHistoryError = null;
    textHistoryHasLoadedOlderPages = false;
  }

  void clearDirect() {
    invalidateSelection();
    directMessageHistory = const [];
    nextDirectMessageCursor = null;
    olderDirectHistoryError = null;
    lastReadDirectMessageId = null;
  }
}
