import 'dart:typed_data';

import 'package:boohtacord_desktop/src/screens/voice_screen_selection_rail.dart';
import 'package:boohtacord_desktop/src/screens/voice_viewer_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

void main() {
  testWidgets('screen selection rail includes local and remote streams', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final thumbnail = Uint8List.fromList(
      image.encodeJpg(image.Image(width: 8, height: 8)),
    );
    String? selectedIdentity = 'peer-1';
    late StateSetter setState;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, update) {
            setState = update;
            return Scaffold(
              body: VoiceScreenSelectionRail(
                choices: [
                  VoiceScreenChoice(
                    identity: null,
                    label: 'Ваш экран',
                    selected: selectedIdentity == null,
                    isLocal: true,
                    avatarIdentity: 'account-1',
                    avatarLabel: 'Евгений',
                  ),
                  VoiceScreenChoice(
                    identity: 'peer-1',
                    label: 'Алиса',
                    selected: selectedIdentity == 'peer-1',
                    accountId: 'account-2',
                    avatarLabel: 'Алиса',
                    hasAudio: true,
                    thumbnail: thumbnail,
                  ),
                ],
                onSelected: (identity) =>
                    setState(() => selectedIdentity = identity),
              ),
            );
          },
        ),
      ),
    );

    expect(find.text('Ваш экран'), findsOneWidget);
    expect(find.text('Экран Алиса'), findsOneWidget);
    expect(find.text('ЭФИР'), findsOneWidget);
    expect(find.text('Е'), findsOneWidget);
    expect(find.byIcon(Icons.volume_up_outlined), findsNothing);
    expect(find.byIcon(Icons.volume_off_outlined), findsNothing);
    final renderedThumbnail = tester.widget<Image>(find.byType(Image));
    expect(renderedThumbnail.fit, BoxFit.cover);
    expect(renderedThumbnail.image, isA<MemoryImage>());
    expect((renderedThumbnail.image as MemoryImage).bytes, same(thumbnail));
    expect(
      tester.getSize(find.byKey(const ValueKey('voice-screen-preview-peer-1'))),
      const Size(142, 60),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('voice-screen-choice-peer-1'))),
      const Size(152, 96),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Алиса')),
      matchesSemantics(
        label: 'Алиса',
        hint: 'Открыть демонстрацию экрана. Звуковая дорожка есть',
        isButton: true,
        isSelected: true,
        hasSelectedState: true,
        hasTapAction: true,
      ),
    );

    await tester.tap(find.text('Ваш экран'));
    await tester.pump();
    expect(selectedIdentity, isNull);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Ваш экран')),
      matchesSemantics(
        label: 'Ваш экран',
        hint:
            'Предпросмотр собственного экрана без звука. Звуковой дорожки нет',
        isButton: true,
        isSelected: true,
        hasSelectedState: true,
        hasTapAction: true,
      ),
    );

    await tester.tap(find.text('Экран Алиса'));
    await tester.pump();
    expect(selectedIdentity, 'peer-1');
    expect(find.text('ЭФИР'), findsOneWidget);

    expect(find.byTooltip('Ваш экран, предпросмотр без звука'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('matches web responsive stream rail and card geometry', (
    tester,
  ) async {
    final thumbnail = Uint8List.fromList(
      image.encodeJpg(image.Image(width: 8, height: 8)),
    );
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 700);
    addTearDown(tester.view.reset);

    Future<void> verifyAtWidth({
      required double width,
      required double railHeight,
      required double cardWidth,
      required double cardHeight,
      required double previewHeight,
    }) async {
      tester.view.physicalSize = Size(width, 700);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VoiceScreenSelectionRail(
              choices: [
                VoiceScreenChoice(
                  identity: 'peer-1',
                  label: 'Алиса',
                  selected: true,
                  thumbnail: thumbnail,
                ),
              ],
              onSelected: (_) {},
            ),
          ),
        ),
      );

      expect(
        tester
            .getSize(find.byKey(const ValueKey('voice-screen-selection-rail')))
            .height,
        railHeight,
      );
      expect(
        tester.getSize(
          find.byKey(const ValueKey('voice-screen-choice-peer-1')),
        ),
        Size(cardWidth, cardHeight),
      );
      expect(
        tester.getSize(
          find.byKey(const ValueKey('voice-screen-preview-peer-1')),
        ),
        Size(cardWidth - 10, previewHeight),
      );
    }

    await verifyAtWidth(
      width: 900,
      railHeight: 100,
      cardWidth: 152,
      cardHeight: 96,
      previewHeight: 60,
    );
    await verifyAtWidth(
      width: 390,
      railHeight: 84,
      cardWidth: 128,
      cardHeight: 80,
      previewHeight: 48,
    );
  });

  testWidgets('places the selectable stream rail below the video stage', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 700);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: VoiceViewerLayout(
            stage: ColoredBox(
              key: ValueKey('video-stage'),
              color: Colors.black,
            ),
            diagnostics: SizedBox(
              key: ValueKey('viewer-diagnostics'),
              height: 40,
            ),
            streamRail: SizedBox(key: ValueKey('stream-rail'), height: 76),
            participants: SizedBox(
              key: ValueKey('participant-strip'),
              height: 92,
            ),
          ),
        ),
      ),
    );

    final stage = tester.getRect(find.byKey(const ValueKey('video-stage')));
    final diagnostics = tester.getRect(
      find.byKey(const ValueKey('viewer-diagnostics')),
    );
    final rail = tester.getRect(find.byKey(const ValueKey('stream-rail')));
    final participants = tester.getRect(
      find.byKey(const ValueKey('participant-strip')),
    );
    expect(stage.bottom, lessThanOrEqualTo(diagnostics.top));
    expect(diagnostics.bottom, lessThanOrEqualTo(rail.top));
    expect(rail.bottom, lessThanOrEqualTo(participants.top));
    expect(tester.takeException(), isNull);
  });
}
