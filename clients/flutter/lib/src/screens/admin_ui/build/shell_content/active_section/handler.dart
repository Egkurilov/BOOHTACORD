import '../../category_creation/handler.dart';
import '../../category_selection/handler.dart';
import '../../channel_creation/handler.dart';
import '../../channel_move/handler.dart';
import '../../channel_archive/handler.dart';
import '../../voice_admission/handler.dart';
import '../../../native_bindings.dart';
import '../../../lifecycle/context.dart';

extension RenderAdminActiveSectionAction on AdminScreenStateContext {
  List<Widget> renderAdminActiveSection(
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
      child: adminSelectedAdminSection == AdminSection.guild
          ? AdminGuildSettings(
              api: widget.state.api,
              channels:
                  widget.state.topology?.categories
                      .expand((category) => category.channels)
                      .toList() ??
                  [],
              onSaved: widget.state.guildProfile.refresh,
            )
          : adminSelectedAdminSection == AdminSection.roles
          ? RolePermissionsPanel(
              api: widget.state.api,
              onSaved: widget.state.permissions.refresh,
            )
          : adminSelectedAdminSection == AdminSection.audit
          ? adminBuildAuditPanel()
          : adminSelectedAdminSection == AdminSection.media
          ? adminBuildMediaPanel()
          : adminSelectedAdminSection == AdminSection.readiness
          ? AdminReadinessPanel(api: widget.state.api)
          : adminSelectedAdminSection == AdminSection.members
          ? adminBuildMembersPanel()
          : ListView(
              padding: EdgeInsets.fromLTRB(
                adminContentInset,
                0,
                adminContentInset,
                24,
              ),
              children: [
                adminSection(
                  title: 'Управление каналами',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ...renderAdminCategoryCreation(
                        categories,
                        expandedCategoryId,
                        selectedCategory,
                      ),
                      ...renderAdminCategorySelection(
                        selectedId,
                        categories,
                        selectedCategory,
                        channels,
                        selectedChannel,
                      ),
                      ...renderAdminChannelCreation(categories),
                      ...renderAdminChannelMove(categories, moveSourceCategory),
                      ...renderAdminChannelArchive(textChannels, allChannels),
                      ...renderAdminVoiceAdmission(voiceChannels, allChannels),
                    ],
                  ),
                ),
                if (adminStatus != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Semantics(
                      liveRegion: true,
                      label: adminStatus,
                      child: Text(
                        adminStatus!,
                        style: const TextStyle(color: GcColors.success),
                      ),
                    ),
                  ),
                if (adminError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Semantics(
                      liveRegion: true,
                      label: adminError,
                      child: Text(
                        adminError!,
                        style: const TextStyle(color: GcColors.danger),
                      ),
                    ),
                  ),
              ],
            ),
    ),
  ];
}
