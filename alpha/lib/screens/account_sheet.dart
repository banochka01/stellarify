import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/features/auth/account_controller.dart';
import 'package:resonance_alpha/design/tokens.dart';
import 'package:resonance_alpha/design/widgets.dart';
import 'package:resonance_alpha/state.dart';

Future<void> showAccountSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    useRootNavigator: true,
    context: context,
    backgroundColor: Pal.raised,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (_) => const _AccountSheet(),
  );
}

class _AccountSheet extends ConsumerStatefulWidget {
  const _AccountSheet();

  @override
  ConsumerState<_AccountSheet> createState() => _AccountSheetState();
}

class _AccountSheetState extends ConsumerState<_AccountSheet> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();
  bool _register = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.length < 8) {
      setState(() => _error = 'Нужны почта и пароль от 8 символов');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final account = ref.read(accountControllerProvider.notifier);
    if (_register) {
      await account.register(email, password);
    } else {
      await account.login(email, password);
    }
    if (!mounted) return;
    final state = ref.read(accountControllerProvider);
    setState(() {
      _busy = false;
      _error = state.hasError ? _reason(state.error) : null;
    });
  }

  Future<void> _verify() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(accountControllerProvider.notifier)
          .verifyEmail(_code.text.trim());
      if (mounted) setState(() => _error = null);
    } on Object catch (error) {
      if (mounted) setState(() => _error = _reason(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _reason(Object? error) {
    final text = '$error';
    final colon = text.indexOf(': ');
    return colon > 0 && colon < 40 ? text.substring(colon + 2) : text;
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(accountControllerProvider).valueOrNull;
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(28, 0, 28, 28 + inset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: user != null
            ? [
                Text('АККАУНТ', style: Txt.mono(12)),
                const SizedBox(height: 10),
                Text(user.email, style: Txt.title(24)),
                const SizedBox(height: 8),
                Text(
                  'Лайки и плейлисты синхронизируются с основным '
                  'приложением Resonance.',
                  style: Txt.body(14, color: Pal.muted),
                ),
                if (!user.emailVerified) ...[
                  const SizedBox(height: 20),
                  Text(
                    'Почта не подтверждена — введи код из письма.',
                    style: Txt.body(14),
                  ),
                  _Field(controller: _code, hint: 'Код', number: true),
                  const SizedBox(height: 10),
                  Pill(
                    label: 'Подтвердить',
                    active: true,
                    onTap: _busy ? null : _verify,
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: Txt.body(14, color: Pal.acid)),
                ],
                const SizedBox(height: 24),
                Wrap(
                  spacing: 10,
                  children: [
                    Pill(
                      label: 'Синхронизировать',
                      icon: Icons.sync_rounded,
                      onTap: () => run(
                        context,
                        ref
                            .read(accountControllerProvider.notifier)
                            .synchronize,
                      ),
                    ),
                    Pill(
                      label: 'Выйти',
                      onTap: () {
                        Navigator.of(context).pop();
                        run(
                          context,
                          ref.read(accountControllerProvider.notifier).logout,
                        );
                      },
                    ),
                  ],
                ),
              ]
            : [
                Text(_register ? 'НОВЫЙ АККАУНТ' : 'ВХОД', style: Txt.mono(12)),
                const SizedBox(height: 10),
                Text(
                  _register ? 'Создать\nаккаунт' : 'С возвращением',
                  style: Txt.display(40),
                ),
                const SizedBox(height: 24),
                _Field(controller: _email, hint: 'Почта', email: true),
                _Field(
                  controller: _password,
                  hint: 'Пароль',
                  secret: true,
                  onSubmit: _submit,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: Txt.body(14, color: Pal.acid)),
                ],
                const SizedBox(height: 22),
                Row(
                  children: [
                    Pill(
                      large: true,
                      active: true,
                      label: _busy
                          ? 'Секунду…'
                          : (_register ? 'Создать' : 'Войти'),
                      onTap: _busy ? null : _submit,
                    ),
                    const SizedBox(width: 16),
                    Press(
                      onTap: () => setState(() {
                        _register = !_register;
                        _error = null;
                      }),
                      child: Text(
                        _register ? 'Уже есть аккаунт' : 'Нет аккаунта?',
                        style: Txt.body(14, color: Pal.muted, weight: 650),
                      ),
                    ),
                  ],
                ),
              ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.hint,
    this.secret = false,
    this.email = false,
    this.number = false,
    this.onSubmit,
  });

  final TextEditingController controller;
  final String hint;
  final bool secret;
  final bool email;
  final bool number;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: TextField(
        controller: controller,
        obscureText: secret,
        keyboardType: email
            ? TextInputType.emailAddress
            : (number ? TextInputType.number : TextInputType.text),
        autofillHints: email
            ? const [AutofillHints.email]
            : (secret ? const [AutofillHints.password] : null),
        onSubmitted: onSubmit == null ? null : (_) => onSubmit!(),
        style: Txt.body(17, weight: 600),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: Txt.body(17, color: Pal.faint, weight: 600),
          filled: true,
          fillColor: Pal.stage,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 18,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}
