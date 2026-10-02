import 'package:flutter/material.dart';

import 'app_state.dart';
import 'screens/auth_screen.dart';
import 'screens/password_reset_screen.dart';
import 'screens/workspace_screen.dart';
import 'theme.dart';
import 'features/session/startup/widgets.dart';
import 'features/session/maintenance/banner.dart';
import 'features/updates/banner.dart';
import 'features/updates/controller.dart';
import 'features/updates/scope.dart';

class BoohtacordApp extends StatelessWidget {
  BoohtacordApp({super.key, required this.state, UpdateController? updates})
    : updates = updates ?? UpdateController.disabled();
  final AppState state;
  final UpdateController updates;

  @override
  Widget build(BuildContext context) => UpdateScope(controller:updates, child:MaterialApp(
    title: 'BOOHTACORD',
    debugShowCheckedModeBanner: false,
    theme: guildTheme(),
    home: AnimatedBuilder(
      animation: Listenable.merge([state, updates]),
      builder: (context, _) => Column(
        children: [
          if (state.maintenanceActive) const MaintenanceBanner(),
          ClientUpdateBanner(updates:updates, state:state),
          Expanded(
            child: switch (state.phase) {
              AppPhase.loading => const LoadingScreen(),
              AppPhase.connectionError => ConnectionErrorScreen(state: state),
              AppPhase.signedOut =>
                state.resetRoute
                    ? PasswordResetScreen(state: state)
                    : AuthScreen(state: state),
              AppPhase.ready => WorkspaceScreen(
                state: state,
                maintenanceBannerVisible: state.maintenanceActive,
                openNavigationInitially: true,
              ),
            },
          ),
        ],
      ),
    ),
  ));
}
