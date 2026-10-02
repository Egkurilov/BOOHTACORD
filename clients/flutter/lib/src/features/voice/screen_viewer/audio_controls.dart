import 'package:flutter/material.dart';

import '../../../theme.dart';

class VoiceScreenAudioControls extends StatelessWidget {
  const VoiceScreenAudioControls({
    super.key,
    required this.showingLocalScreen,
    required this.screenAudioAvailable,
    required this.screenAudioVolume,
    required this.screenAudioMuted,
    required this.deafened,
    required this.onToggleScreenAudio,
    required this.onScreenAudioVolumeChanged,
  });

  final bool showingLocalScreen;
  final bool screenAudioAvailable;
  final int? screenAudioVolume;
  final bool screenAudioMuted;
  final bool deafened;
  final VoidCallback? onToggleScreenAudio;
  final ValueChanged<int>? onScreenAudioVolumeChanged;

  @override
  Widget build(BuildContext context) {
    if (showingLocalScreen) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Предпросмотр собственного экрана без звука.',
            style: TextStyle(color: GcColors.muted, fontSize: 12),
          ),
        ),
      );
    }

    if (!screenAudioAvailable) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'У демонстрации нет аудиодорожки.',
            style: TextStyle(color: GcColors.muted, fontSize: 12),
          ),
        ),
      );
    }

    if (screenAudioVolume == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Row(
          children: [
            _muteButton,
            Expanded(
              child: Text(
                deafened
                    ? 'Удалённый звук выключен; аудиодорожка сейчас не воспроизводится.'
                    : 'Аудиодорожка есть; личная настройка громкости недоступна.',
                style: const TextStyle(color: GcColors.muted, fontSize: 12),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (deafened)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Text(
                'Удалённый звук выключен; аудиодорожка сейчас не воспроизводится.',
                style: TextStyle(color: GcColors.muted, fontSize: 12),
              ),
            ),
          Row(
            children: [
              _muteButton,
              SizedBox(
                width: 220,
                child: Text(
                  'Громкость аудиодорожки · $screenAudioVolume%',
                  style: const TextStyle(color: GcColors.textSecondary),
                ),
              ),
              Expanded(
                child: Semantics(
                  label: 'Громкость звука выбранной демонстрации',
                  child: Slider(
                    key: const ValueKey('screen-share-audio-volume-slider'),
                    value: screenAudioVolume!.toDouble(),
                    min: 0,
                    max: 200,
                    divisions: 200,
                    semanticFormatterCallback: (value) =>
                        '${value.round()} процентов',
                    onChanged: deafened || onScreenAudioVolumeChanged == null
                        ? null
                        : (value) => onScreenAudioVolumeChanged!(value.round()),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool get _muted => screenAudioMuted || screenAudioVolume == 0;

  Widget get _muteButton => Semantics(
    toggled: !_muted,
    child: IconButton(
      tooltip: _muted
          ? 'Включить звук трансляции'
          : 'Выключить звук трансляции',
      onPressed: deafened ? null : onToggleScreenAudio,
      icon: Icon(
        _muted || deafened
            ? Icons.volume_off_outlined
            : Icons.volume_up_outlined,
      ),
    ),
  );
}
