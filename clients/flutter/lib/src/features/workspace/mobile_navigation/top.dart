import 'package:flutter/material.dart';

import '../../../theme.dart';
import 'guild_mark.dart';
import 'search_launcher.dart';
import 'tabs.dart';
import '../../guild/profile/name.dart';

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

  String get _memberLabel {
    final count = memberCount!;
    final lastTwo = count % 100;
    final one = count % 10 == 1 && lastTwo != 11;
    final few =
        count % 10 >= 2 && count % 10 <= 4 && (lastTwo < 12 || lastTwo > 14);
    return '$count ${one
        ? 'участник'
        : few
        ? 'участника'
        : 'участников'}';
  }

  @override
  Widget build(BuildContext context) {
    final compact = onClose != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DecoratedBox(
          key: const ValueKey('navigation-guild-header-surface'),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: GcColors.borderSubtle)),
          ),
          child: SizedBox(
            key: const ValueKey('navigation-guild-header'),
            height: GcLayout.headerHeight,
            child: Padding(
              padding: EdgeInsets.only(left: compact ? 12 : 16, right: 16),
              child: Row(
                children: [
                  const WorkspaceGuildMark(),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GuildName(
                          guildName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            height: 20 / 15,
                          ),
                        ),
                        if (memberCount != null)
                          Text(
                            _memberLabel,
                            style: const TextStyle(
                              color: GcColors.muted,
                              fontSize: 12,
                              height: 16 / 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(
                    key: ValueKey('navigation-guild-chevron'),
                    width: 36,
                    height: 36,
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: GcColors.textSecondary,
                    ),
                  ),
                  if (onClose != null)
                    SizedBox(
                      width: 44,
                      height: 44,
                      child: IconButton(
                        tooltip: 'Закрыть навигацию',
                        onPressed: onClose,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(
                          width: 44,
                          height: 44,
                        ),
                        icon: const Icon(Icons.close, size: 20),
                      ),
                    ),
                ],
              ),
            ),
          ),
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
