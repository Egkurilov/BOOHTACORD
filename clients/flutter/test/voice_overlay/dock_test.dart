import 'package:boohtacord_desktop/src/features/voice/overlay/dock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.windows);
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  testWidgets('forwards existing dock actions to the voice owner', (
    tester,
  ) async {
    var visibility = false;
    var onlySpeakers = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VoiceOverlayDock(
            binding: VoiceOverlayDockBinding(
              enabled: false,
              onlySpeakers: false,
              available: true,
              onVisibilityChanged: (value) => visibility = value,
              onOnlySpeakersChanged: (value) async {
                onlySpeakers = value;
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Показать панель говорящих'));
    expect(visibility, isTrue);
    await tester.tap(find.byTooltip('Настройки панели говорящих'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CheckedPopupMenuItem<bool>));
    expect(onlySpeakers, isTrue);
  });

  testWidgets('keeps the dock controls disabled when unavailable', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VoiceOverlayDock(
            binding: VoiceOverlayDockBinding(
              enabled: false,
              onlySpeakers: false,
              available: false,
              onVisibilityChanged: _ignore,
              onOnlySpeakersChanged: (_) async {},
            ),
          ),
        ),
      ),
    );

    expect(
      tester.widget<IconButton>(
        find.byTooltip('Показать панель говорящих'),
      ).onPressed,
      isNull,
    );
    expect(
      tester.widget<PopupMenuButton<bool>>(
        find.byTooltip('Настройки панели говорящих'),
      ).enabled,
      isFalse,
    );
  });
}

void _ignore(bool value) {}
