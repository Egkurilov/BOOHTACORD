// Copyright 2026 LiveKit, Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:livekit_client/livekit_client.dart';

class _ObservedSender implements rtc.RTCRtpSender {
  final List<bool> enabledAtReplacement = [];
  @override
  Future<void> replaceTrack(rtc.MediaStreamTrack? track) async {
    enabledAtReplacement.add(track!.enabled);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Transceiver implements rtc.RTCRtpTransceiver {
  _Transceiver(this.sender);
  @override
  final rtc.RTCRtpSender sender;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  var captures = 0;
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  setUp(() {
    captures = 0;
    messenger.setMockMethodCallHandler(const MethodChannel('FlutterWebRTC.Event'), (_) async => null);
    messenger.setMockMethodCallHandler(const MethodChannel('FlutterWebRTC.Logs'), (_) async => null);
    messenger.setMockMethodCallHandler(const MethodChannel('livekit_client'), (_) async => null);
    messenger.setMockMethodCallHandler(const MethodChannel('FlutterWebRTC.Method'), (call) async {
      if (call.method == 'getUserMedia') {
        captures++;
        return {
          'streamId': 'capture-$captures',
          'audioTracks': [
            {'id': 'microphone-$captures', 'label': 'microphone', 'kind': 'audio', 'enabled': true},
          ],
          'videoTracks': [],
        };
      }
      return null;
    });
  });

  test('muted audio is disabled before sender replacement through recapture and rollback', () async {
    final track = await LocalAudioTrack.create();
    final sender = _ObservedSender();
    track.transceiver = _Transceiver(sender);
    addTearDown(track.dispose);
    track.updateMuted(true);

    await track.restartTrack(const AudioCaptureOptions(noiseSuppression: false));
    await track.restartTrack(const AudioCaptureOptions(noiseSuppression: true));

    expect(sender.enabledAtReplacement, [false, false]);
    expect(track.muted, isTrue);
    expect(track.mediaStreamTrack.enabled, isFalse);
  });

  test('unmuted audio remains enabled during ordinary recapture', () async {
    final track = await LocalAudioTrack.create();
    final sender = _ObservedSender();
    track.transceiver = _Transceiver(sender);
    addTearDown(track.dispose);

    await track.restartTrack();

    expect(sender.enabledAtReplacement, [true]);
    expect(track.muted, isFalse);
    expect(track.mediaStreamTrack.enabled, isTrue);
  });
}
