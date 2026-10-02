import '../../models.dart';
import '../../features/voice/lifecycle/controller.dart';
import '../../features/workspace/lifecycle/controller.dart';
import '../composition/owners.dart';

mixin AppVoiceNavigationAccess on AppOwners {
  Future<void> enterVoiceChannel(GuildChannel channel) async {
    final ticket = session.scope.capture();
    if (!ticket.isActive) return;
    await workspace.selectChannel(channel);
    if (!ticket.isActive) return;
    if (channel.kind != ChannelKind.voice || channel.admissionClosed) return;
    if (voice.voiceChannel?.id == channel.id ||
        voice.voicePhase == VoicePhase.joining) {
      return;
    }
    if (voice.voiceChannel != null) await voice.leaveVoice();
    if (!ticket.isActive) return;
    await voice.joinVoice(channel);
  }
}
