import 'package:livekit_client/livekit_client.dart' hide ChatMessage;

import '../../models.dart';
import '../../features/voice/lifecycle/controller.dart';
import '../composition/owners.dart';

mixin AppVoiceControlsAccess on AppOwners {
  VoicePhase get voicePhase => voice.voicePhase;

  set voicePhase(VoicePhase value) => voice.voicePhase = value;

  GuildChannel? get voiceChannel => voice.voiceChannel;

  set voiceChannel(GuildChannel? value) => voice.voiceChannel = value;

  bool get microphoneMuted => voice.microphoneMuted;

  set microphoneMuted(bool value) => voice.microphoneMuted = value;

  bool get microphoneUnavailable => voice.microphoneUnavailable;

  set microphoneUnavailable(bool value) => voice.microphoneUnavailable = value;

  bool get deafened => voice.deafened;

  set deafened(bool value) => voice.deafened = value;

  bool get deafenChanging => voice.deafenChanging;

  set deafenChanging(bool value) => voice.deafenChanging = value;

  bool get voiceStreamSoundEnabled => voice.voiceStreamSoundEnabled;

  set voiceStreamSoundEnabled(bool value) =>
      voice.voiceStreamSoundEnabled = value;

  bool get voiceStreamStartNotice => voice.voiceStreamStartNotice;

  set voiceStreamStartNotice(bool value) =>
      voice.voiceStreamStartNotice = value;

  AudioActivationMode get audioActivationMode => voice.audioActivationMode;

  bool get usesTouchPushToTalk => voice.usesTouchPushToTalk;

  set audioActivationMode(AudioActivationMode value) =>
      voice.audioActivationMode = value;

  int? get pushToTalkKeyId => voice.pushToTalkKeyId;

  set pushToTalkKeyId(int? value) => voice.pushToTalkKeyId = value;

  String? get pushToTalkKeyLabel => voice.pushToTalkKeyLabel;

  set pushToTalkKeyLabel(String? value) => voice.pushToTalkKeyLabel = value;

  String? get audioActivationError => voice.audioActivationError;

  set audioActivationError(String? value) => voice.audioActivationError = value;

  bool get pushToTalkPressed => voice.pushToTalkPressed;

  set pushToTalkPressed(bool value) => voice.pushToTalkPressed = value;

  Room? get room => voice.room;

  ConnectionQuality get voiceConnectionQuality =>
      voice.room?.localParticipant?.connectionQuality ??
      ConnectionQuality.unknown;

  int? get voicePingMs => voice.voicePingMs;

  Future<void> setVoiceStreamSoundEnabled(bool enabled) =>
      voice.setVoiceStreamSoundEnabled(enabled);

  Future<void> setPushToTalkKey(int? keyId, String? label) =>
      voice.setPushToTalkKey(keyId, label);

  Future<void> setAudioActivationMode(AudioActivationMode next) =>
      voice.setAudioActivationMode(next);

  Future<void> setPushToTalkPressed(bool pressed) =>
      voice.setPushToTalkPressed(pressed);

  Future<void> selectRemoteScreenForViewing(String? identity) =>
      voice.selectRemoteScreenForViewing(identity);

  Future<void> joinVoice(GuildChannel channel, {bool listenerOnly = false}) =>
      voice.joinVoice(channel, listenerOnly: listenerOnly);

  Future<void> toggleMicrophone() => voice.toggleMicrophone();

  Future<void> toggleDeafen() => voice.toggleDeafen();

  Future<void> leaveVoice() => voice.leaveVoice();
}
