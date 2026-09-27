import 'package:flutter/material.dart';

import '../app_state.dart';
import '../theme.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.state});
  final AppState state;
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _login = TextEditingController();
  final _password = TextEditingController();
  final _loginFocus = FocusNode(debugLabel: 'auth-login');
  final _passwordFocus = FocusNode(debugLabel: 'auth-password');
  bool _register = false;
  bool _pending = false;
  late final bool _focusLogin;

  @override
  void initState() {
    super.initState();
    _focusLogin = widget.state.focusLoginOnMount;
    widget.state.focusLoginOnMount = false;
  }

  @override
  void dispose() {
    _login.dispose();
    _password.dispose();
    _loginFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _pending = true);
    try {
      await widget.state.authenticate(
        _login.text,
        _password.text,
        register: _register,
      );
    } catch (_) {
      if (mounted) setState(() => _pending = false);
    }
  }

  Future<void> _usePasswordResetLink() async {
    final controller = TextEditingController();
    final link = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: GcColors.surface,
        title: const Text('Ссылка для сброса пароля'),
        content: SizedBox(
          width: 460,
          child: TextField(
            controller: controller,
            autofocus: true,
            obscureText: true,
            maxLength: 512,
            enableIMEPersonalizedLearning: false,
            decoration: const InputDecoration(
              labelText: 'Одноразовая ссылка администратора',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Продолжить'),
          ),
        ],
      ),
    );
    controller.clear();
    controller.dispose();
    if (!mounted || link == null) return;
    widget.state.openPasswordResetLink(link);
  }

  Future<void> _changeServer() async {
    final controller = TextEditingController(
      text: widget.state.serverUrl.replaceFirst(RegExp(r'/api/v1$'), ''),
    );
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: GcColors.surface,
        title: const Text('Сервер гильдии'),
        content: SizedBox(
          width: 460,
          child: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'HTTPS-адрес',
              hintText: 'https://guild.example.com',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value.isEmpty) return;
    try {
      await widget.state.setServer(value);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(
      children: [
        Positioned.fill(child: CustomPaint(painter: _GridPainter())),
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Container(
              width: 460,
              padding: const EdgeInsets.all(36),
              decoration: BoxDecoration(
                color: GcColors.sidebar,
                border: Border.all(color: GcColors.border),
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black38,
                    blurRadius: 50,
                    offset: Offset(0, 20),
                  ),
                ],
              ),
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Row(
                        children: [
                          _AuthMark(),
                          SizedBox(width: 14),
                          Text(
                            'BOOHTACORD',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                              letterSpacing: .5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      Text(
                        _register ? 'Создать аккаунт' : 'С возвращением',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Одна приватная гильдия. Ваши люди, каналы и голос.',
                        style: TextStyle(
                          color: GcColors.textSecondary,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 28),
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(value: false, label: Text('Войти')),
                          ButtonSegment(
                            value: true,
                            label: Text('Регистрация'),
                          ),
                        ],
                        selected: {_register},
                        onSelectionChanged: (value) =>
                            setState(() => _register = value.first),
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        key: const ValueKey('auth-login-field'),
                        controller: _login,
                        focusNode: _loginFocus,
                        autofocus: _focusLogin,
                        keyboardType: TextInputType.text,
                        textCapitalization: TextCapitalization.none,
                        textInputAction: TextInputAction.next,
                        autocorrect: false,
                        enableSuggestions: false,
                        enableIMEPersonalizedLearning: false,
                        autofillHints: const [AutofillHints.username],
                        onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                        decoration: const InputDecoration(
                          labelText: 'Логин',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (value) =>
                            value != null &&
                                RegExp(r'^[A-Za-z0-9_.-]{3,32}$')
                                    .hasMatch(value)
                            ? null
                            : 'От 3 до 32 символов: A–Z, 0–9, _, . или -',
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        key: const ValueKey('auth-password-field'),
                        controller: _password,
                        focusNode: _passwordFocus,
                        obscureText: true,
                        autocorrect: false,
                        enableSuggestions: false,
                        enableIMEPersonalizedLearning: false,
                        autofillHints: [
                          _register
                              ? AutofillHints.newPassword
                              : AutofillHints.password,
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Пароль',
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                        onFieldSubmitted: (_) => _submit(),
                        validator: (value) => (value?.length ?? 0) >= 12
                            ? null
                            : 'Пароль должен содержать не менее 12 символов',
                      ),
                      if (widget.state.error != null) ...[
                        const SizedBox(height: 14),
                        Text(
                          widget.state.error!,
                          style: const TextStyle(color: GcColors.danger),
                        ),
                      ],
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: _pending ? null : _submit,
                        icon: _pending
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.arrow_forward),
                        label: Text(
                          _pending
                              ? 'Подождите…'
                              : _register
                              ? 'Создать аккаунт'
                              : 'Войти',
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextButton.icon(
                        onPressed: _pending ? null : _usePasswordResetLink,
                        icon: const Icon(Icons.password_outlined, size: 18),
                        label: const Text('Есть ссылка для сброса пароля?'),
                      ),
                      TextButton.icon(
                        onPressed: _pending ? null : _changeServer,
                        icon: const Icon(Icons.dns_outlined, size: 18),
                        label: Text(
                          widget.state.serverUrl,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _AuthMark extends StatelessWidget {
  const _AuthMark();
  @override
  Widget build(BuildContext context) => Container(
    width: 42,
    height: 42,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: GcColors.accent,
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Text(
      'B',
      style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
    ),
  );
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = GcColors.border.withValues(alpha: .32)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 48) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 48) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
