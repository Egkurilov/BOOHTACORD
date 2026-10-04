import 'dart:io';
import 'dart:ui' as ui;

import 'package:boohtacord_desktop/src/features/workspace/mobile_navigation/top.dart';
import 'package:boohtacord_desktop/src/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('R14 captures the real Flutter navigation top at 390 dp', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    await (FontLoader('Inter')
          ..addFont(rootBundle.load('assets/fonts/InterVariable.ttf')))
        .load();
    const captureKey = ValueKey('navigation-visual-capture');
    await tester.pumpWidget(MaterialApp(
      theme: guildTheme(),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 320,
            height: 172,
            child: RepaintBoundary(
              key: captureKey,
              child: ColoredBox(
                color: GcColors.sidebar,
                child: WorkspaceNavigationTop(
                  memberCount: 6,
                  channelsSelected: true,
                  onSearch: () {},
                  onChannels: () {},
                  onDirectMessages: () {},
                  onClose: () {},
                ),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byKey(captureKey)), const Rect.fromLTWH(0, 0, 320, 172));
    expect(tester.getRect(find.byKey(const ValueKey('navigation-search'))), const Rect.fromLTWH(12, 76, 296, 36));

    final directory = Platform.environment['BOOHTACORD_VISUAL_CAPTURE_DIR'];
    if (directory == null || directory.isEmpty) return;
    final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(captureKey));
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      expect(data, isNotNull);
      Directory(directory).createSync(recursive: true);
      File('$directory/R14-navigation-top.png').writeAsBytesSync(data!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}
