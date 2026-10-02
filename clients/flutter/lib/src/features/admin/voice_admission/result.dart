class VoiceAdmissionCloseResult {
  const VoiceAdmissionCloseResult({
    required this.channelId,
    required this.revision,
    required this.revokedLeases,
  });

  final String channelId;
  final int revision;
  final int revokedLeases;
}
