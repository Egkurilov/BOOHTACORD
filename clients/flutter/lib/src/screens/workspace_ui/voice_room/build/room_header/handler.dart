import '../../../header/component.dart';
import '../../../show_screen_share_setup/component.dart';
import '../../../voice_prejoin_header_subtitle/component.dart';
import '../../../native_bindings.dart';
import '../../lifecycle/context.dart';

extension VoiceRoomRoomHeaderRenderer on WorkspaceVoiceRoomStateContext {
  WorkspaceHeader renderVoiceRoomRoomHeader(
    GuildChannel channel,
    String? selectedName,
    bool active,
    AppState state,
    int participantCount,
    BuildContext context,
  ) => WorkspaceHeader(
    icon: Icons.volume_up_outlined,
    title: channel.name,
    onToggleNavigation: widget.onToggleNavigation,
    onOpenMembers: widget.onOpenMembers,
    subtitle: selectedName != null
        ? 'Демонстрация $selectedName'
        : active
        ? state.voicePhase == VoicePhase.reconnecting
              ? 'Восстанавливаем связь · состояние микрофона сохранено'
              : 'Голосовой канал · участников: $participantCount'
        : workspaceVoicePrejoinHeaderSubtitle(state, channel),
    trailing: active
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (state.screenSharePhase == ScreenSharePhase.sharing)
                IconButton(
                  tooltip: 'Изменить качество и FPS',
                  onPressed: () =>
                      unawaited(workspaceShowScreenShareSetup(context, state)),
                  icon: const Icon(Icons.tune),
                ),
              IconButton(
                tooltip: state.screenSharePhase == ScreenSharePhase.sharing
                    ? 'Остановить демонстрацию экрана'
                    : 'Начать демонстрацию экрана',
                onPressed: switch (state.screenSharePhase) {
                  ScreenSharePhase.starting ||
                  ScreenSharePhase.stopping => null,
                  ScreenSharePhase.sharing => state.stopScreenShare,
                  _ => () => workspaceToggleLocalScreenShare(state),
                },
                icon:
                    state.screenSharePhase == ScreenSharePhase.starting ||
                        state.screenSharePhase == ScreenSharePhase.stopping
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        state.screenSharePhase == ScreenSharePhase.sharing
                            ? Icons.stop_screen_share_outlined
                            : Icons.screen_share_outlined,
                      ),
              ),
            ],
          )
        : null,
  );
}
