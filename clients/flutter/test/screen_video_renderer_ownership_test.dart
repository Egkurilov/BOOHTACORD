import 'package:boohtacord_desktop/src/widgets/screen_video_renderer_slot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('search mini owns the selected publication renderer', (
    tester,
  ) async {
    final owner = screenVideoRendererOwner(
      selectedIdentity: 'publication-1',
      selectedGeneration: 'generation-1',
      pinnedIdentity: 'publication-1',
      pinnedMiniVisible: true,
      fullscreenSelection: null,
    );

    await _expectOneRenderer(tester, owner, 'pinned-mini');
  });

  testWidgets('fullscreen owns the selected publication renderer', (
    tester,
  ) async {
    final owner = screenVideoRendererOwner(
      selectedIdentity: 'publication-1',
      selectedGeneration: 'generation-1',
      pinnedIdentity: 'publication-1',
      pinnedMiniVisible: true,
      fullscreenSelection: const ScreenFullscreenSelection(
        identity: 'publication-1',
        generation: 'generation-1',
      ),
    );

    await _expectOneRenderer(tester, owner, 'fullscreen');
  });

  testWidgets('new generation is not suppressed by stale fullscreen owner', (
    tester,
  ) async {
    final owner = screenVideoRendererOwner(
      selectedIdentity: 'publication-1',
      selectedGeneration: 'generation-2',
      pinnedIdentity: 'publication-1',
      pinnedMiniVisible: true,
      fullscreenSelection: const ScreenFullscreenSelection(
        identity: 'publication-1',
        generation: 'generation-1',
      ),
    );

    expect(owner, ScreenVideoRendererOwner.pinnedMini);
    await _expectOneRenderer(tester, owner, 'pinned-mini');
  });
}

Future<void> _expectOneRenderer(
  WidgetTester tester,
  ScreenVideoRendererOwner owner,
  String expectedSurface,
) async {
  Widget slot(ScreenVideoRendererSurface surface, String name) =>
      ScreenVideoRendererSlot(
        surface: surface,
        owner: owner,
        isSelectedPublication: true,
        isFullscreenPublication: surface ==
            ScreenVideoRendererSurface.pinnedMini &&
            owner == ScreenVideoRendererOwner.fullscreen,
        child: ColoredBox(key: ValueKey(name), color: Colors.black),
      );

  await tester.pumpWidget(
    MaterialApp(
      home: Stack(
        children: [
          slot(ScreenVideoRendererSurface.stage, 'stage'),
          slot(ScreenVideoRendererSurface.pinnedMini, 'pinned-mini'),
          slot(ScreenVideoRendererSurface.fullscreen, 'fullscreen'),
        ],
      ),
    ),
  );

  for (final surface in ['stage', 'pinned-mini', 'fullscreen']) {
    expect(
      find.byKey(ValueKey(surface)),
      surface == expectedSurface ? findsOneWidget : findsNothing,
    );
  }
}
