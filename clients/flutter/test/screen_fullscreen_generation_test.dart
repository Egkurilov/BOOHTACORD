import 'package:boohtacord_desktop/src/features/voice/screen_viewer/publication_generation.dart';
import 'package:boohtacord_desktop/src/widgets/screen_video_renderer_slot.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('same participant republish expires the old fullscreen route', () {
    const oldGeneration = ScreenViewerPublicationGeneration(
      participantIdentity: 'participant-1',
      publicationSid: 'publication-old',
    );
    const newGeneration = ScreenViewerPublicationGeneration(
      participantIdentity: 'participant-1',
      publicationSid: 'publication-new',
    );

    expect(
      screenFullscreenGenerationIsCurrent(
        selection: const ScreenFullscreenSelection(
          identity: 'participant-1',
          generation: oldGeneration,
        ),
        currentIdentity: 'participant-1',
        currentGeneration: newGeneration,
      ),
      isFalse,
    );
  });

  test('fullscreen route remains current for its exact publication', () {
    const generation = ScreenViewerPublicationGeneration(
      participantIdentity: 'participant-1',
      publicationSid: 'publication-1',
    );

    expect(
      screenFullscreenGenerationIsCurrent(
        selection: const ScreenFullscreenSelection(
          identity: 'participant-1',
          generation: generation,
        ),
        currentIdentity: 'participant-1',
        currentGeneration: generation,
      ),
      isTrue,
    );
  });

  test('replaced local capture expires its fullscreen route', () {
    const selection = ScreenFullscreenSelection(
      identity: null,
      generation: 'local-capture-old',
    );

    expect(
      screenFullscreenGenerationIsCurrent(
        selection: selection,
        currentIdentity: null,
        currentGeneration: 'local-capture-new',
      ),
      isFalse,
    );
  });
}
