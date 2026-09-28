import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';

import '../app_state.dart';
import '../services/native_notifications.dart';
import '../theme.dart';
import '../widgets/authenticated_avatar.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.state});
  final AppState state;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _titleFocus = FocusNode(debugLabel: 'profile-screen-title');
  final _displayName = TextEditingController();
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  String? _status;

  @override
  void initState() {
    super.initState();
    _displayName.text = widget.state.profile?.displayName ?? '';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _titleFocus.requestFocus();
    });
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final value = widget.state.profile?.displayName ?? '';
    if (!_displayName.selection.isValid && _displayName.text != value) {
      _displayName.text = value;
    }
  }

  @override
  void dispose() {
    _titleFocus.dispose();
    _displayName.dispose();
    _currentPassword.dispose();
    _newPassword.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    setState(() => _status = null);
    if (await widget.state.saveDisplayName(_displayName.text)) {
      setState(() => _status = 'Имя профиля сохранено.');
    }
  }

  Future<void> _savePassword() async {
    setState(() => _status = null);
    if (await widget.state.updatePassword(
      _currentPassword.text,
      _newPassword.text,
    )) {
      _currentPassword.clear();
      _newPassword.clear();
      setState(() => _status = 'Пароль изменён. Другие сессии завершены.');
    }
  }

  Future<void> _selectAvatar() async {
    setState(() => _status = null);
    try {
      final file = await openFile(
        acceptedTypeGroups: [
          XTypeGroup(
            label: 'Изображения',
            extensions: ['png', 'jpg', 'jpeg'],
            mimeTypes: ['image/png', 'image/jpeg'],
          ),
        ],
      );
      if (file == null || !mounted) return;
      if (await file.length() > 2 * 1024 * 1024) {
        widget.state.reportError('Изображение должно быть не больше 2 МиБ.');
        return;
      }
      final bytes = await file.readAsBytes();
      final isPng =
          bytes.length >= 8 &&
          bytes[0] == 0x89 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x4e &&
          bytes[3] == 0x47 &&
          bytes[4] == 0x0d &&
          bytes[5] == 0x0a &&
          bytes[6] == 0x1a &&
          bytes[7] == 0x0a;
      final isJpeg =
          bytes.length >= 3 &&
          bytes[0] == 0xff &&
          bytes[1] == 0xd8 &&
          bytes[2] == 0xff;
      if (!isPng && !isJpeg) {
        widget.state.reportError('Выберите изображение PNG или JPEG.');
        return;
      }
      if (await widget.state.uploadAvatar(
        bytes,
        isPng ? 'image/png' : 'image/jpeg',
      )) {
        if (mounted) setState(() => _status = 'Аватар обновлён.');
      }
    } catch (_) {
      if (mounted) {
        widget.state.reportError('Не удалось прочитать изображение.');
      }
    }
  }

  Future<void> _removeAvatar() async {
    setState(() => _status = null);
    if (await widget.state.deleteAvatar()) {
      if (mounted) setState(() => _status = 'Аватар удалён.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.state.profile;
    return ColoredBox(
      color: GcColors.content,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth <= 720;
          final inset = compact ? 16.0 : 24.0;
          final contentWidth = (constraints.maxWidth - inset * 2)
              .clamp(0.0, 720.0)
              .toDouble();
          return ListView(
            padding: EdgeInsets.all(inset),
            children: [
              Center(
                child: SizedBox(
                  key: const ValueKey('profile-settings-content'),
                  width: contentWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Focus(
                        key: const ValueKey('profile-screen-title-focus'),
                        focusNode: _titleFocus,
                        child: Semantics(
                          header: true,
                          child: const Text(
                            'Профиль',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Настройки вашей учётной записи',
                        style: TextStyle(color: GcColors.textSecondary),
                      ),
                      const SizedBox(height: 32),
                      if (widget.state.profileLoading)
                        Semantics(
                          liveRegion: true,
                          child: Text('Загружаем профиль…'),
                        )
                      else if (widget.state.profileLoadError != null)
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            widget.state.profileLoadError!,
                            style: const TextStyle(color: GcColors.danger),
                          ),
                        )
                      else if (profile != null) ...[
                        Row(
                          children: [
                            AuthenticatedAvatar(
                              state: widget.state,
                              name: profile.displayName,
                              avatarUrl: profile.avatarUrl,
                              radius: 32,
                            ),
                            const SizedBox(width: 16),
                            OutlinedButton(
                              onPressed: widget.state.profileSaving
                                  ? null
                                  : _selectAvatar,
                              child: const Text('Загрузить аватар'),
                            ),
                            if (profile.avatarUrl != null) ...[
                              const SizedBox(width: 8),
                              TextButton(
                                onPressed: widget.state.profileSaving
                                    ? null
                                    : _removeAvatar,
                                child: const Text('Удалить'),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 32),
                        ConstrainedBox(
                          key: const ValueKey('profile-name-form-width'),
                          constraints: const BoxConstraints(maxWidth: 480),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextField(
                                controller: _displayName,
                                decoration: const InputDecoration(
                                  labelText: 'Имя пользователя',
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                initialValue: profile.login,
                                readOnly: true,
                                decoration: const InputDecoration(
                                  labelText: 'Логин',
                                ),
                              ),
                              const SizedBox(height: 16),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: FilledButton(
                                  onPressed: widget.state.profileSaving
                                      ? null
                                      : _saveName,
                                  child: const Text('Сохранить изменения'),
                                ),
                              ),
                              const SizedBox(height: 32),
                              const Divider(height: 1, color: GcColors.border),
                              const SizedBox(height: 32),
                              const Text(
                                'Изменить пароль',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _currentPassword,
                                obscureText: true,
                                decoration: const InputDecoration(
                                  labelText: 'Текущий пароль',
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _newPassword,
                                obscureText: true,
                                decoration: const InputDecoration(
                                  labelText: 'Новый пароль',
                                ),
                              ),
                              const SizedBox(height: 16),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: FilledButton(
                                  onPressed: widget.state.profileSaving
                                      ? null
                                      : _savePassword,
                                  child: const Text('Обновить пароль'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (_status != null) ...[
                        const SizedBox(height: 20),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            _status!,
                            style: const TextStyle(color: GcColors.success),
                          ),
                        ),
                      ],
                      if (widget.state.error != null) ...[
                        const SizedBox(height: 12),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            widget.state.error!,
                            style: const TextStyle(color: GcColors.danger),
                          ),
                        ),
                      ],
                      if (widget.state.notificationsSupported) ...[
                        const SizedBox(height: 32),
                        const Divider(height: 1, color: GcColors.border),
                        const SizedBox(height: 32),
                        const Text(
                          'Уведомления',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Показываем общий текст нового сообщения, пока приложение неактивно. Содержимое личных сообщений не отображается.',
                          style: TextStyle(color: GcColors.textSecondary),
                        ),
                        const SizedBox(height: 8),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            switch (widget.state.notificationPermission) {
                              NativeNotificationPermission.unavailable =>
                                'Системные уведомления недоступны.',
                              NativeNotificationPermission.denied =>
                                'Уведомления запрещены в настройках системы.',
                              NativeNotificationPermission.granted =>
                                widget.state.notificationsEnabled
                                    ? 'Уведомления включены.'
                                    : 'Уведомления выключены.',
                            },
                          ),
                        ),
                        if (widget.state.notificationError != null) ...[
                          const SizedBox(height: 8),
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              widget.state.notificationError!,
                              style: const TextStyle(color: GcColors.danger),
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: OutlinedButton(
                            onPressed:
                                widget.state.notificationPermission ==
                                    NativeNotificationPermission.unavailable
                                ? null
                                : widget.state.notificationsEnabled
                                ? widget.state.disableNotifications
                                : widget.state.enableNotifications,
                            child: Text(
                              widget.state.notificationsEnabled
                                  ? 'Отключить уведомления'
                                  : 'Включить уведомления',
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 32),
                      const Divider(height: 1, color: GcColors.border),
                      const SizedBox(height: 32),
                      const Text(
                        'Выход из аккаунта',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Голосовое подключение завершится, а личные данные исчезнут с этого экрана.',
                        style: TextStyle(color: GcColors.textSecondary),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton(
                          onPressed:
                              widget.state.logoutBusy ||
                                  widget.state.profileSaving
                              ? null
                              : widget.state.logout,
                          child: Text(
                            widget.state.logoutBusy
                                ? 'Выходим…'
                                : 'Выйти из аккаунта',
                          ),
                        ),
                      ),
                      if (widget.state.logoutError != null) ...[
                        const SizedBox(height: 8),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            widget.state.logoutError!,
                            style: const TextStyle(color: GcColors.danger),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
