String? parsePasswordResetToken(String apiBaseUrl, String rawLink) {
  final base = Uri.tryParse(apiBaseUrl);
  final link = Uri.tryParse(rawLink.trim());
  if (base == null ||
      link == null ||
      base.scheme != 'https' ||
      !base.hasAuthority ||
      link.scheme != 'https' ||
      !link.hasAuthority ||
      link.origin != base.origin ||
      link.path != '/reset-password' ||
      link.hasQuery ||
      link.userInfo.isNotEmpty ||
      link.fragment.isEmpty) {
    return null;
  }

  try {
    final parts = link.fragment.split('&');
    if (parts.length != 1 || !parts.single.startsWith('token=')) return null;
    final token = Uri.decodeQueryComponent(parts.single.substring(6));
    if (!RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(token)) {
      return null;
    }
    return token;
  } on FormatException {
    return null;
  }
}
