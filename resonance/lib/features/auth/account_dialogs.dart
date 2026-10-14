import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/app/providers.dart';
import 'package:resonance/features/auth/account_controller.dart';
import 'package:resonance/features/auth/account_models.dart';
import 'package:resonance/shared/theme/resonance_theme.dart';

const _minPasswordLength = 10;

String _errorText(Object error) => error is AccountApiException
    ? error.message
    : 'Не удалось выполнить запрос. Попробуйте ещё раз.';

TextField _codeField(TextEditingController controller, {Key? key}) => TextField(
  key: key,
  controller: controller,
  keyboardType: TextInputType.number,
  autofillHints: const [AutofillHints.oneTimeCode],
  maxLength: 6,
  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
  decoration: const InputDecoration(
    labelText: 'Код из письма',
    prefixIcon: Icon(Icons.pin_rounded),
    counterText: '',
  ),
);

Widget _errorLine(String? message) => message == null
    ? const SizedBox.shrink()
    : Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Text(
          message,
          style: const TextStyle(color: ResonanceColors.primary),
        ),
      );

Future<void> showPasswordResetDialog(BuildContext context, String email) =>
    showDialog<void>(
      context: context,
      builder: (_) => _PasswordResetDialog(initialEmail: email),
    );

Future<void> showChangePasswordDialog(BuildContext context) => showDialog<void>(
  context: context,
  builder: (_) => const _ChangePasswordDialog(),
);

Future<void> showVerifyEmailDialog(BuildContext context, String email) =>
    showDialog<void>(
      context: context,
      builder: (_) => _VerifyEmailDialog(email: email),
    );

class _PasswordResetDialog extends ConsumerStatefulWidget {
  const _PasswordResetDialog({required this.initialEmail});

  final String initialEmail;

  @override
  ConsumerState<_PasswordResetDialog> createState() =>
      _PasswordResetDialogState();
}

class _PasswordResetDialogState extends ConsumerState<_PasswordResetDialog> {
  late final _email = TextEditingController(text: widget.initialEmail.trim());
  final _code = TextEditingController();
  final _password = TextEditingController();
  bool _codeSent = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (!_email.text.contains('@')) {
      setState(() => _error = 'Укажите почту аккаунта.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(accountApiProvider).requestPasswordReset(_email.text);
      if (mounted) setState(() => _codeSent = true);
    } on Object catch (error) {
      if (mounted) setState(() => _error = _errorText(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    if (_code.text.length != 6) {
      setState(() => _error = 'Введите 6-значный код из письма.');
      return;
    }
    if (_password.text.length < _minPasswordLength) {
      setState(() => _error = 'Пароль должен содержать не меньше 10 символов.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final controller = ref.read(accountControllerProvider.notifier);
    await controller.resetPassword(_email.text, _code.text, _password.text);
    if (!mounted) return;
    final result = ref.read(accountControllerProvider);
    if (result.hasError) {
      setState(() {
        _busy = false;
        _error = _errorText(result.error!);
      });
      return;
    }
    Navigator.of(context).pop();
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(content: Text('Пароль изменён, вы вошли в аккаунт.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Сброс пароля'),
      content: SizedBox(
        width: 380,
        child: AutofillGroup(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _codeSent
                    ? 'Если аккаунт с этой почтой существует, мы отправили на неё код. Он действует 15 минут — проверьте и папку «Спам».'
                    : 'Отправим 6-значный код на почту аккаунта.',
                style: const TextStyle(color: ResonanceColors.muted),
              ),
              const SizedBox(height: 16),
              TextField(
                key: const ValueKey('reset-email'),
                controller: _email,
                enabled: !_codeSent,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(
                  labelText: 'Электронная почта',
                  prefixIcon: Icon(Icons.alternate_email_rounded),
                ),
              ),
              if (_codeSent) ...[
                const SizedBox(height: 12),
                _codeField(_code, key: const ValueKey('reset-code')),
                const SizedBox(height: 12),
                TextField(
                  key: const ValueKey('reset-password'),
                  controller: _password,
                  obscureText: true,
                  autofillHints: const [AutofillHints.newPassword],
                  onSubmitted: (_) => _reset(),
                  decoration: const InputDecoration(
                    labelText: 'Новый пароль',
                    helperText: 'Не меньше 10 символов',
                    prefixIcon: Icon(Icons.lock_reset_rounded),
                  ),
                ),
              ],
              _errorLine(_error),
            ],
          ),
        ),
      ),
      actions: [
        if (_codeSent)
          TextButton(
            onPressed: _busy ? null : _sendCode,
            child: const Text('Отправить ещё раз'),
          )
        else
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Отмена'),
          ),
        FilledButton(
          key: const ValueKey('reset-submit'),
          onPressed: _busy ? null : (_codeSent ? _reset : _sendCode),
          child: Text(_codeSent ? 'Сменить пароль' : 'Получить код'),
        ),
      ],
    );
  }
}

class _ChangePasswordDialog extends ConsumerStatefulWidget {
  const _ChangePasswordDialog();

