import '../lifecycle/event.dart';

bool dispatchScreenPreviewEvent(
  RealtimeEvent event,
  void Function(Map<String, dynamic>)? updated,
  void Function(Map<String, dynamic>)? invalidated,
) {
  if (event.kind == 'screen_preview.updated') updated?.call(event.payload);
  if (event.kind == 'screen_preview.invalidated') invalidated?.call(event.payload);
  return event.kind == 'screen_preview.updated' ||
      event.kind == 'screen_preview.invalidated';
}
