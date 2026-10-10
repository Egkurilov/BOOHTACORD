import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

bool get uiuxVisualCaptureEnabled =>
    (Platform.environment['BOOHTACORD_VISUAL_CAPTURE_DIR'] ?? '').isNotEmpty;

Future<void> loadUiuxVisualCaptureFonts() async {
  if (!uiuxVisualCaptureEnabled) return;
  await (FontLoader(
    'Inter',
  )..addFont(rootBundle.load('assets/fonts/InterVariable.ttf'))).load();
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  expect(flutterRoot, isNotNull);
  final icons = File(
    '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  expect(icons.existsSync(), isTrue);
  await (FontLoader('MaterialIcons')
        ..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync()))))
      .load();
}

Future<void> captureUiuxBoundary(
  WidgetTester tester,
  Finder boundaryFinder, {
  required String fileName,
  required double pixelRatio,
}) async {
  if (!uiuxVisualCaptureEnabled) return;
  final directory = Platform.environment['BOOHTACORD_VISUAL_CAPTURE_DIR']!;
  final boundary = tester.renderObject<RenderRepaintBoundary>(boundaryFinder);
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('Flutter returned no PNG bytes');
      return data.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  });
  expect(bytes, isNotNull);
  Directory(directory).createSync(recursive: true);
  File('$directory/$fileName').writeAsBytesSync(bytes!);
}
