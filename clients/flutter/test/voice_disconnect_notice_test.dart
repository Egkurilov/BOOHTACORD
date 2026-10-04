import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/features/voice/disconnect_notice/state.dart';
void main() {
  for (final serverFirst in [true, false]) {
    test('server reason wins with serverFirst=$serverFirst and emits once', () {
      final outcomes = <VoiceDisconnectNotice>[];
      final state = VoiceDisconnectState(report: outcomes.add)..bind('lease', 'channel');
      if (serverFirst) { state.server('lease', 'KICK'); state.transport(); }
      else { state.transport(); state.server('lease', 'KICK'); }
      state.local(); state.server('lease', 'KICK'); state.transport();
      expect(state.notice?.reason, 'KICK'); expect(state.notice?.reconnectAllowed, isTrue);
      expect(state.notice?.message, 'Администратор отключил вас от голосового канала.');
      expect(outcomes.length, 1); expect(outcomes.single.source, 'server');
    });
  }
  test('stale lease after reset is ignored and closed/session access blocks join', () {
    final state = VoiceDisconnectState()..bind('lease', 'channel');
    state.local(); state.server('lease', 'KICK');
    state.reset(); state.bind('new', 'channel');
    expect(state.server('lease', 'KICK'), isFalse);
    expect(state.notice, isNull);
    for (final reason in ['CHANNEL_CLOSED', 'BANNED', 'SESSION_REVOKED', 'LOGOUT']) {
      state.reset(); state.bind('new', 'channel'); state.server('new', reason);
      expect(state.notice?.reconnectAllowed, isFalse);
    }
    state.selectChannel('other'); expect(state.notice, isNull);
    state.bind('other', 'other'); state.transport(); expect(state.notice?.source, 'transport');
  });
}
