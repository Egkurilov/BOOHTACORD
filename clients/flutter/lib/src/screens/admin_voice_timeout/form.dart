import 'package:flutter/material.dart';

import '../../features/admin/voice_timeout/model.dart';
import 'controller.dart';

class VoiceTimeoutForm extends StatelessWidget {
  const VoiceTimeoutForm({super.key, required this.owner});
  final AdminVoiceTimeoutController owner;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      DropdownButtonFormField<int>(
        initialValue: owner.minutes,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Длительность'),
        items: const [
          DropdownMenuItem(value: 5, child: Text('5 минут')),
          DropdownMenuItem(value: 15, child: Text('15 минут')),
          DropdownMenuItem(value: 60, child: Text('1 час')),
          DropdownMenuItem(value: 240, child: Text('4 часа')),
          DropdownMenuItem(value: 1440, child: Text('24 часа')),
        ],
        onChanged: owner.canMutate
            ? (value) => owner.select(duration: value)
            : null,
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<VoiceTimeoutReason>(
        initialValue: owner.reason,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Причина'),
        items: [
          for (final reason in VoiceTimeoutReason.values)
            DropdownMenuItem(value: reason, child: Text(reason.label)),
        ],
        onChanged: owner.canMutate ? (value) => owner.select(why: value) : null,
      ),
    ],
  );
}
