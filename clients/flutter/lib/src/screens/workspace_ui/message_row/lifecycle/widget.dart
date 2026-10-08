import 'context.dart';
import '../handler_bindings.dart';

class WorkspaceMessageRow extends WorkspaceMessageRowContext
    with WorkspaceMessageRowBuildBinding {
  const WorkspaceMessageRow({
    super.key,
    required super.state,
    required super.message,
    super.grouped = false,
    super.replyPreview,
    super.onReply,
    super.onJumpToReply,
    super.onRetry,
  });
}
