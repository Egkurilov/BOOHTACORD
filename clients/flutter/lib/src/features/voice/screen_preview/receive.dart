import '../lifecycle/controller.dart';
import 'receive_state.dart';

final screenPreviewReceivers = Expando<ScreenPreviewReceiver>();

extension VoiceScreenPreviewReceive on VoiceController {
  void clearScreenPreviewReceivers() => screenPreviewReceivers[this]?.clear();

  void receiveScreenPreviewHint(Map<String, dynamic> payload) {
    final lease = payload['lease_id'], generation = payload['generation_id'];
    final revision = payload['revision'];
    if (lease is! String || generation is! String || revision is! int ||
        revision < 1 || !_isUuid(lease) || !_isUuid(generation)) return;
    (screenPreviewReceivers[this] ??= ScreenPreviewReceiver(this))
        .updated(lease, generation, revision);
  }

  void receiveScreenPreviewInvalidation(Map<String, dynamic> payload) {
    final lease = payload['lease_id'], generation = payload['generation_id'];
    if (lease is! String || generation is! String ||
        !_isUuid(lease) || !_isUuid(generation)) return;
    screenPreviewReceivers[this]?.invalidated(lease, generation);
  }
}

bool _isUuid(String value) => RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  caseSensitive: false,
).hasMatch(value);
