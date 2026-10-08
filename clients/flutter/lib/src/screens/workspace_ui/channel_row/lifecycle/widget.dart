import '../../native_bindings.dart';

import 'context.dart';
import '../handler_bindings.dart';

class WorkspaceChannelRow extends StatefulWidget {
  const WorkspaceChannelRow({
    super.key,
    required this.state,
    required this.channel,
    required this.selected,
    required this.voiceConnected,
    this.voiceParticipantCount,
    required this.onTap,
  });
  final AppState state;
  final GuildChannel channel;
  final bool selected;
  final bool voiceConnected;
  final int? voiceParticipantCount;
  final VoidCallback onTap;

  @override
  State<WorkspaceChannelRow> createState() => WorkspaceChannelRowState();
}

class WorkspaceChannelRowState extends WorkspaceChannelRowStateContext
    with
        WorkspaceChannelRowStateWorkspaceShowObjectMenuBinding,
        WorkspaceChannelRowStateBuildBinding {}
