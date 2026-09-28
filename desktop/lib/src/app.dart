import 'package:flutter/material.dart';

import 'app_state.dart';
import 'screens/auth_screen.dart';
import 'screens/password_reset_screen.dart';
import 'screens/workspace_screen.dart';
import 'theme.dart';

class BoohtacordApp extends StatelessWidget {
  const BoohtacordApp({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'BOOHTACORD',
    debugShowCheckedModeBanner: false,
    theme: guildTheme(),
    home: AnimatedBuilder(
      animation: state,
      builder: (context, _) => Column(
        children: [
          if (state.maintenanceActive) const _MaintenanceBanner(),
          Expanded(
            child: switch (state.phase) {
              AppPhase.loading => const _LoadingScreen(),
              AppPhase.connectionError => _ConnectionErrorScreen(state: state),
              AppPhase.signedOut =>
                state.resetRoute
                    ? PasswordResetScreen(state: state)
                    : AuthScreen(state: state),
              AppPhase.ready => WorkspaceScreen(
                state: state,
                maintenanceBannerVisible: state.maintenanceActive,
              ),
            },
          ),
        ],
      ),
    ),
  );
}

class _ConnectionErrorScreen extends StatelessWidget {
  const _ConnectionErrorScreen({required this.state});
  final AppState state;

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
            const SizedBox(height: 24),
            FilledButton(
              onPressed: state.initialize,
              child: const Text('Повторить подключение'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _MaintenanceBanner extends StatelessWidget {
  const _MaintenanceBanner();

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      key: const ValueKey('maintenance-banner'),
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 44),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: GcColors.warningBackground,
      child: const Text(
        'Идёт обновление: новые входы и подключения к голосу временно приостановлены.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: GcColors.warning,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          height: 20 / 14,
          decoration: TextDecoration.none,
        ),
      ),
    ),
  );
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();
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
