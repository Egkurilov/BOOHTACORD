class ScreenShareSenderDescriptor {
  const ScreenShareSenderDescriptor({
    required this.originId,
    required this.accountId,
    required this.roomId,
    required this.mediaSessionId,
    required this.publicationGeneration,
    required this.operationRevision,
    required this.mode,
    required this.requestedProfileId,
  });

  final String originId;
  final String accountId;
  final String roomId;
  final String mediaSessionId;
  final int publicationGeneration;
  final int operationRevision;
  final String mode;
  final String requestedProfileId;
}
