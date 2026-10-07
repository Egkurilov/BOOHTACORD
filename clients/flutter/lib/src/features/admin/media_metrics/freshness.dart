import '../../../models.dart';

enum AdminMediaFreshnessState { populated, empty, stale, error }

class AdminMediaFreshness {
  const AdminMediaFreshness(this.state, this.freshSamples);

  final AdminMediaFreshnessState state;
  final List<AdminScreenSample> freshSamples;
  int get freshCount => freshSamples.length;
}

AdminMediaFreshness selectAdminMediaFreshness({
  required List<AdminScreenSample> samples,
  required DateTime nowUtc,
  DateTime? lastSeenAt,
  bool hasError = false,
}) {
  final fresh = hasError
      ? <AdminScreenSample>[]
      : samples.where((sample) {
          final at = sample.sampledAtUtc;
          return !at.isBefore(nowUtc.subtract(const Duration(seconds: 60))) &&
              !at.isAfter(nowUtc.add(const Duration(seconds: 5)));
        }).toList(growable: false);
  final state = hasError
      ? AdminMediaFreshnessState.error
      : fresh.isNotEmpty
      ? AdminMediaFreshnessState.populated
      : samples.isEmpty && lastSeenAt == null
      ? AdminMediaFreshnessState.empty
      : AdminMediaFreshnessState.stale;
  return AdminMediaFreshness(state, fresh);
}

DateTime? latestAdminMediaSeenAt(
  DateTime? previous,
  List<AdminScreenSample> samples,
) {
  var latest = previous;
  for (final sample in samples) {
    if (latest == null || sample.sampledAtUtc.isAfter(latest)) {
      latest = sample.sampledAtUtc;
    }
  }
  return latest;
}
