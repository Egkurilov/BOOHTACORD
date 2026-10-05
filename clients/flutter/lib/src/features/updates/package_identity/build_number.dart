/// Flutter adds a per-ABI offset to Android split APK version codes.
bool packageBuildMatches({
  required String? platform,
  required String arch,
  required String? declared,
  required String? installed,
}) {
  if (declared == null || installed == null || declared == installed) return true;
  if (platform != 'android') return false;
  final canonical = RegExp(r'^[1-9][0-9]*$');
  if (!canonical.hasMatch(declared) || !canonical.hasMatch(installed)) {
    return false;
  }
  final offset = switch (arch) {
    'armv7' => 1000,
    'arm64' => 2000,
    'x64' => 4000,
    _ => null,
  };
  final base = int.tryParse(declared);
  final actual = int.tryParse(installed);
  return offset != null && base != null && actual == base + offset;
}
