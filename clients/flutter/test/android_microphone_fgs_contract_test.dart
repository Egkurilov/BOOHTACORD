import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('microphone FGS is private, independent and cannot capture or restart itself', () {
    const root = 'packages/boohtacord_voice_foreground/android/src/main';
    final manifest = File('$root/AndroidManifest.xml').readAsStringSync();
    final service = File('$root/kotlin/ru/boohtacord/voice/start/MicrophoneService.kt').readAsStringSync();
    final plugin = File('$root/kotlin/ru/boohtacord/voice/start/VoiceMicrophonePlugin.kt').readAsStringSync();
    expect(manifest, contains('FOREGROUND_SERVICE_MICROPHONE'));
    expect(manifest, contains('android:foregroundServiceType="microphone"'));
    expect(manifest, contains('android:exported="false"'));
    expect(service, contains('FOREGROUND_SERVICE_TYPE_MICROPHONE'));
    expect(service, contains('START_NOT_STICKY'));
    expect(service, isNot(contains('AudioRecord')));
    expect(service, isNot(contains('MediaProjection')));
    expect(manifest, isNot(contains('BOOT_COMPLETED')));
    expect(plugin, contains('Manifest.permission.RECORD_AUDIO'));
    expect(plugin, contains('AdmissionPolicy.permitsStart'));
    expect(File('android/app/src/main/AndroidManifest.xml').readAsStringSync(),
      contains('android:foregroundServiceType="mediaProjection"'));
  });
}
