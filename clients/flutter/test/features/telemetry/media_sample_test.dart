import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/features/telemetry/media_sample/record.dart';

void main() {
  test('unknown and stale stats never become fresh zero measurements', () {
    expect(
      mediaSampleFields({'sample_age_ms': double.nan, 'decoded_fps': 20})
          .containsKey('app.media.decoded_fps'),
      isFalse,
    );
    expect(
      mediaSampleFields({'sample_age_ms': 0, 'capture_fps': 30})
          .containsKey('app.media.capture_fps'),
      isFalse,
    );
    expect(
      mediaSampleFields({'decoded_fps': 20})['app.media.sample_state'],
      'unknown',
    );
    expect(
      mediaSampleFields({'sample_age_ms': 16000, 'decoded_fps': 20})
          .containsKey('app.media.decoded_fps'),
      isFalse,
    );
    final fields = mediaSampleFields({
      'sample_age_ms': 0,
      'decoded_fps': 0,
      'rtt_ms': double.infinity,
      'body': 'private',
    });
    expect(fields['app.media.decoded_fps'], 0);
    expect(fields.containsKey('app.media.rtt_ms'), isFalse);
    expect(fields.values, isNot(contains('private')));
  });
}
