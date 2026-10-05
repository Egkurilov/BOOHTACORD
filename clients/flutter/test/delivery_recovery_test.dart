import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/features/conversation/delivery/recovery.dart';
import 'package:boohtacord_desktop/src/core/http/api_failure.dart';

void main() {
  test('lost response reconciles without a second POST', () async {
    final statuses = <String>[];
    var posts = 0;
    final result = await recoverDelivery<String>(
      post: () async {
        posts++;
        throw Exception('network');
      },
      lookup: () async => 'committed',
      status: statuses.add,
      active: () => true,
      retry: false,
    );
    expect(result, 'committed');
    expect(posts, 1);
    expect(statuses, ['sending', 'checking']);
  });
  test('manual retry first checks absence and preserves request', () async {
    final calls = <String>[];
    await recoverDelivery<String>(
      post: () async {
        calls.add('POST');
        return 'message';
      },
      lookup: () async {
        calls.add('LOOKUP');
        return null;
      },
      status: (_) {},
      active: () => true,
      retry: true,
    );
    expect(calls, ['LOOKUP', 'POST']);
  });
  test('explicit 403 and failed lookup do not cause another POST', () async {
    var checks = 0, posts = 0;
    await expectLater(
      recoverDelivery<String>(
        post: () async {
          posts++;
          throw const ApiFailure('denied', status: 403);
        },
        lookup: () async {
          checks++;
          return null;
        },
        status: (_) {},
        active: () => true,
        retry: false,
      ),
      throwsA(isA<ApiFailure>()),
    );
    expect(checks, 0);
    await expectLater(
      recoverDelivery<String>(
        post: () async {
          posts++;
          return 'message';
        },
        lookup: () async {
          throw Exception('offline');
        },
        status: (_) {},
        active: () => true,
        retry: true,
      ),
      throwsException,
    );
    expect(posts, 1);
  });
  test('closed scope stops retry after pending lookup', () async {
    var active = true, posts = 0;
    await expectLater(
      recoverDelivery<String>(
        post: () async {
          posts++;
          return 'message';
        },
        lookup: () async {
          active = false;
          return null;
        },
        status: (_) {},
        active: () => active,
        retry: true,
      ),
      throwsStateError,
    );
    expect(posts, 0);
  });
}
