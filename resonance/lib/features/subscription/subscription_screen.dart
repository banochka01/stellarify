import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:resonance/app/providers.dart';
import 'package:resonance/features/auth/account_controller.dart';
import 'package:resonance/features/subscription/subscription_service.dart';

final subscriptionStatusProvider = FutureProvider<SubscriptionSnapshot>((ref) {
  ref.watch(accountControllerProvider);
  return ref.read(subscriptionServiceProvider).status(force: true);
});

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});
  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  final _promo = TextEditingController();
  final _invitation = TextEditingController();
  bool _busy = false;
  String? _message;
  bool _failed = false;
  List<Map<String, dynamic>> _devices = [];
  List<Map<String, dynamic>> _members = [];
  String? _createdInvitation;
  @override
  void dispose() {
    _promo.dispose();
    _invitation.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action, {String? success}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
      _failed = false;
    });
    try {
      await action();
      ref.read(subscriptionServiceProvider).invalidate();
      ref.invalidate(subscriptionStatusProvider);
      if (mounted) setState(() => _message = success);
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _failed = true;
          _message = error is SubscriptionException
              ? error.message
              : 'Не удалось выполнить действие. Проверьте подключение и вход в аккаунт.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loadManagement() async {
    final service = ref.read(subscriptionServiceProvider);
    final devices = await service.request('GET', '/devices');
    final family = await service.request('GET', '/family');
    if (mounted) {
      setState(() {
        _devices = (devices['devices'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _members = (family['members'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(subscriptionStatusProvider);
    final account = ref.watch(accountControllerProvider).valueOrNull;
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Подписка', style: theme.textTheme.headlineLarge),
              const SizedBox(height: 8),
              const Text(
                'Твоя музыка. Собственный плеер Resonance. Доступ на оплаченный срок, без автоматических списаний.',
              ),
              const SizedBox(height: 24),
              status.when(
                loading: () => const LinearProgressIndicator(),
                error: (error, stack) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Text(
                          'Не удалось проверить доступ. Данные не заменены новым пробным периодом.',
                        ),
                        TextButton(
                          onPressed: () =>
                              ref.invalidate(subscriptionStatusProvider),
                          child: const Text('Повторить'),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (value) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(value.label, style: theme.textTheme.headlineSmall),
                        const SizedBox(height: 8),
                        Text(
                          value.expiresAt == null
                              ? 'Войдите в аккаунт и активируйте оплаченный промокод.'
                              : 'Доступ до ${_date(value.expiresAt!)} · до ${value.deviceLimit} устройств',
                        ),
                        if (value.tier == 'guest')
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text(
                              'Пробные сутки: только SoundCloud, поиск и до трёх подборок Wave. Регистрация не запускает срок заново.',
                            ),
                          ),
                        for (final period in value.scheduled)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'Далее: ${period['plan']} · ${_date(DateTime.parse(period['startsAt'] as String))} — ${_date(DateTime.parse(period['expiresAt'] as String))}',
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, constraints) => Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    for (final plan in const [
                      (
                        'Base',
                        'Личная коллекция',
                        'SoundCloud + Яндекс\nОблачная медиатека\nОбычная Wave\nВход в комнаты\n2 устройства',
                      ),
                      (
                        'Plus',
                        'Больше возможностей',
                        'Всё из Base\nWave обычным языком\nМузыкальная память и продолжение\nОбщая Wave в комнатах\nДо 10 устройств',
                      ),
                      (
                        'Family',
                        'До пяти человек',
                        'Все возможности Plus\nВладелец + 4 участника\nОтдельные аккаунты\nЛичные медиатеки\nДо 10 устройств на человека',
                      ),
                    ])
                      SizedBox(
                        width: constraints.maxWidth >= 800
                            ? (constraints.maxWidth - 32) / 3
                            : constraints.maxWidth,
                        child: Card(
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  plan.$1,
                                  style: theme.textTheme.headlineSmall,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  plan.$2,
                                  style: theme.textTheme.titleMedium,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  plan.$3,
                                  style: const TextStyle(height: 1.7),
                                ),
                                const SizedBox(height: 16),
                                const Text('Срок определяется промокодом'),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Активировать промокод',
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Код выдаёт администратор через Telegram-бота после оплаты. В приложении нет покупки или автоматического подтверждения оплаты.',
                      ),
                      const SizedBox(height: 16),
                      if (account == null)
                        FilledButton(
                          onPressed: () => context.go('/account'),
                          child: const Text('Войти для активации'),
                        )
                      else ...[
                        TextField(
                          key: const ValueKey('subscription-promo'),
                          controller: _promo,
                          enabled: !_busy,
                          autocorrect: false,
                          enableSuggestions: false,
                          maxLength: 100,
                          decoration: const InputDecoration(
                            labelText: 'Оплаченный промокод',
                            hintText: 'RSN-…',
                            border: OutlineInputBorder(),
                          ),
                          onSubmitted: (_) => _redeem(),
                        ),
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          key: const ValueKey('subscription-redeem'),
                          onPressed: _busy ? null : _redeem,
                          icon: const Icon(Icons.key_rounded),
                          label: Text(_busy ? 'Проверяем…' : 'Активировать'),
                        ),
                      ],
                      if (_message != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Semantics(
                            liveRegion: true,
                            child: Text(
                              _message!,
                              style: TextStyle(
                                color: _failed
                                    ? theme.colorScheme.error
                                    : theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (account != null) ...[
                const SizedBox(height: 24),
                ExpansionTile(
                  title: const Text('Семейная группа и устройства'),
                  onExpansionChanged: (open) {
                    if (open) _run(_loadManagement);
                  },
                  childrenPadding: const EdgeInsets.all(16),
                  children: [
                    if (status.valueOrNull?.allows('family.manage') ==
                        true) ...[
                      const Text(
                        'Создайте одноразовое приглашение на 24 часа. Новое приглашение отменяет предыдущее. Медиатеки участников не объединяются.',
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: _busy
                            ? null
                            : () => _run(() async {
                                final data = await ref
                                    .read(subscriptionServiceProvider)
                                    .request('POST', '/family/invite');
                                if (mounted) {
                                  setState(
                                    () => _createdInvitation =
                                        data['invitation'] as String,
                                  );
                                }
                              }),
                        child: const Text('Создать приглашение'),
                      ),
                      if (_createdInvitation != null)
                        Row(
                          children: [
                            Expanded(
                              child: SelectableText(_createdInvitation!),
                            ),
                            IconButton(
                              tooltip: 'Копировать приглашение',
                              onPressed: () => Clipboard.setData(
                                ClipboardData(text: _createdInvitation!),
                              ),
                              icon: const Icon(Icons.copy_rounded),
                            ),
                          ],
                        ),
                      for (final member in _members)
                        ListTile(
                          title: Text('Участник ${member['id']}'),
                          trailing: IconButton(
                            tooltip: 'Удалить участника',
                            onPressed: _busy
                                ? null
                                : () => _run(() async {
                                    await ref
                                        .read(subscriptionServiceProvider)
                                        .request(
                                          'DELETE',
                                          '/family/${member['id']}',
                                        );
                                    await _loadManagement();
                                  }),
                            icon: const Icon(Icons.person_remove_outlined),
                          ),
                        ),
                    ] else if (status.valueOrNull?.familyOwnerId != null)
                      OutlinedButton(
                        onPressed: _busy
                            ? null
                            : () => _run(() async {
                                await ref
                                    .read(subscriptionServiceProvider)
                                    .request('DELETE', '/family/${account.id}');
                              }, success: 'Вы вышли из семейной группы.'),
                        child: const Text('Выйти из семейной группы'),
                      )
                    else ...[
                      TextField(
                        controller: _invitation,
                        enabled: !_busy,
                        decoration: const InputDecoration(
                          labelText: 'Семейное приглашение (не промокод)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: _busy
                            ? null
                            : () => _run(() async {
                                await ref
                                    .read(subscriptionServiceProvider)
                                    .request(
                                      'POST',
                                      '/family/join',
                                      data: {
                                        'invitation': _invitation.text.trim(),
                                      },
                                    );
                                _invitation.clear();
                              }, success: 'Вы вступили в семейную группу.'),
                        child: const Text('Принять приглашение'),
                      ),
                    ],
                    const Divider(height: 32),
                    const Text(
                      'Устройства, использовавшие подписку за последние 30 дней',
                    ),
                    for (final device in _devices)
                      ListTile(
                        title: Text(
                          'Устройство ${device['id'].toString().substring(0, 8)}',
                        ),
                        subtitle: Text(
                          'Активность: ${_date(DateTime.fromMillisecondsSinceEpoch(device['lastSeenAt'] as int))}',
                        ),
                        trailing: IconButton(
                          tooltip: 'Освободить место устройства',
                          onPressed: _busy
                              ? null
                              : () => _run(() async {
                                  await ref
                                      .read(subscriptionServiceProvider)
                                      .request(
                                        'DELETE',
                                        '/devices/${device['id']}',
                                      );
                                  await _loadManagement();
                                }),
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              const Text(
                'Подписка Resonance не заменяет доступ у музыкального источника. Качество зависит от источника. Скачивание, офлайн-кэш и сторонние плееры не предоставляются. После окончания срока медиатека сохраняется, воспроизведение и облачная синхронизация приостанавливаются.',
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _redeem() => _run(() async {
    if (_promo.text.trim().length < 20) {
      throw const SubscriptionException('Введите полный промокод.');
    }
    await ref.read(subscriptionServiceProvider).redeem(_promo.text);
    _promo.clear();
  }, success: 'Промокод активирован. Доступ обновлён.');

  String _date(DateTime date) {
    final d = date.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}.${two(d.month)}.${d.year} ${two(d.hour)}:${two(d.minute)}';
  }
}
