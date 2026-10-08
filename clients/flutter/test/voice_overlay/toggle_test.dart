import 'package:boohtacord_desktop/src/features/voice/overlay/toggle.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Windows toggle is accessible and changes visibility', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    var enabled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VoiceOverlayToggle(
            enabled: enabled,
            available: true,
            onChanged: (value) => enabled = value,
          ),
        ),
      ),
    );

    expect(find.byTooltip('Показать панель говорящих'), findsOneWidget);
    await tester.tap(find.byTooltip('Показать панель говорящих'));
    expect(enabled, isTrue);
  });

  testWidgets('toggle is absent outside Windows', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: VoiceOverlayToggle(
            enabled: false,
            available: true,
            onChanged: _ignore,
          ),
        ),
      ),
    );

    expect(find.byType(IconButton), findsNothing);
  });
}

void _ignore(bool value) {}
