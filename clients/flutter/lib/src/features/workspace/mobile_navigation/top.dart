import 'package:flutter/material.dart';

import 'guild_header.dart';
import 'search_launcher.dart';
import 'tabs.dart';

class WorkspaceNavigationTop extends StatelessWidget {
  const WorkspaceNavigationTop({
    super.key,
    required this.memberCount,
    required this.channelsSelected,
    required this.onSearch,
    required this.onChannels,
    required this.onDirectMessages,
    this.onClose,
    this.searchFocusNode,
    this.guildName = 'BOOHTACORD',
  });

  final int? memberCount;
  final String guildName;
  final bool channelsSelected;
  final VoidCallback onSearch;
  final VoidCallback onChannels;
  final VoidCallback onDirectMessages;
  final VoidCallback? onClose;
  final FocusNode? searchFocusNode;

  @override
  Widget build(BuildContext context) {
    final compact = onClose != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        WorkspaceGuildHeader(
          guildName: guildName,
          compact: compact,
          memberCount: memberCount,
          onClose: onClose,
        ),
        WorkspaceNavigationSearch(
          compact: compact,
          onPressed: onSearch,
          focusNode: searchFocusNode,
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: WorkspaceNavigationTabs(
            channelsSelected: channelsSelected,
            onChannels: onChannels,
            onDirectMessages: onDirectMessages,
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
