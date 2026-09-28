import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/src/native/media_stream_track_impl.dart';
import 'package:flutter_webrtc/src/native/track_ended_event_dispatcher.dart';

void main() {
  group('TrackEndedEventDispatcher', () {
    late StreamController<Map<String, dynamic>> events;
    late TrackEndedEventDispatcher dispatcher;

    setUp(() {
      events = StreamController<Map<String, dynamic>>.broadcast();
      dispatcher = TrackEndedEventDispatcher(events.stream);
    });

    tearDown(() async {
      await dispatcher.dispose();
      await events.close();
    });

    test('routes an ended event only to the matching track', () async {
      var firstEnded = 0;
      var secondEnded = 0;
      dispatcher.register('screen-1', () => firstEnded++);
      dispatcher.register('screen-2', () => secondEnded++);

      events.add({
        'onTrackEnded': {'event': 'onTrackEnded', 'trackId': 'screen-2'},
      });
      await Future<void>.delayed(Duration.zero);

      expect(firstEnded, 0);
      expect(secondEnded, 1);
    });

    test('fires an ended callback at most once', () async {
      var ended = 0;
      dispatcher.register('screen-1', () => ended++);
      final event = {
        'onTrackEnded': {'event': 'onTrackEnded', 'trackId': 'screen-1'},
      };

      events.add(event);
      events.add(event);
      await Future<void>.delayed(Duration.zero);

      expect(ended, 1);
    });

    test('remembers an ended event that arrives before track registration', () {
      var ended = 0;
      events.add({
        'onTrackEnded': {'event': 'onTrackEnded', 'trackId': 'screen-1'},
      });
      events.add({
        'onTrackEnded': {'event': 'onTrackEnded', 'trackId': 'screen-1'},
      });

      return Future<void>.delayed(Duration.zero, () {
        dispatcher.register('screen-1', () => ended++);
        expect(ended, 1);
      });
    });

    test('unregistering prevents later ended callbacks', () async {
      var ended = 0;
      void onEnded() => ended++;
      dispatcher.register('screen-1', onEnded);
      dispatcher.unregister('screen-1', onEnded);

      events.add({
        'onTrackEnded': {'event': 'onTrackEnded', 'trackId': 'screen-1'},
      });
      await Future<void>.delayed(Duration.zero);

      expect(ended, 0);
    });
  });

  test('delivers a stop event received before LiveKit assigns onEnded',
      () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final sinks = <MockStreamHandlerEventSink>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(
      const EventChannel('FlutterWebRTC.Event'),
      MockStreamHandler.inline(
        onListen: (_, events) => sinks.add(events),
      ),
    );

    final track = MediaStreamTrackNative(
      'screen-early',
      'Screen capture',
      'video',
      true,
      'local',
    );
    await Future<void>.delayed(Duration.zero);
    expect(sinks, hasLength(1));

    sinks.single.success({'event': 'onTrackEnded', 'trackId': 'screen-early'});
    await Future<void>.delayed(Duration.zero);

    var ended = 0;
    track.onEnded = () => ended++;
    expect(ended, 1);
  });
}
