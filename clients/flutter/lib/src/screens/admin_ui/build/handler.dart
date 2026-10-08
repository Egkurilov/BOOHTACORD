import 'shell_header/handler.dart';
import 'shell_content/handler.dart';
import '../native_bindings.dart';
import '../lifecycle/context.dart';

mixin AdminScreenStateBuildBinding on AdminScreenStateContext {
  @override
  Widget build(BuildContext context) => executeAdminBuild(context);
}

extension AdminScreenStateBuildBindingAction on AdminScreenStateContext {
  Widget executeAdminBuild(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < GcLayout.mobileBreakpoint;
    final categories =
        widget.state.topology?.categories ?? const <ChannelCategory>[];
    final selectedId = categories.any((item) => item.id == adminCategoryId)
        ? adminCategoryId
        : categories.firstOrNull?.id;
    final selectedCategory = categories
        .where((item) => item.id == selectedId)
        .firstOrNull;
    final expandedCategoryId =
        selectedId != null &&
            !adminCollapsedTopologyCategories.contains(selectedId)
        ? selectedId
        : null;
    final channels = selectedCategory?.channels ?? const <GuildChannel>[];
    final selectedChannel = channels
        .where((item) => item.id == adminChannelId)
        .firstOrNull;
    final moveSourceCategory = categories
        .where(
          (category) => category.channels.any(
            (channel) => channel.id == adminMoveChannelId,
          ),
        )
        .firstOrNull;
    final allChannels = categories
        .expand((category) => category.channels)
        .toList(growable: false);
    final textChannels = allChannels
        .where((channel) => channel.kind == ChannelKind.text)
        .toList(growable: false);
    final voiceChannels = allChannels
        .where((channel) => channel.kind == ChannelKind.voice)
        .toList(growable: false);
    return Material(
      color: GcColors.content,
      child: Column(
        children: [
          ...renderAdminShellHeader(compact),
          ...renderAdminShellContent(
            compact,
            width,
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
    );
  }
}
