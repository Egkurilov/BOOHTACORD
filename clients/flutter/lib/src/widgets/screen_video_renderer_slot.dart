import 'package:flutter/widgets.dart';

enum ScreenVideoRendererOwner { stage, pinnedMini, fullscreen }

enum ScreenVideoRendererSurface { stage, pinnedMini, fullscreen }

class ScreenFullscreenSelection {
  const ScreenFullscreenSelection({
    required this.identity,
    required this.generation,
  });

  final String? identity;
  final Object generation;
}

ScreenVideoRendererOwner screenVideoRendererOwner({
  required String? selectedIdentity,
  required Object? selectedGeneration,
  required String? pinnedIdentity,
  required bool pinnedMiniVisible,
  required ScreenFullscreenSelection? fullscreenSelection,
}) {
  if (fullscreenSelection != null &&
      fullscreenSelection.identity == selectedIdentity &&
      fullscreenSelection.generation == selectedGeneration) {
    return ScreenVideoRendererOwner.fullscreen;
  }
  if (pinnedMiniVisible &&
      selectedIdentity != null &&
      selectedIdentity == pinnedIdentity) {
    return ScreenVideoRendererOwner.pinnedMini;
  }
  return ScreenVideoRendererOwner.stage;
}

bool _shouldMountRenderer({
  required ScreenVideoRendererSurface surface,
  required ScreenVideoRendererOwner owner,
  required bool isSelectedPublication,
  required bool isFullscreenPublication,
}) => switch (surface) {
  ScreenVideoRendererSurface.stage =>
    isSelectedPublication && owner == ScreenVideoRendererOwner.stage,
  ScreenVideoRendererSurface.fullscreen =>
    isSelectedPublication && owner == ScreenVideoRendererOwner.fullscreen,
  ScreenVideoRendererSurface.pinnedMini =>
    !isFullscreenPublication &&
    (!isSelectedPublication || owner == ScreenVideoRendererOwner.pinnedMini),
};

class ScreenVideoRendererSlot extends StatelessWidget {
  const ScreenVideoRendererSlot({
    super.key,
    required this.surface,
    required this.owner,
    required this.isSelectedPublication,
    required this.isFullscreenPublication,
    required this.child,
  });

  final ScreenVideoRendererSurface surface;
  final ScreenVideoRendererOwner owner;
  final bool isSelectedPublication;
  final bool isFullscreenPublication;
  final Widget child;

  @override
  Widget build(BuildContext context) => _shouldMountRenderer(
    surface: surface,
    owner: owner,
    isSelectedPublication: isSelectedPublication,
    isFullscreenPublication: isFullscreenPublication,
  )
      ? child
      : const SizedBox.expand();
}
