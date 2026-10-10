class WorkspaceSearchSession {
  const WorkspaceSearchSession({
    required this.query,
    required this.scope,
    required this.scrollOffset,
    required this.shouldSearch,
  });

  final String query;
  final String scope;
  final double scrollOffset;
  final bool shouldSearch;
}
