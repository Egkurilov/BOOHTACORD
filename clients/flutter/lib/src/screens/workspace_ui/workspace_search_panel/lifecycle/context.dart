import '../../native_bindings.dart';

import 'widget.dart';

abstract class WorkspaceWorkspaceSearchPanelStateContext
    extends State<WorkspaceWorkspaceSearchPanel> {
  final workspaceQuery = TextEditingController();
  final workspaceScroll = ScrollController();
  String workspaceScope = 'all';
  String workspaceActiveQuery = '';
  String? workspaceNextCursor;
  String? workspaceError;
  bool workspaceLoading = false;
  bool workspaceSearched = false;
  bool navigationMode = false;
  bool pinsMode = false;
  int workspaceSequence = 0;
  List<SearchMessage> workspaceResults = const [];
  void workspaceQueryChanged();
  bool get workspaceCanLoadMore;
  bool get workspaceCanSubmit;
  AppState get state;
  ({String id, String label, bool direct})? workspaceCurrentConversation();
  void workspaceReset();
  Future<void> workspaceSearch({String? before});
  String workspaceConversationLabel(SearchMessage message);
  void workspaceMutateView(VoidCallback action) => setState(action);
}
