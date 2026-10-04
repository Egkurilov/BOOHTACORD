import 'package:livekit_client/livekit_client.dart';
import 'generated.dart';
var _selected = defaultVoiceAudioProfile;
Map<String, Object> get selectedVoiceAudioProfile =>
    voiceAudioProfiles.firstWhere((profile) => profile['id'] == _selected);
bool selectVoiceAudioProfile(String id) {
  if (!voiceAudioProfiles.any((profile) => profile['id'] == id)) return false;
  _selected = id;
  return true;
}
AudioPublishOptions profilePublishOptions(Map<String, Object> profile) =>
    AudioPublishOptions(
      encoding: AudioEncoding(
        maxBitrate: profile['maxBitrate']! as int,
        bitratePriority: Priority.high,
      ),
      dtx: profile['dtx']! as bool,
      red: profile['red']! as bool,
    );
String profileIdForBitrate(int? bitrate) => voiceAudioProfiles
    .where((profile) => profile['maxBitrate'] == bitrate)
    .map((profile) => profile['id']! as String)
    .firstOrNull ?? 'unknown';
