bool pinnedScreenMiniPlayerVisible({
  required String? pinnedScreenIdentity,
  required String? activeVoiceChannelId,
  required String? selectedChannelId,
  required bool directMessageOpen,
  required bool workspacePanelOpen,
}) {
  if (pinnedScreenIdentity == null || activeVoiceChannelId == null) {
    return false;
  }
  return directMessageOpen ||
      workspacePanelOpen ||
      selectedChannelId != activeVoiceChannelId;
}

bool screenSelectionBelongsToVoiceChannel({
  required String? selectionVoiceChannelId,
  required String? activeVoiceChannelId,
}) =>
    selectionVoiceChannelId != null &&
    selectionVoiceChannelId == activeVoiceChannelId;

bool pinnedScreenPublicationEnded({
  required bool participantPresent,
  required bool publicationPresent,
}) => !participantPresent || !publicationPresent;
