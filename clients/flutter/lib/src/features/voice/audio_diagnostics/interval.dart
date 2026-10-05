import 'model.dart';
({bool fresh, bool valid}) audioInterval(Map<String, Object?> current,
    Map<String, Object?>? previous, double at, double? previousAt, String direction) {
  final dt = previousAt == null ? 0.0 : at - previousAt;
  final changed = previous != null &&
      ['ssrc', 'codecId', 'mediaSourceId', 'mid', 'transportId']
          .any((key) => current[key] != previous[key]);
  final timestamp = statNumber(current['timestamp']);
  final oldTimestamp = statNumber(previous?['timestamp']);
  final fresh = previous == null || changed || timestamp == null ||
      oldTimestamp == null || timestamp > oldTimestamp;
  final suffix = direction == 'sender' ? 'Sent' : 'Received';
  final reset = ['bytes$suffix', 'packets$suffix'].any((key) {
    final now = statNumber(current[key]), old = statNumber(previous?[key]);
    return now != null && old != null && now < old;
  });
  return (fresh: fresh, valid: fresh && !changed && !reset &&
      dt.isFinite && dt > 0 && dt <= 15000);
}
