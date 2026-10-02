import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app_state.dart';
import 'controller.dart';
import 'evaluator.dart';
import 'model.dart';

Future<void> performUpdateAction(BuildContext context, UpdateController updates, AppState state) async {
  try { await updates.check(); } catch (_) { return; }
  final policy = updates.policy; final target = policy?.target;
  if (target == null || evaluateUpdate(updates.identity.local, policy!, updates.identity.environment) != UpdateResult.updateAvailable) return;
  final busy = {'joining','connected','listener','reconnecting','leaving'}.contains(state.voicePhase.name) || {'starting','sharing','stopping'}.contains(state.screenSharePhase.name);
  if (busy && context.mounted) {
    final proceed = await showDialog<bool>(context:context, builder:(context)=>AlertDialog(
      title:const Text('Открыть обновление?'), content:const Text('Сейчас активно голосовое подключение или демонстрация. Приложение не завершит их автоматически.'),
      actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('Отмена')),FilledButton(onPressed:()=>Navigator.pop(context,true),child:const Text('Открыть'))],
    ));
    if (proceed != true) return;
  }
  final raw = target.actionUrl; if (raw == null) return;
  final base = Uri.parse(updates.api.baseUrl()); final uri = base.resolve(raw);
  if ((uri.scheme != 'https' && uri.origin != base.origin) || !await launchUrl(uri, mode:LaunchMode.externalApplication)) {
    throw StateError('Не удалось открыть страницу обновления.');
  }
}
