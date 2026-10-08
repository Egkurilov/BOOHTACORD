import 'package:flutter/material.dart';

import '../../features/voice/overlay/settings/model.dart';
import 'content.dart';

class VoiceOverlaySettingsDialog extends StatefulWidget {
  const VoiceOverlaySettingsDialog({
    super.key,
    required this.initial,
    required this.save,
  });
  final OverlayConfiguration initial;
  final Future<bool> Function(OverlayConfiguration) save;
  @override
  State<VoiceOverlaySettingsDialog> createState() => OverlaySettingsView();
}

class OverlaySettingsView extends State<VoiceOverlaySettingsDialog> {
  late OverlayConfiguration draft;
  bool saving = false;
  String? error;
  @override
  void initState() {
    super.initState();
    draft = widget.initial;
  }

  void change(OverlayConfiguration value) => setState(() => draft = value);
  Future<void> submit() async {
    if (saving) return;
    setState(() {
      saving = true;
      error = null;
    });
    bool accepted = false;
    try {
      accepted = await widget.save(draft);
    } catch (_) {}
    if (!mounted) return;
    if (accepted) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      saving = false;
      error = 'Не удалось применить настройки. Проверьте сохранение и доступность горячей клавиши; выберите другую комбинацию при конфликте.';
    });
  }

  @override
  Widget build(BuildContext context) => renderOverlaySettings(this);
}
