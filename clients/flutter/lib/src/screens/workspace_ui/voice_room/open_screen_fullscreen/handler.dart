import 'fullscreen_content/handler.dart';
import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceVoiceRoomStateWorkspaceOpenScreenFullscreenBinding
    on WorkspaceVoiceRoomStateContext {
  @override
  Future<void> workspaceOpenScreenFullscreen({
    required VideoTrack track,
    required String publisherName,
    required String? publisherIdentity,
    required Object viewerGeneration,
    required VoidCallback? onFirstFrameRendered,
    required bool showingLocalScreen,
  }) {
    return executeWorkspaceVoiceRoomStateWorkspaceOpenScreenFullscreen(
      track: track,
      publisherName: publisherName,
      publisherIdentity: publisherIdentity,
      viewerGeneration: viewerGeneration,
      onFirstFrameRendered: onFirstFrameRendered,
      showingLocalScreen: showingLocalScreen,
    );
  }
}

extension WorkspaceVoiceRoomStateWorkspaceOpenScreenFullscreenAction
    on WorkspaceVoiceRoomStateContext {
  Future<void> executeWorkspaceVoiceRoomStateWorkspaceOpenScreenFullscreen({
    required VideoTrack track,
    required String publisherName,
    required String? publisherIdentity,
    required Object viewerGeneration,
    required VoidCallback? onFirstFrameRendered,
    required bool showingLocalScreen,
  }) async {
    ScreenFullscreenPresentation? presentation;
    final rendererLease = ScreenFullscreenRendererLease();
    BuildContext? overlayContext;
    var closing = false;
    final capturedRoom = widget.state.room;
    bool stillPublished() => screenFullscreenGenerationIsPublished(
      room: widget.state.room,
      capturedRoom: capturedRoom,
      publisherIdentity: publisherIdentity,
      viewerGeneration: viewerGeneration,
      localCaptureActive:
          widget.state.screenSharePhase == ScreenSharePhase.sharing,
    );

    void closeWhenEnded() {
      final target = overlayContext;
      if (closing || target == null || !target.mounted || stillPublished()) {
        return;
      }
      closing = true;
      rendererLease.expire(() => Navigator.of(target).pop());
    }

    widget.onFullscreenSelectionChanged(
      ScreenFullscreenSelection(
        identity: publisherIdentity,
        generation: viewerGeneration,
      ),
    );
    try {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      presentation = await ScreenFullscreenPresentation.enter();
      if (!mounted) return;
      widget.state.addListener(closeWhenEnded);
      capturedRoom?.addListener(closeWhenEnded);
      await showGeneralDialog<void>(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Закрыть полноэкранный режим',
        barrierColor: Colors.black,
        transitionDuration: const Duration(milliseconds: 160),
        pageBuilder: (dialogContext, _, _) {
          overlayContext = dialogContext;
          WidgetsBinding.instance.addPostFrameCallback((_) => closeWhenEnded());
          return renderVoiceRoomFullscreenContent(
            publisherName,
            viewerGeneration,
            onFirstFrameRendered,
            showingLocalScreen,
            rendererLease,
            track,
            dialogContext,
          );
        },
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не удалось развернуть демонстрацию на весь экран.'),
          ),
        );
      }
    } finally {
      widget.state.removeListener(closeWhenEnded);
      capturedRoom?.removeListener(closeWhenEnded);
      rendererLease.dispose();
      await presentation?.restore();
      widget.onFullscreenSelectionChanged(null);
    }
  }
}
