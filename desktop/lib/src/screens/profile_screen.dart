import 'package:flutter/material.dart';

import '../app_state.dart';
import '../theme.dart';

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
    if (await widget.state.saveDisplayName(_displayName.text)) {
      setState(() => _status = 'Имя профиля сохранено.');
    }
  }

  Future<void> _savePassword() async {
    if (await widget.state.updatePassword(
      _currentPassword.text,
      _newPassword.text,
    )) {
      _currentPassword.clear();
      _newPassword.clear();
      setState(() => _status = 'Пароль изменён. Другие сессии завершены.');
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
            const Center(child: CircularProgressIndicator())
          else if (profile != null) ...[
            Row(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: const Color(0xFF365ACA),
                  child: Text(
                    profile.displayName.characters.first.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                OutlinedButton(
                  onPressed: null,
                  child: const Text('Загрузить аватар'),
                ),
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
        ],
      ),
    );
  }
}
