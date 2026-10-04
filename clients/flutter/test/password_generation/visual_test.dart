import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    if (Platform.environment['PASSWORD_GENERATION_SCREENSHOTS'] != '1') return;
    await (FontLoader('Inter')..addFont(rootBundle.load('assets/fonts/InterVariable.ttf'))).load();
    final sdk = Platform.environment['FLUTTER_ROOT']!;
    final icons = File('$sdk/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf').readAsBytesSync();
    await (FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(icons)))).load();
  });
  for (final entry in {
    'mobile': const Size(390, 844),
    'desktop': const Size(1440, 900),
  }.entries) {
    testWidgets('registration layout and neutral live status at ${entry.key}', (
      tester,
    ) async {
      final key = GlobalKey();
      await mountRegistration(tester, entry.value, captureKey: key);
      await press(tester, generateButton);
      await press(tester, find.byTooltip('Скрыть пароль'));
      expect(passwordInput(tester).obscureText, isTrue);
      expect(find.text('Надёжный пароль сгенерирован'), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (Platform.environment['PASSWORD_GENERATION_SCREENSHOTS'] == '1') {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final output = File(
          '../../evidence/qa/issue-104-password-generation/flutter-${entry.key}.png',
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1);
          final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
          await output.parent.create(recursive: true);
          await output.writeAsBytes(data.buffer.asUint8List());
          image.dispose();
        });
      }
    });
  }
}
