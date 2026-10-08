import 'load_failure/handler.dart';
import 'header/handler.dart';
import '../../member_summary/handler.dart';
import '../../../../member_profile_action_style/component.dart';
import '../../../../native_bindings.dart';
import '../../../lifecycle/context.dart';

extension MemberProfilePopoverColumnRenderer
    on WorkspaceMemberProfilePopoverStateContext {
  Column renderMemberProfilePopoverColumn(
    bool canMessage,
    bool canKick,
    RemoteParticipant? participant,
    BuildContext context,
  ) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      renderMemberProfilePopoverHeader(),
      const SizedBox(height: GcSpacing.x4),
      if (workspaceLoading)
        Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Semantics(liveRegion: true, child: Text('Загружаем профиль…')),
        )
      else if (workspaceError != null)
        renderMemberProfilePopoverLoadFailure()
      else if (workspaceMember case final member?) ...[
        renderMemberProfilePopoverMemberSummary(member),
        if (canMessage || canKick) ...[
          const SizedBox(height: GcSpacing.x4),
          if (canMessage)
            OutlinedButton(
              onPressed: member.id == widget.state.user?.accountId
                  ? null
                  : () => widget.onOpenDirectMessage(member),
              style: workspaceMemberProfileActionStyle,
              child: const Text('Сообщение'),
            ),
          if (canKick && participant != null) ...[
            const SizedBox(height: GcSpacing.x2),
            OutlinedButton.icon(
              onPressed: workspaceKicking
                  ? null
                  : () => workspaceKick(participant),
              icon: const Icon(Icons.call_end, size: 18),
              label: Text(
                workspaceKicking ? 'Отключаем…' : 'Отключить от голоса',
              ),
              style: workspaceMemberProfileActionStyle,
            ),
          ],
        ],
        if (participant != null) ...[
          const SizedBox(height: GcSpacing.x4),
          const Text(
            'Громкость участника',
            style: TextStyle(
              color: GcColors.textSecondary,
              fontSize: 13,
              height: 18 / 13,
            ),
          ),
          const SizedBox(height: GcSpacing.x2),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Text(
              '${widget.state.participantVolume(participant) ?? 100}%',
              style: const TextStyle(
                color: GcColors.textSecondary,
                fontSize: 13,
                height: 18 / 13,
              ),
            ),
          ),
          const SizedBox(height: GcSpacing.x2),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: GcColors.accent,
              thumbColor: GcColors.accent,
              inactiveTrackColor: GcColors.control.withValues(alpha: 0.55),
            ),
            child: ParticipantVolumeSlider(
              name: member.displayName,
              volume: widget.state.participantVolume(participant) ?? 100,
              onChanged: (value) => unawaited(
                widget.state.setParticipantVolume(participant, value),
              ),
              onChangeEnd: () => unawaited(widget.state.flushVoiceVolumes()),
            ),
          ),
        ],
        if (widget.state.voiceVolumeWarning != null)
          Semantics(
            liveRegion: true,
            child: Text(widget.state.voiceVolumeWarning!),
          ),
        if (workspaceError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              workspaceError!,
              style: const TextStyle(color: GcColors.danger),
            ),
          ),
        if (workspaceStatus != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Semantics(
              liveRegion: true,
              child: Text(
                workspaceStatus!,
                style: const TextStyle(color: GcColors.success),
              ),
            ),
          ),
      ],
    ],
  );
}
