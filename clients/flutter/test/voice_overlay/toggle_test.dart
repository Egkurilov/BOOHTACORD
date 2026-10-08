import 'package:boohtacord_desktop/src/features/voice/overlay/toggle.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Windows toggle is accessible and changes visibility', (
    tester,
  ) async {
    try {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      var enabled = false;
      var onlySpeakers = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VoiceOverlayToggle(
              enabled: enabled,
              onlySpeakers: onlySpeakers,
              available: true,
              onChanged: (value) => enabled = value,
              onOnlySpeakersChanged: (value) => onlySpeakers = value,
            ),
          ),
        ),
      );

      expect(find.byTooltip('Показать панель говорящих'), findsOneWidget);
      await tester.tap(find.byTooltip('Показать панель говорящих'));
      expect(enabled, isTrue);
      await tester.tap(find.byTooltip('Настройки панели говорящих'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Показывать только говорящих'));
      expect(onlySpeakers, isTrue);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('toggle is absent outside Windows', (tester) async {
    try {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VoiceOverlayToggle(
              enabled: false,
              onlySpeakers: false,
              available: true,
              onChanged: _ignore,
              onOnlySpeakersChanged: _ignore,
            ),
          ),
        ),
      );

      expect(find.byType(IconButton), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

void _ignore(bool value) {}
