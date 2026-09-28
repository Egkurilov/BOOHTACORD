import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';

import '../app_state.dart';
import '../theme.dart';
import '../widgets/authenticated_avatar.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.state});
  final AppState state;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _displayName = TextEditingController();
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  String? _status;

  @override
  void initState() {
    super.initState();
    _displayName.text = widget.state.profile?.displayName ?? '';
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
      child: ListView(
        padding: const EdgeInsets.all(32),
        children: [
          const Text(
            'Профиль',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const Text(
            'Настройки вашей учётной записи',
            style: TextStyle(color: GcColors.textSecondary),
          ),
          const SizedBox(height: 28),
          if (widget.state.profileLoading)
            Semantics(liveRegion: true, child: Text('Загружаем профиль…'))
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
                  radius: 36,
                ),
                const SizedBox(width: 16),
                OutlinedButton(
                  onPressed: widget.state.profileSaving ? null : _selectAvatar,
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
            const SizedBox(height: 28),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _displayName,
                    maxLength: 64,
                    decoration: const InputDecoration(
                      labelText: 'Имя пользователя',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: profile.login,
                    readOnly: true,
                    decoration: const InputDecoration(labelText: 'Логин'),
                  ),
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton(
                      onPressed: widget.state.profileSaving ? null : _saveName,
                      child: const Text('Сохранить изменения'),
                    ),
                  ),
                  const SizedBox(height: 36),
                  const Text(
                    'Изменить пароль',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _currentPassword,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Текущий пароль',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _newPassword,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Новый пароль',
                    ),
                  ),
                  const SizedBox(height: 14),
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
            Text(_status!, style: const TextStyle(color: GcColors.success)),
          ],
          if (widget.state.error != null) ...[
            const SizedBox(height: 12),
            Text(
              widget.state.error!,
              style: const TextStyle(color: GcColors.danger),
            ),
          ],
          const SizedBox(height: 36),
          const Text(
            'Выход из аккаунта',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'Голосовое подключение завершится, а личные данные исчезнут с этого экрана.',
            style: TextStyle(color: GcColors.textSecondary),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              onPressed: widget.state.logoutBusy || widget.state.profileSaving
                  ? null
                  : widget.state.logout,
              child: Text(
                widget.state.logoutBusy ? 'Выходим…' : 'Выйти из аккаунта',
              ),
            ),
          ),
          if (widget.state.logoutError != null) ...[
            const SizedBox(height: 8),
            Text(
              widget.state.logoutError!,
              style: const TextStyle(color: GcColors.danger),
            ),
          ],
        ],
      ),
    );
  }
}
