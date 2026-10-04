import 'package:flutter/material.dart';
import 'slider.dart';
class ParticipantVolumeMenu extends StatelessWidget {
  const ParticipantVolumeMenu({super.key, required this.name, required this.volume,
    required this.onChanged, required this.onChangeEnd, this.warning});
  final String name;
  final String? warning;
  final int volume;
  final ValueChanged<int> onChanged;
  final VoidCallback onChangeEnd;
  @override
  Widget build(BuildContext context) => MenuAnchor(menuChildren: [
    SizedBox(width: 240, child: Padding(padding: const EdgeInsets.all(12),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ParticipantVolumeSlider(name: name, volume: volume, onChanged: onChanged, onChangeEnd: onChangeEnd),
        if (warning != null) Semantics(liveRegion: true, child: Text(warning!)),
      ]))),
  ], builder: (context, controller, child) => IconButton(
    tooltip: 'Настройки громкости $name',
    onPressed: controller.isOpen ? controller.close : controller.open,
    icon: const Icon(Icons.more_horiz, size: 20),
  ));
}
