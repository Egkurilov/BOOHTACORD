import 'package:flutter/material.dart';

import '../../../theme.dart';

class ConnectionErrorScreen extends StatelessWidget {
  const ConnectionErrorScreen({super.key, required this.error, required this.onRetry});
  final String? error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 48, color: GcColors.muted),
            const SizedBox(height: 16),
            const Text(
              'Не удалось проверить сессию',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Проверьте соединение с сервером и повторите попытку. Повторный вход пока не требуется.',
              textAlign: TextAlign.center,
              style: TextStyle(color: GcColors.textSecondary),
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(
                error!,
                key: const ValueKey('startup-connection-error-detail'),
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () { onRetry(); },
              child: const Text('Повторить подключение'),
            ),
          ],
        ),
      ),
    ),
  );
}

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _BrandMark(size: 64),
          SizedBox(height: 24),
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            'Подключаемся к гильдии…',
            style: TextStyle(color: GcColors.textSecondary),
          ),
        ],
      ),
    ),
  );
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({this.size = 40});
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: GcColors.accent,
      borderRadius: BorderRadius.circular(size * .28),
    ),
    alignment: Alignment.center,
    child: Text(
      'B',
      style: TextStyle(
        color: Colors.white,
        fontSize: size * .48,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}
