import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/features/screen/capture/update_notice.dart';

void main() {
  test('Windows explains that a changed FPS needs a capture restart', () {
    final notice = screenShareUpdateNotice(TargetPlatform.windows);

    expect(notice, contains('FPS'));
    expect(notice, contains('остановить'));
    expect(notice, contains('кодирования'));
  });

  test('macOS and Android explain capture restart and platform consent', () {
    final macOS = screenShareUpdateNotice(TargetPlatform.macOS);
    final android = screenShareUpdateNotice(TargetPlatform.android);

    expect(macOS, contains('захвата'));
    expect(macOS, contains('остановить'));
    expect(android, contains('захвата'));
    expect(android, contains('разрешение'));
  });

  test('iOS does not claim that an encoder update restarts capture', () {
    final notice = screenShareUpdateNotice(TargetPlatform.iOS);

    expect(notice, contains('кодирования'));
    expect(notice, isNot(contains('остановить')));
  });
}
