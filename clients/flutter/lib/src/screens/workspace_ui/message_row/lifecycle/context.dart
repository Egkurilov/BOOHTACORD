import '../../native_bindings.dart';

abstract class WorkspaceMessageRowContext extends StatelessWidget {
  const WorkspaceMessageRowContext({
    super.key,
    required this.state,
    required this.message,
    this.grouped = false,
    this.replyPreview,
    this.onReply,
    this.onJumpToReply,
    this.onRetry,
  });
  final AppState state;
  final ChatMessage message;
  final bool grouped;
  final String? replyPreview;
  final ValueChanged<ChatMessage>? onReply;
  final VoidCallback? onJumpToReply;
  final VoidCallback? onRetry;
}
