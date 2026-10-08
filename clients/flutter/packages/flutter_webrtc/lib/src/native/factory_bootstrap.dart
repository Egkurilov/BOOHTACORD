import 'factory_bootstrap/readiness.dart';

/// Initializes the native peer-connection factory and audio device module
/// before enumeration. macOS warms a transient local PC and releases it,
/// without Room, signaling, SDP, ICE servers or media capture.
final _factoryReadiness = FactoryReadiness();
Future<void> ensurePeerConnectionFactoryReady() => _factoryReadiness.ensure();
