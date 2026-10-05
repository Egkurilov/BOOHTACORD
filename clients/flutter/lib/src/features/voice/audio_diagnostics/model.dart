import '../audio_report/export.dart';
class VoiceAudioDiagnostics {
  const VoiceAudioDiagnostics(this.profile, this.capBps, this.capture, this.samples);
  final String profile;
  final int? capBps;
  final Map<String, Object?> capture;
  final List<Map<String, Object?>> samples;
  Map<String, Object?> toSafeJson() => safeVoiceAudioReport(profile, capBps, capture, samples);
}
double? statNumber(Object? value) {
  if (value is! num && value is! String) return null;
  final number = double.tryParse(value.toString());
  return number != null && number.isFinite && number >= 0 ? number : null;
}
