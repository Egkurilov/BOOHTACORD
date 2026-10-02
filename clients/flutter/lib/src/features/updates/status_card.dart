import 'package:flutter/material.dart';

import '../../../app_version.dart';
import '../../../theme.dart';
import 'scope.dart';
import 'model.dart';

class ClientUpdateStatusCard extends StatelessWidget {
  const ClientUpdateStatusCard({super.key});
  @override Widget build(BuildContext context) {
    final updates = UpdateScope.maybeOf(context);
    if (updates == null) return const Text(appVersionLabel, key:ValueKey('app-version-label'), style:TextStyle(color:GcColors.muted,fontSize:12));
    return AnimatedBuilder(animation:updates,builder:(context,_)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Divider(height:1,color:GcColors.border), const SizedBox(height:24),
      const Text('Версия приложения',style:TextStyle(fontSize:20,fontWeight:FontWeight.w600)),
      const SizedBox(height:8),Text('$appVersionLabel · ${updates.result?.wireName ?? 'ещё не проверено'}${updates.stale ? ' · данные устарели' : ''}',style:const TextStyle(color:GcColors.textSecondary)),
      const SizedBox(height:12),OutlinedButton(onPressed:updates.status.name == 'checking' ? null : updates.manual,child:Text(updates.status.name == 'checking' ? 'Проверяем…' : 'Проверить обновления')),
      if (updates.error != null) ...[const SizedBox(height:8),Text(updates.error!,style:const TextStyle(color:GcColors.danger))],
    ]));
  }
}
