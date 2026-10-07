import 'package:boohtacord_desktop/src/features/voice/screen_viewer/recovery_deadline.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('foreground deadline preserves its remaining time across pauses', () {
    var now = Duration.zero;
    final deadline = ScreenViewerRecoveryDeadline(
      monotonicNow: () => now,
    );

    deadline.reset();
    deadline.start();
    now += const Duration(seconds: 4);
    deadline.pause();
    expect(deadline.remaining, const Duration(seconds: 1));

    now += const Duration(minutes: 2);
    deadline.start();
    now += const Duration(milliseconds: 999);
    expect(deadline.remaining, const Duration(milliseconds: 1));
    now += const Duration(milliseconds: 1);
    expect(deadline.remaining, Duration.zero);
  });

  test('deadline reset gives a fresh budget only to a new generation', () {
    var now = Duration.zero;
    final deadline = ScreenViewerRecoveryDeadline(
      monotonicNow: () => now,
    );
    deadline.reset();
    deadline.start();
    now += const Duration(seconds: 5);
    expect(deadline.remaining, Duration.zero);

    deadline.expire();
    expect(deadline.remaining, Duration.zero);
    deadline.reset();
    expect(deadline.remaining, const Duration(seconds: 5));
  });
}
