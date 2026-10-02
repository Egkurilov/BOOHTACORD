import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/services/third_party_audio_licenses.dart';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('RNNoise notice ships in the Flutter asset bundle and license registry', () async {
    final text = await rootBundle.loadString('assets/licenses/rnnoise.txt');
    expect(text, contains('cdf196b1e9de2f8ff1003328ebf9a4316477429d'));
    expect(text, contains('Redistribution and use'));
    registerThirdPartyAudioLicenses();
    final license = await LicenseRegistry.licenses.firstWhere((entry) => entry.packages.contains('RNNoise'));
    expect(license.paragraphs.map((p) => p.text).join('\n'), contains('Redistribution and use'));
  });
}
