import 'dart:convert';

import 'package:boohtacord_desktop/src/features/screen/sender_metadata/descriptor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'fixtures.dart';

void main() {
  test('parses a scoped v1 sender profile without treating it as actual quality', () {
    final parsed = parseScreenShareDescriptor(
      jsonEncode(descriptor()),
      expectedAccountId: 'account-a',
      expectedRoomId: 'room-a',
    );

    expect(parsed?.mode, 'motion');
    expect(parsed?.requestedProfileId, 'P1080_60');
    expect(parsed?.publicationGeneration, 4);
    expect(parsed?.operationRevision, 12);
  });

  test('only accepts newer revisions and publication generations', () {
    final current = parse(descriptor())!;
    final staleRevision = parse(descriptor(revision: 11))!;
    final newerRevision = parse(descriptor(revision: 13))!;
    final newerGeneration = parse(
      descriptor(generation: 5, revision: 1),
    )!;

    expect(isNewerScreenShareDescriptor(staleRevision, current), isFalse);
    expect(isNewerScreenShareDescriptor(current, current), isFalse);
    expect(isNewerScreenShareDescriptor(newerRevision, current), isTrue);
    expect(isNewerScreenShareDescriptor(newerGeneration, current), isTrue);
    final replacedSession = parse(descriptor(generation: 4, revision: 13)
      ..['scope'] = {
        ...(descriptor()['scope'] as Map<String, Object?>),
        'media_session_id': 'session-b',
      })!;
    expect(isNewerScreenShareDescriptor(replacedSession, current), isFalse);
  });

}
