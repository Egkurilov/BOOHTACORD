import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('adaptive launcher icon provides a monochrome brand mark', () {
    const adaptiveIconPath =
        'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml';
    const monochromeIconPath =
        'android/app/src/main/res/drawable/ic_launcher_monochrome.xml';

    final adaptiveIcon = File(adaptiveIconPath).readAsStringSync();
    final monochromeIcon = File(monochromeIconPath).readAsStringSync();

    expect(
      adaptiveIcon,
      contains(
        '<monochrome android:drawable="@drawable/ic_launcher_monochrome"',
      ),
    );
    expect(monochromeIcon, contains('android:viewportWidth="24"'));
    expect(monochromeIcon, contains('android:viewportHeight="24"'));
    expect(monochromeIcon, contains('android:fillColor="#FFFFFFFF"'));
    expect(monochromeIcon, contains('android:fillType="evenOdd"'));
  });
}
