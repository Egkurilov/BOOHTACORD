import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'toggle.dart';

class VoiceOverlayDockBinding {
  const VoiceOverlayDockBinding({
    required this.enabled,
    required this.onlySpeakers,
    required this.available,
    required this.onVisibilityChanged,
    required this.onOnlySpeakersChanged,
  });

  final bool enabled;
  final bool onlySpeakers;
  final bool available;
  final ValueChanged<bool> onVisibilityChanged;
  final Future<void> Function(bool) onOnlySpeakersChanged;
}

class VoiceOverlayDock extends StatelessWidget {
  const VoiceOverlayDock({super.key, required this.binding});

  final VoiceOverlayDockBinding binding;

  @override
  Widget build(BuildContext context) => VoiceOverlayToggle(
    enabled: binding.enabled,
    onlySpeakers: binding.onlySpeakers,
    available: binding.available,
    onChanged: binding.onVisibilityChanged,
    onOnlySpeakersChanged: (value) =>
        unawaited(binding.onOnlySpeakersChanged(value)),
  );
}
