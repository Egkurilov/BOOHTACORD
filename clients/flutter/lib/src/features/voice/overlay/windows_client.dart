import 'dart:async';

import 'package:flutter/services.dart';

import 'feed.dart';

class WindowsVoiceOverlayClient {
  WindowsVoiceOverlayClient({
    required VoiceOverlayFeed feed,
    MethodChannel? channel,
  }) : _feed = feed,
       _channel = channel ?? const MethodChannel('boohtacord/voice_overlay') {
    _feed.addListener(_publish);
    unawaited(_publish());
  }

  final VoiceOverlayFeed _feed;
  final MethodChannel _channel;
  Future<void> _tail = Future<void>.value();

  Future<void> _publish() {
    final snapshot = _feed.snapshot;
    final arguments = <String, Object>{
      'visible': snapshot.visible,
      'members': snapshot.members
          .map(
            (member) => <String, Object>{
              'displayName': member.displayName,
              'speaking': member.speaking,
              'microphoneMuted': member.microphoneMuted,
            },
          )
          .toList(growable: false),
    };
    return _enqueue(arguments);
  }

  Future<void> dispose() {
    _feed.removeListener(_publish);
    return _enqueue(const {'visible': false, 'members': <Object>[]});
  }

  Future<void> _enqueue(Map<String, Object> arguments) {
    _tail = _tail.then((_) async {
      try {
        await _channel.invokeMethod<void>('setSnapshot', arguments);
      } on MissingPluginException {
        // The Windows runner owns this channel; keep the client UI independent.
      } on PlatformException {
        // A native overlay failure must not interrupt the voice session.
      }
    });
    return _tail;
  }
}
