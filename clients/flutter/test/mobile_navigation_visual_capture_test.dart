import 'dart:io';
import 'dart:ui' as ui;

import 'package:boohtacord_desktop/src/features/workspace/mobile_navigation/guild_mark.dart';
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
    final directory = Platform.environment['BOOHTACORD_VISUAL_CAPTURE_DIR'];
    if (directory != null && directory.isNotEmpty) {
      final flutterRoot = Platform.environment['FLUTTER_ROOT'];
      expect(
        flutterRoot,
        isNotNull,
        reason: 'Flutter SDK is required for icon capture',
      );
      final iconFont = File(
        '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      );
      expect(iconFont.existsSync(), isTrue);
      final iconBytes = iconFont.readAsBytesSync();
      await (FontLoader('MaterialIcons')
            ..addFont(Future.value(ByteData.sublistView(iconBytes))))
          .load();
    }
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
    final mark = find.byType(WorkspaceGuildMark);
    final badge = tester.widget<Container>(find.descendant(
      of: mark,
      matching: find.byType(Container),
    ));
    expect((badge.decoration! as BoxDecoration).color, const Color(0xFF1A193E));
    final gamepad = tester.widget<Icon>(find.descendant(
      of: mark,
      matching: find.byType(Icon),
    ));
    expect(gamepad.color, const Color(0xFFA391F9));

    if (directory == null || directory.isEmpty) return;
    final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(captureKey));
    final bytes = await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
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
    File('$directory/R14-navigation-top.png').writeAsBytesSync(bytes!);
  });
}
