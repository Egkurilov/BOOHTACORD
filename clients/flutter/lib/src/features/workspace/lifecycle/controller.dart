import 'package:flutter/foundation.dart';

import '../../../core/session/scope.dart';
import '../../../guild_presence_state.dart';
import '../../../models.dart';
import '../../../services/api_client.dart';
import 'effects.dart';
import 'types.dart';
export 'effects.dart';
export 'types.dart';
export '../navigation/controller.dart';
export '../load_members/controller.dart';
export '../load_topology/controller.dart';
export '../load_directs/controller.dart';
export '../search/navigation.dart';
export '../search/context.dart';
export '../search/resolve.dart';

class WorkspaceController extends ChangeNotifier {
  WorkspaceController(this.api, this.scope, {required this.effects});
  final ApiClient api;
  final SessionScope scope;
  final WorkspaceEffects effects;
  bool disposed = false;
  ChannelTopology? topology;
  List<GuildMember> members = const [];
  final GuildPresenceState guildPresence = GuildPresenceState();
  bool membersLoading = false;
  String? membersError;
  List<DirectConversation> directMessages = const [];
  List<DirectCandidate> directMessageCandidates = const [];
  DirectConversation? selectedDirectMessage;
  GuildChannel? selectedChannel;
  NavigationSection navigationSection = NavigationSection.channels;
  WorkspacePanel workspacePanel = WorkspacePanel.none;
  SearchMessage? searchContextMessage;
  String searchContextHeading = 'Контекст найденного сообщения';
  List<ChatMessage> searchContextTextMessages = const [];
  List<DirectChatMessage> searchContextDirectMessages = const [];
  bool loadingSearchContext = false;
  String? searchContextError;
  GuildChannel? searchOriginChannel;
  DirectConversation? searchOriginDirectMessage;
  int searchContextSequence = 0;

  bool accepts(SessionTicket ticket) => !disposed && ticket.isActive;
  void changed() {
    if (!disposed) notifyListeners();
  }

  void clear() {
    searchContextSequence++;
    topology = null;
    members = const [];
    membersLoading = false;
    membersError = null;
    guildPresence.invalidate();
    directMessages = const [];
    directMessageCandidates = const [];
    selectedDirectMessage = null;
    selectedChannel = null;
    navigationSection = NavigationSection.channels;
    workspacePanel = WorkspacePanel.none;
    searchContextMessage = null;
    searchContextHeading = 'Контекст найденного сообщения';
    searchContextTextMessages = const [];
    searchContextDirectMessages = const [];
    loadingSearchContext = false;
    searchContextError = null;
    searchOriginChannel = null;
    searchOriginDirectMessage = null;
  }

  @override
  void dispose() {
    disposed = true;
    clear();
    super.dispose();
  }
}
