import '../../native_bindings.dart';

abstract class WorkspaceVoiceDockContext extends StatelessWidget {
  const WorkspaceVoiceDockContext({
    super.key,
    required this.state,
    this.compact = false,
  });
  final AppState state;
  final bool compact;
  String get workspaceStatus;
  bool get workspaceConnected;
  String get workspaceSubtitle;
}
