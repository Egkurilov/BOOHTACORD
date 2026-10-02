import 'dart:typed_data';

import 'package:boohtacord_desktop/src/widgets/voice_participant_thumbnail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

void main() {
  testWidgets('shows the participant fallback before a thumbnail arrives', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: VoiceParticipantThumbnail(
          fallback: Text('avatar'),
          thumbnail: null,
          width: 44,
          height: 32,
        ),
      ),
    );

    expect(find.text('avatar'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('renders a supplied screen thumbnail in the compact size', (
    tester,
  ) async {
    final thumbnail = Uint8List.fromList(
      image.encodeJpg(image.Image(width: 8, height: 8)),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: VoiceParticipantThumbnail(
            fallback: const Text('avatar'),
            thumbnail: thumbnail,
            width: 44,
            height: 32,
          ),
        ),
      ),
    );

    final renderedImage = tester.widget<Image>(find.byType(Image));
    expect(renderedImage.image, isA<MemoryImage>());
    expect((renderedImage.image as MemoryImage).bytes, same(thumbnail));
    expect(tester.getSize(find.byType(ClipRRect)), const Size(44, 32));
    expect(find.text('avatar'), findsNothing);
  });

  testWidgets('participant-card thumbnail matches the web 64px cover tile', (
    tester,
  ) async {
    final thumbnail = Uint8List.fromList(
      image.encodeJpg(image.Image(width: 8, height: 16)),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: VoiceParticipantThumbnail.participantCard(
            fallback: const Text('avatar'),
            thumbnail: thumbnail,
          ),
        ),
      ),
    );

    final renderedImage = tester.widget<Image>(find.byType(Image));
    expect(renderedImage.fit, BoxFit.cover);
    expect(tester.getSize(find.byType(ClipRRect)), const Size(64, 64));
  });
}
