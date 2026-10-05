import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../core/session/scope.dart';
import '../../../models.dart';
import '../../../services/api_client.dart';
import '../../workspace/lifecycle/controller.dart';
import 'clear.dart';
export 'exports.dart';

class ConversationController extends ChangeNotifier {
  ConversationController(
    this.api,
    this.scope,
    this.workspace, {
    required this.readUser,
    required this.isReady,
    required this.reportError,
    required this.formatError,
  });
  final ApiClient api;
  final SessionScope scope;
  final WorkspaceController workspace;
  final SessionUser? Function() readUser;
  final bool Function() isReady;
  final void Function(String?) reportError;
  final String Function(Object) formatError;
  final Uuid uuid = const Uuid();
  bool disposed = false;
  int cacheGeneration = 0;
  int selectionRevision = 0;
  List<ChatMessage> messages = const [];
  String? nextMessageCursor;
  bool loadingOlderMessages = false;
  bool loadingMessages = false;
  bool textHistoryHasLoadedOlderPages = false;
  int textHistoryLoadSequence = 0;
  List<DirectChatMessage> directMessageHistory = const [];
  String? nextDirectMessageCursor;
  bool loadingOlderDirectMessages = false;
  bool loadingDirectMessages = false;
  bool sending = false;
  final Map<String, String> sendRetryIds = {};
  final Set<String> blockedSendRetries = {};
  final Map<String, ChatMessage> pendingTextSends = {};
  final Map<String, DirectChatMessage> pendingDirectSends = {};
  String? lastReadDirectMessageId;
  final Map<String, DateTime> lastReadTextAt = {};
  final Map<String, DateTime> pendingTextReadAt = {};
  final Set<String> pendingTextReads = {};
  SessionUser? get user => readUser();
  GuildChannel? get selectedChannel => workspace.selectedChannel;
  set selectedChannel(GuildChannel? value) => workspace.selectedChannel = value;
  DirectConversation? get selectedDirectMessage =>
      workspace.selectedDirectMessage;
  List<DirectConversation> get directMessages => workspace.directMessages;
  set directMessages(List<DirectConversation> value) =>
      workspace.directMessages = value;
  set topology(ChannelTopology value) => workspace.topology = value;
  set error(String? value) => reportError(value);

  bool Function() admission({bool selection = false}) {
    final ticket = scope.capture();
    final cache = cacheGeneration;
    final selected = selectionRevision;
    final navigation = workspace.selectionRevision;
    return () =>
        !disposed &&
        ticket.isActive &&
        cache == cacheGeneration &&
        (!selection ||
            selected == selectionRevision &&
                navigation == workspace.selectionRevision);
  }

  void changed() {
    if (!disposed) notifyListeners();
  }

  void invalidateSelection() {
    selectionRevision++;
    textHistoryLoadSequence++;
    loadingMessages = false;
    loadingDirectMessages = false;
    loadingOlderMessages = false;
    loadingOlderDirectMessages = false;
  }

  @override
  void dispose() {
    disposed = true;
    clear();
    super.dispose();
  }
}
