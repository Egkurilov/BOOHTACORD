import 'controller.dart';

extension ProfileRefresh on ProfileController {
  Future<void> refreshProfile() => _refreshProfile();

  Future<void> refreshProfileIfNewer(int revision) {
    if ((profileRevision ?? 0) >= revision) return Future<void>.value();
    return _refreshProfile(minimumRevision: revision);
  }

  Future<void> _refreshProfile({int? minimumRevision}) async {
    final ticket = scope.capture();
    if (disposed || !ticket.isActive) return;
    final request = revision;
    final profileRequest = ++profileRequestSequence;
    bool current() => accepts(ticket, request) &&
        profileRequest == profileRequestSequence;
    profileLoading = true;
    profileLoadError = null;
    changed();
    try {
      final result = await api.ownProfile();
      if (current()) acceptProfile(result, minimumRevision: minimumRevision);
    } catch (cause) {
      if (current()) profileLoadError = message(cause);
    } finally {
      if (current()) {
        profileLoading = false;
        changed();
      }
    }
  }
}
