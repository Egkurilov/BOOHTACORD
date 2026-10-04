import 'package:flutter/material.dart';
class MicrophoneLevelMeter extends StatelessWidget {
  const MicrophoneLevelMeter({super.key, required this.levelDb, required this.thresholdDb});
  final double levelDb, thresholdDb;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Уровень микрофона до усиления', value: '${levelDb.round()} dBFS',
    child: Padding(padding: const EdgeInsets.symmetric(vertical: 10),
      child: SizedBox(width: double.infinity, height: 14,
        child: CustomPaint(painter: _Meter(levelDb, thresholdDb, Theme.of(context).colorScheme)),
      ),
    ),
  );
}
class _Meter extends CustomPainter {
  _Meter(this.level, this.threshold, this.colors);
  final double level, threshold;
  final ColorScheme colors;
  double position(double db) => ((db + 90) / 90).clamp(0, 1);
  @override
  void paint(Canvas canvas, Size size) {
    final base = Rect.fromLTWH(0, 3, size.width, 8);
    canvas.drawRRect(RRect.fromRectAndRadius(base, const Radius.circular(4)), Paint()..color = colors.surfaceContainerHighest);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 3, size.width * position(level), 8),
      const Radius.circular(4)), Paint()..color = colors.primary);
    final x = size.width * position(threshold);
    canvas.drawLine(Offset(x, 0), Offset(x, 14), Paint()..color = colors.onSurface..strokeWidth = 2);
  }
  @override
  bool shouldRepaint(_Meter old) => old.level != level || old.threshold != threshold || old.colors != colors;
}
