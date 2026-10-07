import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/features/admin/media_metrics/freshness.dart';
import 'package:flutter_test/flutter_test.dart';

AdminScreenSample _sample(DateTime at) => AdminScreenSample(
  platform: 'android_native',
  direction: 'receiver',
  state: 'playing',
  sampledAtUtc: at,
  decodedFps: 12,
);

void main() {
  final now = DateTime.utc(2026, 10, 7, 12);

  test('uses the 60 second window and five second future tolerance', () {
    final samples = [
      _sample(now.subtract(const Duration(seconds: 60))),
      _sample(now.add(const Duration(seconds: 5))),
      _sample(now.subtract(const Duration(seconds: 61))),
      _sample(now.add(const Duration(seconds: 6))),
    ];
    expect(
      selectAdminMediaFreshness(samples: samples, nowUtc: now).freshSamples,
      samples.take(2),
    );
  });

  test('distinguishes populated, empty, stale and error states', () {
    expect(
      selectAdminMediaFreshness(samples: [_sample(now)], nowUtc: now).state,
      AdminMediaFreshnessState.populated,
    );
    expect(
      selectAdminMediaFreshness(samples: [], nowUtc: now).state,
      AdminMediaFreshnessState.empty,
    );
    expect(
      selectAdminMediaFreshness(
        samples: [_sample(now.subtract(const Duration(minutes: 2)))],
        nowUtc: now,
      ).state,
      AdminMediaFreshnessState.stale,
    );
    final error = selectAdminMediaFreshness(
      samples: [_sample(now)],
      nowUtc: now,
      hasError: true,
    );
    expect(error.state, AdminMediaFreshnessState.error);
    expect(error.freshCount, 0);
  });

  test('keeps last seen timestamp monotonic across snapshots', () {
    final old = now.subtract(const Duration(seconds: 2));
    expect(latestAdminMediaSeenAt(old, [_sample(now)]), now);
    expect(latestAdminMediaSeenAt(now, [_sample(old)]), now);
  });
}