  @override
  ConsumerState<_ChangePasswordDialog> createState() =>
      _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends ConsumerState<_ChangePasswordDialog> {
  final _current = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_password.text.length < _minPasswordLength) {
      setState(() => _error = 'Пароль должен содержать не меньше 10 символов.');
      return;
    }
    if (_password.text != _confirmation.text) {
      setState(() => _error = 'Пароли не совпадают.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(accountControllerProvider.notifier)
          .changePassword(_current.text, _password.text);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text(
            'Пароль изменён. Остальные устройства вышли из аккаунта.',
          ),
        ),
      );
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = _errorText(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Смена пароля'),
      content: SizedBox(
        width: 380,
        child: AutofillGroup(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                key: const ValueKey('change-current'),
                controller: _current,
                obscureText: true,
                autofillHints: const [AutofillHints.password],
                decoration: const InputDecoration(
                  labelText: 'Текущий пароль',
                  prefixIcon: Icon(Icons.lock_outline_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('change-password'),
                controller: _password,
                obscureText: true,
                autofillHints: const [AutofillHints.newPassword],
                decoration: const InputDecoration(
                  labelText: 'Новый пароль',
                  helperText: 'Не меньше 10 символов',
                  prefixIcon: Icon(Icons.lock_reset_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('change-confirmation'),
                controller: _confirmation,
                obscureText: true,
                autofillHints: const [AutofillHints.newPassword],
                onSubmitted: (_) => _submit(),
                decoration: const InputDecoration(
                  labelText: 'Повторите новый пароль',
                  prefixIcon: Icon(Icons.lock_reset_rounded),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Остальные устройства выйдут из аккаунта, на почту придёт уведомление.',
                style: TextStyle(color: ResonanceColors.muted, fontSize: 13),
              ),
              _errorLine(_error),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(
          key: const ValueKey('change-submit'),
          onPressed: _busy ? null : _submit,
          child: const Text('Сменить пароль'),
        ),
      ],
    );
  }
}

class _VerifyEmailDialog extends ConsumerStatefulWidget {
  const _VerifyEmailDialog({required this.email});

  final String email;

  @override
  ConsumerState<_VerifyEmailDialog> createState() => _VerifyEmailDialogState();
}

class _VerifyEmailDialogState extends ConsumerState<_VerifyEmailDialog> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;
  String? _notice;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _resend() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(accountApiProvider).sendEmailVerification();
      if (mounted) setState(() => _notice = 'Новый код отправлен.');
    } on Object catch (error) {
      if (mounted) setState(() => _error = _errorText(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    if (_code.text.length != 6) {
      setState(() => _error = 'Введите 6-значный код из письма.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(accountControllerProvider.notifier)
          .verifyEmail(_code.text);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(const SnackBar(content: Text('Почта подтверждена.')));
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = _errorText(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Подтверждение почты'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Нажмите «Отправить код» — мы пришлём 6-значный код на ${widget.email}. Если код уже пришёл после регистрации, просто введите его.',
              style: const TextStyle(color: ResonanceColors.muted),
            ),
            const SizedBox(height: 16),
            _codeField(_code, key: const ValueKey('verify-code')),
            if (_notice != null && _error == null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _notice!,
                  style: const TextStyle(color: ResonanceColors.success),
                ),
              ),
            _errorLine(_error),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : _resend,
          child: const Text('Отправить код'),
        ),
        FilledButton(
          key: const ValueKey('verify-submit'),
          onPressed: _busy ? null : _verify,
          child: const Text('Подтвердить'),
        ),
      ],
    );
  }
}
