import 'dart:io';
import '../factory_impl.dart';
import '../utils.dart';

/// Process readiness is accepted only after the empty local PC is released.
/// No SDP, signaling, media or ICE servers are created by this bootstrap.
class FactoryReadiness {
  FactoryReadiness({bool Function()? isMacOS}) : _isMacOS = isMacOS ?? (() => Platform.isMacOS);
  final bool Function() _isMacOS;
  Future<void>? _pending;
  bool _ready = false;

  Future<void> ensure() {
    if (_ready) return Future.value();
    if (!_isMacOS()) return WebRTC.initialize();
    if (_pending != null) return _pending!;
    late final Future<void> operation;
    operation = _warm().whenComplete(() {
      if (identical(_pending, operation)) _pending = null;
    });
    _pending = operation;
    return operation;
  }

  Future<void> _warm() async {
    await WebRTC.initialize();
    final peer = await RTCFactoryNative.instance.createPeerConnection({
      'iceServers': <Map<String, dynamic>>[], 'iceTransportPolicy': 'relay',
    });
    try { await peer.close(); }
    finally { await peer.dispose(); }
    _ready = true;
  }
}
