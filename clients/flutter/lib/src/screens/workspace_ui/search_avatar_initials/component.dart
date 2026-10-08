String workspaceSearchAvatarInitials(String name) {
  final letters = RegExp(r'\p{L}', unicode: true)
      .allMatches(name)
      .take(2)
      .map((match) => match.group(0)!.toUpperCase())
      .join();
  return letters.isEmpty ? 'У' : letters;
}
