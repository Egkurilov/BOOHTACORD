import 'package:flutter/material.dart';

class VoiceViewerLayout extends StatelessWidget {
  const VoiceViewerLayout({
    super.key,
    required this.stage,
    required this.diagnostics,
    required this.participants,
    this.audioControls,
    this.streamRail,
  });

  final Widget stage;
  final Widget diagnostics;
  final Widget? audioControls;
  final Widget? streamRail;
  final Widget participants;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(child: stage),
      diagnostics,
      ?audioControls,
      ?streamRail,
      participants,
    ],
  );
}
