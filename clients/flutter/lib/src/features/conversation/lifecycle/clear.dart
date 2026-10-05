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
    lastReadTextAt.clear();
    pendingTextReadAt.clear();
    pendingTextReads.clear();
  }

  void clearText() {
    invalidateSelection();
    messages = const [];
    nextMessageCursor = null;
    textHistoryHasLoadedOlderPages = false;
  }

  void clearDirect() {
    invalidateSelection();
    directMessageHistory = const [];
    nextDirectMessageCursor = null;
    lastReadDirectMessageId = null;
  }
}
