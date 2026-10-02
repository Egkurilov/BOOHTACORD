import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

void registerThirdPartyAudioLicenses() {
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'RNNoise',
    ], await rootBundle.loadString('assets/licenses/rnnoise.txt'));
  });
}
