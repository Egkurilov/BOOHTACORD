Map<String, dynamic> withAvatarRevision(
  Map<String, dynamic> profile,
  int? revision,
) {
  final url = profile['avatar_url'];
  if (revision == null || url is! String) return profile;
  try {
    final uri = Uri.parse(url);
    return {
      ...profile,
      'avatar_url': uri.replace(
        queryParameters: {...uri.queryParameters, 'revision': '$revision'},
      ).toString(),
    };
  } on FormatException {
    return profile;
  }
}
