import 'package:boohtacord_desktop/src/features/session/lifecycle/controller.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';

SessionEffects effects({
  Future<void> Function()? clear,
  Future<void> Function()? ready,
}) => SessionEffects(
  initialize: () async {},
  prepare: (_) async {},
  ready: ready ?? () async {},
  closeMedia: () async {},
  closeRealtime: () async {},
  clearAccount: clear ?? () async {},
  expireAccount: () async {},
  beforeServerChange: () {},
  clearServer: () async {},
  error: (_) {},
  message: (cause) => cause is ApiFailure ? cause.message : cause.toString(),
);
