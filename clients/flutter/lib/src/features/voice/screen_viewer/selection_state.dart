mixin VoiceScreenViewerSelectionState {
  String? _selectedRemoteScreenViewerIdentity;
  String? get selectedRemoteScreenViewerIdentity =>
      _selectedRemoteScreenViewerIdentity;
  set selectedRemoteScreenViewerIdentity(String? identity) {
    if (_selectedRemoteScreenViewerIdentity == identity) return;
    _selectedRemoteScreenViewerIdentity = identity;
    screenViewerSelectionRevision++;
  }

  int screenViewerSelectionRevision = 0;
}
