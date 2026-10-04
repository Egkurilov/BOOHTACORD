import 'package:flutter/material.dart';
class ParticipantVolumeSlider extends StatefulWidget {
  const ParticipantVolumeSlider({super.key, required this.name, required this.volume,
    required this.onChanged, required this.onChangeEnd});
  final String name;
  final int volume;
  final ValueChanged<int> onChanged;
  final VoidCallback onChangeEnd;
  @override
  State<ParticipantVolumeSlider> createState() => _SliderState();
}
class _SliderState extends State<ParticipantVolumeSlider> {
  late int _volume = widget.volume;
  @override
  void didUpdateWidget(covariant ParticipantVolumeSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.volume != widget.volume) _volume = widget.volume;
  }
  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
    Text('Громкость · $_volume%'),
    Semantics(label: 'Громкость участника ${widget.name}', child: Slider(
      value: _volume.clamp(0, 200).toDouble(), min: 0, max: 200, divisions: 200,
      semanticFormatterCallback: (value) => '${value.round()} процентов',
      onChanged: (value) { setState(() => _volume = value.round()); widget.onChanged(_volume); },
      onChangeEnd: (_) => widget.onChangeEnd(),
    )),
  ]);
}
