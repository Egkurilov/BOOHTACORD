class RealtimeEvent {
  const RealtimeEvent(this.id, this.kind, this.payload);
  final String id;
  final String? kind;
  final Map<String, dynamic> payload;
}
