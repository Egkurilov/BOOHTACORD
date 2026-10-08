import 'section_tabs/handler.dart';
import 'active_section/handler.dart';
import '../../native_bindings.dart';
import '../../lifecycle/context.dart';

extension RenderAdminShellContentAction on AdminScreenStateContext {
  List<Widget> renderAdminShellContent(
    bool compact,
    double width,
    List<ChannelCategory> categories,
    String? expandedCategoryId,
    ChannelCategory? selectedCategory,
    String? selectedId,
    List<GuildChannel> channels,
    GuildChannel? selectedChannel,
    ChannelCategory? moveSourceCategory,
    List<GuildChannel> textChannels,
    List<GuildChannel> allChannels,
    List<GuildChannel> voiceChannels,
  ) => [
    Expanded(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880),
          child: SizedBox(
            key: const ValueKey('admin-content-panel'),
            width: double.infinity,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                compact ? 16 : 0,
                compact ? 24 : 32,
                compact ? 16 : 0,
                0,
              ),
              child: Column(
                children: [
                  ...renderAdminSectionTabs(width),
                  ...renderAdminActiveSection(
                    categories,
                    expandedCategoryId,
                    selectedCategory,
                    selectedId,
                    channels,
                    selectedChannel,
                    moveSourceCategory,
                    textChannels,
                    allChannels,
                    voiceChannels,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  ];
}
