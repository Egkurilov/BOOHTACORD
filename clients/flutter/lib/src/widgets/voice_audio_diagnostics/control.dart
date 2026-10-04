import 'dart:convert';
import 'package:flutter/material.dart';
import '../../features/voice/audio_diagnostics/model.dart';
import '../../features/voice/audio_profile/generated.dart';
import '../../features/voice/audio_profile/profile.dart';

class VoiceAudioDiagnosticsControl extends StatefulWidget {
  const VoiceAudioDiagnosticsControl({super.key, required this.connected, this.diagnostics});
  final bool connected;
  final VoiceAudioDiagnostics? diagnostics;
  @override
  State<VoiceAudioDiagnosticsControl> createState() => _VoiceAudioDiagnosticsControlState();
}
class _VoiceAudioDiagnosticsControlState extends State<VoiceAudioDiagnosticsControl> {
  String selected = selectedVoiceAudioProfile['id']! as String;
  bool exported = false;
  String metric(Object? value, [String unit = '']) => value == null ? 'неизвестно' : '${value is num ? (value * 100).round() / 100 : value}$unit';
  String flag(Object? value) => value == null ? 'неизвестно' : value == true ? 'да' : 'нет';
  @override
  Widget build(BuildContext context) {
    final snapshot = widget.diagnostics;
    return ExpansionTile(
      title: const Text('Диагностика качества голоса'),
      childrenPadding: const EdgeInsets.all(12),
      children: [
        DropdownButtonFormField<String>(
          initialValue: selected, isExpanded: true,
          decoration: const InputDecoration(labelText: 'Профиль следующего подключения'),
          items: [for (final profile in voiceAudioProfiles) DropdownMenuItem(
            value: profile['id']! as String,
            child: Text('${(profile['maxBitrate']! as int) ~/ 1000} кбит/с'),
          )],
          onChanged: widget.connected ? null : (id) {
            if (id != null && selectVoiceAudioProfile(id)) setState(() => selected = id);
          },
        ),
        const Text('64 и 96 кбит/с — кандидаты для A/B. Улучшение качества ещё не подтверждено.'),
        const Text('Запрошено: Opus, mono, 48 кГц, высокий приоритет, DTX и RED. Фактические параметры — ниже.'),
        if (snapshot == null) const Text('Статистика появляется после подключения и двух измерений.'),
        if (snapshot != null) ...[
          Text('Профиль: ${snapshot.profile}; предел ${metric(snapshot.capBps)} бит/с.'),
          Text('Capture: ${metric(snapshot.capture['sampleRate'])} Гц, ${metric(snapshot.capture['channels'])} каналов. AGC ${flag(snapshot.capture['agc'])}, AEC ${flag(snapshot.capture['aec'])}, NS ${flag(snapshot.capture['ns'])}.'),
          const Text('Native SDK не подтверждает параметры исходного capture. Каналы RTP Opus не доказывают стерео capture.'),
          Text('Последний native processing hook: ${metric(snapshot.capture['processingSampleRate'])} Гц, ${metric(snapshot.capture['processingChannels'])} каналов. Это формат PCM обработки, не аппаратного capture.'),
          if (snapshot.samples.isEmpty) const Text('SDK не сообщил RTP-статистику микрофона.'),
          for (final sample in snapshot.samples) Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('${sample['direction'] == 'sender' ? 'Отправка' : 'Приём'}: codec ${metric(sample['codec'])} / RTP ${metric(sample['transportCodec'])}, ${metric(sample['clockRate'])} Гц, ${metric(sample['codecChannels'])} RTP каналов.\n'
              'Stereo ${flag(sample['stereo'])}, DTX ${flag(sample['dtx'])}, RED ${flag(sample['red'])}, FEC ${flag(sample['fec'])}.\n'
              '${metric(sample['bitrateBps'])} бит/с; пакеты ${metric(sample['packets'])}; jitter ${metric(sample['jitterMs'])} мс; loss ${metric(sample['lossPercent'])}%; concealment ${metric(sample['concealedSamples'])} samples / ${metric(sample['concealmentEvents'])} events за ${metric(sample['intervalMs'])} мс.\n'
              'Уровень (только локально): ${metric(sample['audioLevel'])}'),
          ),
          TextButton(onPressed: () => setState(() => exported = !exported), child: const Text('Показать безопасный отчёт для A/B')),
          if (exported) SelectableText(const JsonEncoder.withIndent('  ').convert(snapshot.toSafeJson())),
        ],
      ],
    );
  }
}
