import 'utils.dart';

/// Initializes the native peer-connection factory and audio device module
/// before device enumeration, without creating a peer connection or media.
Future<void> ensurePeerConnectionFactoryReady() => WebRTC.initialize();
