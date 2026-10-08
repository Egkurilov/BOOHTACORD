import '../../native_bindings.dart';

import 'context.dart';
import '../handler_bindings.dart';

class WorkspaceMessageEditDialog extends StatefulWidget {
  const WorkspaceMessageEditDialog({
    super.key,
    required this.initialValue,
    required this.initialRevision,
    required this.initialMentionIds,
    required this.mentionOptions,
    required this.selfId,
    required this.onSave,
    required this.onRefresh,
  });

  final String initialValue;
  final int initialRevision;
  final List<String> initialMentionIds;
  final List<(String, String)> mentionOptions;
  final String selfId;
  final Future<MessageEditOutcome> Function(String, int, List<String>) onSave;
  final Future<({int revision, bool deleted})?> Function() onRefresh;

  @override
  State<WorkspaceMessageEditDialog> createState() =>
      WorkspaceMessageEditDialogState();
}

class WorkspaceMessageEditDialogState
    extends WorkspaceMessageEditDialogStateContext
    with
        WorkspaceMessageEditDialogStateInitStateBinding,
        WorkspaceMessageEditDialogStateDisposeBinding,
        WorkspaceMessageEditDialogStateWorkspaceSaveBinding,
        WorkspaceMessageEditDialogStateWorkspaceRefreshBinding,
        WorkspaceMessageEditDialogStateBuildBinding {}
