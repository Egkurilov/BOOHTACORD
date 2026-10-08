import 'context.dart';
import '../handler_bindings.dart';

class WorkspaceVoiceDock extends WorkspaceVoiceDockContext
    with
        WorkspaceVoiceDockWorkspaceStatusBinding,
        WorkspaceVoiceDockWorkspaceConnectedBinding,
        WorkspaceVoiceDockWorkspaceSubtitleBinding,
        WorkspaceVoiceDockBuildBinding {
  const WorkspaceVoiceDock({
    super.key,
    required super.state,
    super.compact = false,
  });
}
