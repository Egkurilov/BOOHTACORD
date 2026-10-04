import 'package:flutter/material.dart';
import '../../features/voice/disconnect_notice/model.dart';
class VoiceDisconnectNoticeView extends StatelessWidget {
  const VoiceDisconnectNoticeView({super.key, required this.notice});
  final VoiceDisconnectNotice notice;
  @override
  Widget build(BuildContext context) => Semantics(container: true, liveRegion: true,
    child: Container(width: double.infinity, padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFF422830), borderRadius: BorderRadius.circular(10)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(notice.message, textAlign: TextAlign.center),
        if (notice.explanation.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6),
          child: Text(notice.explanation, textAlign: TextAlign.center)),
      ]),
    ));
}
