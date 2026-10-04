import 'package:boohtacord_desktop/src/theme.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Design V2 Inter is bundled as a usable Flutter font asset', () async {
    expect(GcTypography.fontFamily, 'Inter');
    final font = await rootBundle.load('assets/fonts/InterVariable.ttf');
    expect(font.lengthInBytes, greaterThan(100000));
    expect(font.getUint8(0), 0);
    expect(font.getUint8(1), 1);
    expect(font.getUint8(2), 0);
    expect(font.getUint8(3), 0);
  });
}
