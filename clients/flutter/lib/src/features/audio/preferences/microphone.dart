class MicrophoneSettings {
  const MicrophoneSettings({this.vadThresholdDb = -50, this.microphoneGainPercent = 100});
  final double vadThresholdDb;
  final double microphoneGainPercent;
  static double _number(Object? value, double fallback, double min, double max) =>
      value is num && value.isFinite ? value.toDouble().clamp(min, max).roundToDouble() : fallback;
  factory MicrophoneSettings.fromJson(Object? raw) {
    final value = raw is Map ? raw : const {};
    return MicrophoneSettings(
      vadThresholdDb: _number(value['vadThresholdDb'], -50, -70, -20),
      microphoneGainPercent: _number(value['microphoneGainPercent'], 100, 0, 200),
    );
  }
  Map<String, double> toJson() => {
    'vadThresholdDb': vadThresholdDb, 'microphoneGainPercent': microphoneGainPercent,
  };
  MicrophoneSettings copyWith({double? vadThresholdDb, double? microphoneGainPercent}) =>
      MicrophoneSettings.fromJson({
        'vadThresholdDb': vadThresholdDb ?? this.vadThresholdDb,
        'microphoneGainPercent': microphoneGainPercent ?? this.microphoneGainPercent,
      });
}
