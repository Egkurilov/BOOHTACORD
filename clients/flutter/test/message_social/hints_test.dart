import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/core/http/transport.dart';
import 'package:boohtacord_desktop/src/features/realtime/social_hints/hints.dart';
import 'package:boohtacord_desktop/src/features/realtime/lifecycle/event.dart';

const channel = '11111111-1111-4111-8111-111111111111',
    message = '22222222-2222-4222-8222-222222222222';
void main() {
  test(
    'hints require exactly scoped IDs and unsubscribe on account boundary',
    () {
      final transport = ApiTransport(),
          bus = SocialHints.forTransport(transport),
          hints = <SocialHint?>[];
      final stop = bus.subscribe(hints.add);
      expect(
        bus.receive(
          const RealtimeEvent('one', 'direct_message.reactions_updated', {
            'direct_message_id': channel,
            'message_id': message,
          }),
        ),
        isTrue,
      );
      expect(hints.single!.direct, isTrue);
      expect(hints.single!.conversation, channel);
      bus.receive(
        const RealtimeEvent('two', 'direct_message.reactions_updated', {
          'direct_message_id': channel,
          'message_id': message,
          'count': 1,
        }),
      );
      expect(hints.length, 1);
      bus.receive(const RealtimeEvent('three', 'connection.ready', {}));
      expect(hints.last, isNull);
      transport.session.scope.close();
      bus.emit(null);
      expect(hints.length, 2);
      expect(bus.observerCount, 0);
      stop();
    },
  );
  test(
    'transport isolation and explicit disposal prevent unrelated callbacks',
    () {
      final first = SocialHints.forTransport(ApiTransport()),
          second = SocialHints.forTransport(ApiTransport());
      var calls = 0;
      final stop = first.subscribe((_) {
        calls++;
      });
      second.emit(null);
      expect(calls, 0);
      stop();
      first.emit(null);
      expect(calls, 0);
    },
  );
}
