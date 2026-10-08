import '../message_edit_dialog/component.dart';
import '../native_bindings.dart';

Future<void> workspaceEditMessageDialog(
  BuildContext context,
  String initialValue,
  int initialRevision,
  List<String> initialMentionIds,
  List<(String, String)> mentionOptions,
  String selfId,
  Future<MessageEditOutcome> Function(String, int, List<String>) onSave,
  Future<({int revision, bool deleted})?> Function() onRefresh,
) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => WorkspaceMessageEditDialog(
    initialValue: initialValue,
    initialRevision: initialRevision,
    initialMentionIds: initialMentionIds,
    mentionOptions: mentionOptions,
    selfId: selfId,
    onSave: onSave,
    onRefresh: onRefresh,
  ),
);
