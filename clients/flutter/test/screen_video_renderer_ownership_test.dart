import 'package:boohtacord_desktop/src/features/voice/screen_viewer/publication_generation.dart';
import 'package:boohtacord_desktop/src/widgets/screen_video_renderer_slot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const generation1 = ScreenViewerPublicationGeneration(
    participantIdentity: 'participant-1',
    publicationSid: 'publication-1',
  );
  const generation2 = ScreenViewerPublicationGeneration(
    participantIdentity: 'participant-1',
    publicationSid: 'publication-2',
  );

  testWidgets('search mini owns the selected publication renderer', (
    tester,
  ) async {
    final owner = screenVideoRendererOwner(
      selectedIdentity: 'participant-1',
      selectedGeneration: generation1,
      pinnedIdentity: 'participant-1',
      pinnedMiniVisible: true,
      fullscreenSelection: null,
    );

    await _expectOneRenderer(tester, owner, 'pinned-mini');
  });

  testWidgets('fullscreen owns the selected publication renderer', (
    tester,
  ) async {
    final owner = screenVideoRendererOwner(
      selectedIdentity: 'participant-1',
      selectedGeneration: generation1,
      pinnedIdentity: 'participant-1',
      pinnedMiniVisible: true,
      fullscreenSelection: const ScreenFullscreenSelection(
        identity: 'participant-1',
        generation: generation1,
      ),
    );

    await _expectOneRenderer(tester, owner, 'fullscreen');
  });

  testWidgets('new generation is not suppressed by stale fullscreen owner', (
    tester,
  ) async {
    final owner = screenVideoRendererOwner(
      selectedIdentity: 'participant-1',
      selectedGeneration: generation2,
      pinnedIdentity: 'participant-1',
      pinnedMiniVisible: true,
      fullscreenSelection: const ScreenFullscreenSelection(
        identity: 'participant-1',
        generation: generation1,
      ),
    );

    expect(owner, ScreenVideoRendererOwner.pinnedMini);
    await _expectOneRenderer(tester, owner, 'pinned-mini');
  });

  testWidgets('local fullscreen ownership matches stable capture generation', (
    tester,
  ) async {
    final owner = screenVideoRendererOwner(
      selectedIdentity: null,
      selectedGeneration: 'local-publication-1',
      pinnedIdentity: null,
      pinnedMiniVisible: false,
      fullscreenSelection: const ScreenFullscreenSelection(
        identity: null,
        generation: 'local-publication-1',
      ),
    );

    await _expectOneRenderer(tester, owner, 'fullscreen');
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
