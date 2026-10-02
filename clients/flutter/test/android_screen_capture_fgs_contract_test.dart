import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('screen capture waits for a media-projection foreground service', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    final activity = File(
      'android/app/src/main/kotlin/ru/boohtacord/app/MainActivity.kt',
    ).readAsStringSync();
    final backgroundService = File(
      'packages/flutter_background/android/src/main/kotlin/de/julianassmann/flutter_background/IsolateHolderService.kt',
    ).readAsStringSync();
    final readinessStart = activity.indexOf('fun checkForegroundState() {');
    final readinessEnd = activity.indexOf(
      '\n                checkForegroundState()',
      readinessStart,
    );
    expect(readinessStart, isNonNegative);
    expect(readinessEnd, greaterThan(readinessStart));
    final readiness = activity.substring(readinessStart, readinessEnd);

    expect(readiness, contains('serviceSupportsCapture'));
    expect(
      manifest,
      contains('android.permission.FOREGROUND_SERVICE_MEDIA_PROJECTION'),
    );
    expect(
      manifest,
      contains('android:foregroundServiceType="mediaProjection"'),
    );
    expect(activity, contains('screenShareServiceDeclaresMediaProjectionType'));
    expect(activity, contains('serviceInfo.foregroundServiceType and'));
    expect(
      activity,
      contains('ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION'),
    );
    expect(
      backgroundService,
      contains('ServiceInfo.FOREGROUND_SERVICE_TYPE_MANIFEST'),
    );
  });
}
