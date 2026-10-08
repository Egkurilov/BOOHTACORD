String workspaceMessageSnippet(String body) {
  final flattened = body.replaceAll('\n', ' ').trim();
  return flattened.length <= 140
      ? flattened
      : '${flattened.substring(0, 140)}…';
}
