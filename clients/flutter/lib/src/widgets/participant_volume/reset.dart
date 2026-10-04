import 'package:flutter/material.dart';
class AudioVolumeReset extends StatefulWidget {
  const AudioVolumeReset({super.key, required this.reset, this.warning});
  final Future<void> Function() reset;
  final String? warning;
  @override
  State<AudioVolumeReset> createState() => _ResetState();
}
class _ResetState extends State<AudioVolumeReset> {
  bool _busy = false;
  Future<void> _reset() async {
    setState(() => _busy = true);
    try { await widget.reset(); } finally { if (mounted) setState(() => _busy = false); }
  }
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    TextButton(onPressed: _busy ? null : _reset, child: const Text('Сбросить настройки аудио')),
    const Text('Возвращает громкость участников и демонстраций к 100% на этом устройстве.'),
    if (widget.warning != null) Semantics(liveRegion: true, child: Text(widget.warning!)),
  ]);
}
