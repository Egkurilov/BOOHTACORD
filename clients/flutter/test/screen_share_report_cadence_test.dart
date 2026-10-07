import 'package:boohtacord_desktop/src/features/screen/metrics/report_cadence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('samples may run each second while reports stay on bounded five-second windows', () {
    final cadence = ScreenShareReportCadence();
    expect(cadence.isDue(0), isTrue);
    expect(cadence.isDue(1000), isFalse);
    expect(cadence.isDue(4999), isFalse);
    expect(cadence.isDue(5000), isTrue);
    expect(cadence.isDue(10000), isTrue);
  });

  test('clears report cadence between sharing generations', () {
    final cadence = ScreenShareReportCadence();
    expect(cadence.isDue(5000), isTrue);
    cadence.clear();
    expect(cadence.isDue(0), isTrue);
  });
}
