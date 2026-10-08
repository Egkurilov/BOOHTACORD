import '../../../native_bindings.dart';
import '../../lifecycle/context.dart';

extension PinnedScreenMiniPlayerVideoPreviewRenderer
    on WorkspacePinnedScreenMiniPlayerContext {
  AspectRatio renderPinnedScreenMiniPlayerVideoPreview(
    VideoTrack? track,
    String? publicationSid,
    RemoteParticipant? participant,
    RemoteTrackPublication<RemoteTrack>? publication,
    ScreenVideoRendererOwner rendererOwner,
    ScreenViewerPublicationGeneration? miniGeneration,
    ScreenViewerPublicationGeneration? selectedGeneration,
    ScreenFullscreenSelection? selectedFullscreen,
  ) => AspectRatio(
    aspectRatio: 16 / 9,
    child: ColoredBox(
      color: Colors.black,
      child: track == null
          ? ScreenFrameGate(
              generation: '$identity:${publicationSid ?? 'unknown'}',
              waitingMessage: participant == null || publication == null
                  ? 'Демонстрация завершена'
                  : 'Ожидаем кадр демонстрации…',
              recoveryExhausted:
                  state.voice.remoteScreenViewerRecoveryExhausted,
              onRecoveryRetry: state.voice.retryRemoteScreenViewerRecovery,
              builder: (context, onFirstFrameRendered) =>
                  const SizedBox.expand(),
            )
          : ScreenVideoRendererSlot(
              surface: ScreenVideoRendererSurface.pinnedMini,
              owner: rendererOwner,
              isSelectedPublication:
                  miniGeneration != null &&
                  miniGeneration == selectedGeneration,
              isFullscreenPublication:
                  miniGeneration != null &&
                  selectedFullscreen != null &&
                  selectedFullscreen.identity == identity &&
                  selectedFullscreen.generation == miniGeneration,
              child: ScreenFrameGate(
                generation: '$identity:${publicationSid ?? 'unknown'}',
                recoveryExhausted:
                    state.voice.remoteScreenViewerRecoveryExhausted,
                onRecoveryRetry: state.voice.retryRemoteScreenViewerRecovery,
                onFirstFrame: publicationSid == null
                    ? null
                    : () => state.voice.markRemoteScreenFirstFrameRendered(
                        identity,
                        publicationSid,
                      ),
                builder: (context, onFirstFrameRendered) => VideoTrackRenderer(
                  track,
                  key: ValueKey('$identity:${publicationSid ?? 'unknown'}'),
                  fit: VideoViewFit.contain,
                  renderMode: VideoRenderMode.auto,
                  onFirstFrameRendered: onFirstFrameRendered,
                ),
              ),
            ),
    ),
  );
}
