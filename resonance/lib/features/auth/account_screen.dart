import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/features/auth/account_controller.dart';
import 'package:resonance/features/auth/account_models.dart';
import 'package:resonance/shared/theme/resonance_theme.dart';

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();
  bool _registering = false;
  bool _obscure = true;
  String? _validationMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (!email.contains('@')) {
      setState(() => _validationMessage = 'Укажите корректную почту.');
      return;
    }
    if (password.length < 10) {
      setState(
        () => _validationMessage =
            'Пароль должен содержать не меньше 10 символов.',
      );
      return;
    }
    if (_registering && password != _confirmationController.text) {
      setState(() => _validationMessage = 'Пароли не совпадают.');
      return;
    }
    setState(() => _validationMessage = null);
    final controller = ref.read(accountControllerProvider.notifier);
    if (_registering) {
      await controller.register(email, password);
    } else {
      await controller.login(email, password);
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(accountControllerProvider);
    final compact = MediaQuery.sizeOf(context).width < 650;
    return ListView(
      padding: EdgeInsets.fromLTRB(
        compact ? 18 : 34,
        26,
        compact ? 18 : 34,
        130,
      ),
      children: [
        Text(
          'Аккаунт Resonance',
          style: Theme.of(context).textTheme.displaySmall,
        ),
        const SizedBox(height: 8),
        const Text(
          'Синхронизируйте избранное и плейлисты между своими устройствами.',
          style: TextStyle(color: ResonanceColors.muted),
        ),
        const SizedBox(height: 22),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: account.when(
            loading: () => const Card(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
            error: (error, _) => _AccountForm(
              emailController: _emailController,
              passwordController: _passwordController,
              confirmationController: _confirmationController,
              registering: _registering,
              obscure: _obscure,
              message: error is AccountApiException
                  ? error.message
                  : 'Не удалось подключиться к аккаунту.',
              onToggleMode: _toggleMode,
              onToggleObscure: () => setState(() => _obscure = !_obscure),
              onSubmit: _submit,
            ),
            data: (user) => user == null
                ? _AccountForm(
                    emailController: _emailController,
                    passwordController: _passwordController,
                    confirmationController: _confirmationController,
                    registering: _registering,
                    obscure: _obscure,
                    message: _validationMessage,
                    onToggleMode: _toggleMode,
                    onToggleObscure: () => setState(() => _obscure = !_obscure),
                    onSubmit: _submit,
                  )
                : _ConnectedAccount(user: user),
          ),
        ),
      ],
    );
  }

  void _toggleMode() {
    setState(() {
      _registering = !_registering;
      _validationMessage = null;
      _confirmationController.clear();
    });
  }
}

class _AccountForm extends StatelessWidget {
  const _AccountForm({
    required this.emailController,
    required this.passwordController,
    required this.confirmationController,
    required this.registering,
    required this.obscure,
    required this.onToggleMode,
    required this.onToggleObscure,
    required this.onSubmit,
    this.message,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController confirmationController;
  final bool registering;
  final bool obscure;
  final String? message;
  final VoidCallback onToggleMode;
  final VoidCallback onToggleObscure;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: AutofillGroup(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                registering
                    ? Icons.person_add_alt_1_rounded
                    : Icons.cloud_sync_rounded,
                size: 42,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 14),
              Text(
                registering ? 'Создать аккаунт' : 'Войти в Resonance',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 20),
              TextField(
                key: const ValueKey('account-email'),
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(
                  labelText: 'Электронная почта',
                  prefixIcon: Icon(Icons.alternate_email_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('account-password'),
                controller: passwordController,
                obscureText: obscure,
                autofillHints: [
                  registering
                      ? AutofillHints.newPassword
                      : AutofillHints.password,
                ],
                onSubmitted: (_) {
                  if (!registering) onSubmit();
                },
                decoration: InputDecoration(
                  labelText: 'Пароль',
                  helperText: registering ? 'Не меньше 10 символов' : null,
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    onPressed: onToggleObscure,
                    icon: Icon(
                      obscure
                          ? Icons.visibility_rounded
                          : Icons.visibility_off_rounded,
                    ),
                  ),
                ),
              ),
              if (registering) ...[
                const SizedBox(height: 12),
                TextField(
                  key: const ValueKey('account-password-confirmation'),
                  controller: confirmationController,
                  obscureText: obscure,
                  autofillHints: const [AutofillHints.newPassword],
                  onSubmitted: (_) => onSubmit(),
                  decoration: const InputDecoration(
                    labelText: 'Повторите пароль',
                    prefixIcon: Icon(Icons.lock_reset_rounded),
                  ),
                ),
              ],
              if (message != null) ...[
                const SizedBox(height: 12),
                Text(
                  message!,
                  style: const TextStyle(color: ResonanceColors.primary),
                ),
              ],
              const SizedBox(height: 18),
              FilledButton.icon(
                key: const ValueKey('account-submit'),
                onPressed: onSubmit,
                icon: Icon(
                  registering ? Icons.person_add_rounded : Icons.login_rounded,
                ),
                label: Text(registering ? 'Создать аккаунт' : 'Войти'),
              ),
              TextButton(
                onPressed: onToggleMode,
                child: Text(
                  registering
                      ? 'У меня уже есть аккаунт'
                      : 'Создать новый аккаунт',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConnectedAccount extends ConsumerWidget {
  const _ConnectedAccount({required this.user});

  final AccountUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.verified_user_rounded,
              size: 46,
              color: ResonanceColors.success,
            ),
            const SizedBox(height: 14),
            Text(
              user.email,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Избранное и плейлисты синхронизируются с вашим аккаунтом. Локальная медиатека остаётся доступной без сети.',
              textAlign: TextAlign.center,
              style: TextStyle(color: ResonanceColors.muted),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              key: const ValueKey('account-sync'),
              onPressed: () =>
                  ref.read(accountControllerProvider.notifier).synchronize(),
              icon: const Icon(Icons.sync_rounded),
              label: const Text('Синхронизировать сейчас'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const ValueKey('account-logout'),
              onPressed: () =>
                  ref.read(accountControllerProvider.notifier).logout(),
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Выйти на этом устройстве'),
            ),
          ],
        ),
      ),
    );
  }
}
