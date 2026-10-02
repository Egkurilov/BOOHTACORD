import '../composition/owners.dart';

mixin AppRealtimeAccess on AppOwners {
  bool get realtimeConnected => realtime.connected;

  set realtimeConnected(bool value) => realtime.connected = value;
}
