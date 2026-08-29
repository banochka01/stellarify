import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:resonance/app/providers.dart';
import 'package:resonance/core/errors/app_exception.dart';
import 'package:resonance/core/networking/backend_endpoint.dart';
import 'package:resonance/core/playback/audio_output_controller.dart';
import 'package:resonance/core/playback/playback_engine.dart';
import 'package:resonance/core/preferences/appearance_preferences.dart';
import 'package:resonance/core/update/app_update_service.dart';
import 'package:resonance/domain/entities/music_enums.dart';
import 'package:resonance/features/auth/account_controller.dart';
import 'package:resonance/shared/theme/resonance_theme.dart';
import 'package:resonance/shared/widgets/provider_badges.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _yandexTokenController = TextEditingController();
  final _soundCloudTokenController = TextEditingController();
  final _youtubeTokenController = TextEditingController();
  final _apiController = TextEditingController();
  final _hasToken = <MusicProvider, bool>{
    MusicProvider.yandex: false,
    MusicProvider.soundcloud: false,
    MusicProvider.youtube: false,
  };
  final _obscureToken = <MusicProvider, bool>{
    MusicProvider.yandex: true,
    MusicProvider.soundcloud: true,
    MusicProvider.youtube: true,
  };
  final _tokenMessages = <MusicProvider, String>{};
  final _serverCredential = <MusicProvider, bool>{};
  MusicProvider? _savingProvider;
  bool _proxyEnabled = false;
  bool _savingProxy = false;
  String? _proxyMessage;
  String? _apiMessage;
  AppUpdate? _availableUpdate;
  String _installedVersion = '…';
  String _updateMessage = 'Проверяем версию…';
  bool _checkingUpdate = true;
  AudioQuality _quality = AudioQuality.high;
  bool _savingQuality = false;

  @override
  void initState() {
    super.initState();
    _apiController.text = BackendEndpoint.displayValue;
    _loadStatus();
    _checkUpdate();
  }

  @override
  void dispose() {
    _yandexTokenController.dispose();
    _soundCloudTokenController.dispose();
    _youtubeTokenController.dispose();
    _apiController.dispose();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    final repository = ref.read(secureTokenRepositoryProvider);
    final tokens = await Future.wait<String?>([
      repository.read(MusicProvider.yandex),
      repository.read(MusicProvider.soundcloud),
      repository.read(MusicProvider.youtube),
    ]);
    final proxyEnabled = await ref
        .read(soundCloudProxyPreferenceProvider)
        .read();
    final onboarding = await ref.read(onboardingPreferencesProvider).read();
    Map<MusicProvider, bool> serverCredentials = const {};
    try {
      serverCredentials = await ref
          .read(resonanceBackendClientProvider)
          .serverCredentialStatus();
    } on AppException {
      // Settings remain usable offline; status will show that no server key was detected.
    }
    if (!mounted) return;
    setState(() {
      _hasToken[MusicProvider.yandex] = tokens[0]?.isNotEmpty == true;
      _hasToken[MusicProvider.soundcloud] = tokens[1]?.isNotEmpty == true;
      _hasToken[MusicProvider.youtube] = tokens[2]?.isNotEmpty == true;
      _serverCredential.addAll(serverCredentials);
      _proxyEnabled = proxyEnabled;
      _quality = onboarding.quality;
    });
  }

  Future<void> _checkUpdate() async {
    if (mounted) setState(() => _checkingUpdate = true);
    try {
      final package = await PackageInfo.fromPlatform();
      final update = await ref.read(appUpdateServiceProvider).check();
      if (!mounted) return;
      setState(() {
        _installedVersion = package.version;
        _availableUpdate = update;
        _updateMessage = update == null
            ? 'У вас установлена последняя версия'
            : 'Доступна версия ${update.latestVersion}';
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _updateMessage = 'Не удалось проверить обновления';
      });
    } finally {
      if (mounted) setState(() => _checkingUpdate = false);
    }
  }

  Future<void> _saveToken(
    MusicProvider provider,
    TextEditingController controller,
  ) async {
    final value = controller.text.trim();
    if (value.isEmpty) {
      setState(() {
        _tokenMessages[provider] = 'Вставьте ${_credentialName(provider)}.';
      });
      return;
    }
    setState(() {
      _savingProvider = provider;
      _tokenMessages.remove(provider);
    });
    try {
      await ref
          .read(resonanceBackendClientProvider)
          .validateProvider(
            provider: provider,
            token: value,
            useProxy: _proxyEnabled,
          );
      await ref.read(secureTokenRepositoryProvider).write(provider, value);
      controller.clear();
      if (!mounted) return;
      setState(() {
        _hasToken[provider] = true;
        _tokenMessages[provider] =
            '${_credentialName(provider)} проверен и подключён.';
      });
    } on AppException catch (error) {
      if (!mounted) return;
      setState(() => _tokenMessages[provider] = error.message);
    } finally {
      if (mounted) setState(() => _savingProvider = null);
    }
  }

  Future<void> _setProxy(bool enabled) async {
    setState(() {
      _savingProxy = true;
      _proxyMessage = null;
    });
    try {
      await ref.read(soundCloudProxyPreferenceProvider).write(enabled);
      if (!mounted) return;
      setState(() {
        _proxyEnabled = enabled;
        _proxyMessage = enabled
            ? 'Каталог и progressive-аудио SoundCloud пойдут через серверный прокси.'
            : 'SoundCloud будет запрашиваться напрямую с сервера.';
      });
    } finally {
      if (mounted) setState(() => _savingProxy = false);
    }
  }

  Future<void> _removeToken(MusicProvider provider) async {
    await ref.read(secureTokenRepositoryProvider).delete(provider);
    if (!mounted) return;
    setState(() {
      _hasToken[provider] = false;
      _tokenMessages[provider] = _serverCredential[provider] == true
          ? 'Собственный ключ удалён. Используется серверный.'
          : 'Собственный ключ удалён; серверный пока не настроен.';
    });
  }

  Future<void> _setQuality(AudioQuality quality) async {
    if (_savingQuality) return;
    setState(() {
      _quality = quality;
      _savingQuality = true;
    });
    try {
      await ref.read(onboardingPreferencesProvider).setQuality(quality);
      final playback = await ref.read(playbackServiceProvider.future);
      playback.setQuality(quality);
    } finally {
      if (mounted) setState(() => _savingQuality = false);
    }
  }

  String _providerName(MusicProvider provider) => switch (provider) {
    MusicProvider.yandex => 'Яндекс Музыка',
    MusicProvider.soundcloud => 'SoundCloud',
    MusicProvider.youtube => 'YouTube Music',
  };

  String _credentialName(MusicProvider provider) => switch (provider) {
    MusicProvider.yandex => 'OAuth-токен Яндекс Музыки',
    MusicProvider.soundcloud => 'SoundCloud Client ID',
    MusicProvider.youtube => 'YouTube Data API key',
  };

  String _qualityName(AudioQuality quality) => switch (quality) {
    AudioQuality.low => 'Экономия · 128',
    AudioQuality.medium => 'Баланс · 192',
    AudioQuality.high => 'Высокое · 320',
    AudioQuality.lossless => 'Лучшее доступное',
  };

  Future<void> _saveApi() async {
    try {
      await BackendEndpoint.save(_apiController.text);
      if (!mounted) return;
      setState(() => _apiMessage = 'Адрес API сохранён.');
    } on FormatException catch (error) {
      setState(() => _apiMessage = error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 650;
    final appearance = ref.watch(appearanceControllerProvider);
    final account = ref.watch(accountControllerProvider);
    final audioOutput = ref.watch(audioOutputControllerProvider);
    return ListView(
      padding: EdgeInsets.fromLTRB(
        compact ? 18 : 34,
        26,
        compact ? 18 : 34,
        130,
      ),
      children: [
        Text('Аккаунт', style: Theme.of(context).textTheme.displaySmall),
        const SizedBox(height: 8),
        const Text(
          'Синхронизация избранного и плейлистов между устройствами.',
          style: TextStyle(color: ResonanceColors.muted),
        ),
        const SizedBox(height: 18),
        Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            leading: Icon(
              account.valueOrNull == null
                  ? Icons.cloud_off_rounded
                  : Icons.cloud_done_rounded,
            ),
            title: Text(account.valueOrNull?.email ?? 'Войти в Resonance'),
            subtitle: Text(
              account.valueOrNull == null
                  ? 'Локальная медиатека работает без аккаунта'
                  : 'Избранное и плейлисты синхронизируются',
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.go('/account'),
          ),
        ),
        const SizedBox(height: 34),
        Text(
          'Воспроизведение',
          style: Theme.of(context).textTheme.displaySmall,
        ),
        const SizedBox(height: 18),
        _AudioOutputCard(
          audioOutput: audioOutput,
          onSelected: (device) => unawaited(
            ref.read(audioOutputControllerProvider.notifier).select(device),
          ),
        ),
        const SizedBox(height: 34),
        Text('Оформление', style: Theme.of(context).textTheme.displaySmall),
        const SizedBox(height: 8),
        const Text(
          'Выберите тему и настройте собственный фон без потери читаемости.',
          style: TextStyle(color: ResonanceColors.muted),
        ),
        const SizedBox(height: 18),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ThemeSelector(
                  compact: compact,
                  selected: appearance.theme,
                  onSelected: (theme) => unawaited(
                    ref
                        .read(appearanceControllerProvider.notifier)
                        .setTheme(theme),
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      onPressed: () => unawaited(
                        ref
                            .read(appearanceControllerProvider.notifier)
                            .chooseBackground(),
                      ),
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: Text(
                        appearance.backgroundPath == null
                            ? 'Выбрать фон'
                            : 'Заменить фон',
                      ),
                    ),
                    if (appearance.backgroundPath != null)
                      OutlinedButton.icon(
                        onPressed: () => unawaited(
                          ref
                              .read(appearanceControllerProvider.notifier)
                              .clearBackground(),
                        ),
                        icon: const Icon(Icons.hide_image_outlined),
                        label: const Text('Убрать фон'),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                _AppearanceSlider(
                  label: 'Размытие',
                  value: appearance.blur,
                  max: 30,
                  valueLabel: '${appearance.blur.round()} px',
                  onChanged: ref
                      .read(appearanceControllerProvider.notifier)
                      .previewBlur,
                  onChangeEnd: (_) => unawaited(
                    ref.read(appearanceControllerProvider.notifier).persist(),
                  ),
                ),
                _AppearanceSlider(
                  label: 'Затемнение',
                  value: appearance.dim,
                  max: .9,
                  valueLabel: '${(appearance.dim * 100).round()}%',
                  onChanged: ref
                      .read(appearanceControllerProvider.notifier)
                      .previewDim,
                  onChangeEnd: (_) => unawaited(
                    ref.read(appearanceControllerProvider.notifier).persist(),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.high_quality_rounded),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Качество воспроизведения',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: AudioQuality.values
                      .map((quality) {
                        return ChoiceChip(
                          label: Text(_qualityName(quality)),
                          selected: _quality == quality,
                          onSelected: _savingQuality
                              ? null
                              : (_) => _setQuality(quality),
                        );
                      })
                      .toList(growable: false),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Применяется к следующему разрешению потока. Уже открытый трек не перезапускается.',
                  style: TextStyle(color: ResonanceColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 34),
        Text('Подключения', style: Theme.of(context).textTheme.displaySmall),
        const SizedBox(height: 8),
        const Text(
          'Пользовательские credentials остаются в защищённом хранилище устройства.',
          style: TextStyle(color: ResonanceColors.muted),
        ),
        const SizedBox(height: 26),
        _buildTokenConnection(
          provider: MusicProvider.yandex,
          controller: _yandexTokenController,
        ),
        const SizedBox(height: 12),
        _buildTokenConnection(
          provider: MusicProvider.soundcloud,
          controller: _soundCloudTokenController,
        ),
        const SizedBox(height: 12),
        _buildTokenConnection(
          provider: MusicProvider.youtube,
          controller: _youtubeTokenController,
        ),
        const SizedBox(height: 12),
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              SwitchListTile(
                key: const ValueKey('soundcloud-proxy-switch'),
                value: _proxyEnabled,
                onChanged: _savingProxy ? null : _setProxy,
                secondary: const Icon(Icons.route_rounded),
                title: const Text('Серверный прокси SoundCloud'),
                subtitle: const Text(
                  'Адрес и логин прокси хранятся только на сервере. '
                  'Приложение передаёт лишь переключатель; при включении '
                  'сервер также ретранслирует progressive-аудио.',
                ),
              ),
              if (_proxyMessage != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _proxyMessage!,
                      style: const TextStyle(color: ResonanceColors.muted),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        Text('Система', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _apiController,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(
                        labelText: 'Адрес Resonance API',
                        hintText: 'https://api.example.com',
                        prefixIcon: Icon(Icons.dns_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: _saveApi,
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Сохранить адрес'),
                      ),
                    ),
                    if (_apiMessage != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _apiMessage!,
                        style: const TextStyle(color: ResonanceColors.muted),
                      ),
                    ],
                  ],
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.system_update_alt_rounded),
                title: Text(_updateMessage),
                subtitle: Text('Установлено: $_installedVersion'),
                trailing: _checkingUpdate
                    ? const Icon(Icons.sync_rounded)
                    : _availableUpdate == null
                    ? IconButton(
                        tooltip: 'Проверить снова',
                        onPressed: _checkUpdate,
                        icon: const Icon(
                          Icons.check_circle_rounded,
                          color: ResonanceColors.success,
                        ),
                      )
                    : FilledButton(
                        onPressed: () =>
                            unawaited(launchUrl(_availableUpdate!.downloadUrl)),
                        child: const Text('Обновить'),
                      ),
              ),
              const Divider(height: 1),
              const ListTile(
                leading: Icon(Icons.shield_outlined),
                title: Text('Приватность воспроизведения'),
                subtitle: Text(
                  'Stream URL и credentials не сохраняются в Drift',
                ),
                trailing: Icon(
                  Icons.check_circle_rounded,
                  color: ResonanceColors.success,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTokenConnection({
    required MusicProvider provider,
    required TextEditingController controller,
  }) {
    final connected = _hasToken[provider] ?? false;
    final obscure = _obscureToken[provider] ?? true;
    final saving = _savingProvider == provider;
    final message = _tokenMessages[provider];
    final soundCloud = provider == MusicProvider.soundcloud;
    final serverConnected = _serverCredential[provider] == true;
    return _ConnectionCard(
      provider: provider,
      title: _providerName(provider),
      subtitle: connected
          ? '${_credentialName(provider)} сохранён на устройстве'
          : serverConnected
          ? 'Серверный ключ используется по умолчанию; можно указать свой'
          : 'Серверный ключ не настроен; укажите собственный',
      connected: connected,
      serverConnected: serverConnected,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: ValueKey('${provider.name}-token-field'),
            controller: controller,
            obscureText: obscure,
            enableSuggestions: false,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: _credentialName(provider),
              hintText: connected
                  ? 'Сохранён — вставьте новый для замены'
                  : soundCloud
                  ? '32 символа из SoundCloud API'
                  : provider == MusicProvider.youtube
                  ? 'Вставьте API key'
                  : 'Вставьте OAuth-токен',
              prefixIcon: const Icon(Icons.key_rounded),
              suffixIcon: IconButton(
                tooltip: obscure ? 'Показать' : 'Скрыть',
                onPressed: () => setState(() {
                  _obscureToken[provider] = !obscure;
                }),
                icon: Icon(
                  obscure
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: _savingProvider == null
                    ? () => _saveToken(provider, controller)
                    : null,
                icon: saving
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.lock_rounded),
                label: const Text('Сохранить безопасно'),
              ),
              if (connected)
                OutlinedButton.icon(
                  onPressed: () => _removeToken(provider),
                  icon: const Icon(Icons.link_off_rounded),
                  label: const Text('Отключить'),
                ),
            ],
          ),
          if (message != null) ...[
            const SizedBox(height: 10),
            Text(message, style: const TextStyle(color: ResonanceColors.muted)),
          ],
        ],
      ),
    );
  }
}

final class _AudioOutputCard extends StatelessWidget {
  const _AudioOutputCard({required this.audioOutput, required this.onSelected});

  final AudioOutputState audioOutput;
  final ValueChanged<AudioOutputDevice> onSelected;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.speaker_group_rounded),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Устройство вывода',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          KeyedSubtree(
            key: const ValueKey('audio-output-picker'),
            child: DropdownButtonFormField<AudioOutputDevice>(
              key: ValueKey(audioOutput.selected.id),
              isExpanded: true,
              initialValue: audioOutput.devices.firstWhere(
                (device) => device.id == audioOutput.selected.id,
                orElse: () => AudioOutputDevice.automatic,
              ),
              decoration: const InputDecoration(
                labelText: 'Куда воспроизводить звук',
                prefixIcon: Icon(Icons.headphones_rounded),
              ),
              items: audioOutput.devices
                  .map(
                    (device) => DropdownMenuItem(
                      value: device,
                      child: Text(device.label),
                    ),
                  )
                  .toList(growable: false),
              onChanged: audioOutput.changing
                  ? null
                  : (device) {
                      if (device != null) onSelected(device);
                    },
            ),
          ),
          const SizedBox(height: 8),
          Text(
            audioOutput.error ??
                (audioOutput.devices.length == 1
                    ? 'Сейчас система сообщает только устройство по умолчанию. Подключённые выходы появятся здесь автоматически.'
                    : 'Можно переключать звук между наушниками, колонками и другими системными выходами без перезапуска трека.'),
            style: TextStyle(
              color: audioOutput.error == null
                  ? ResonanceColors.muted
                  : Theme.of(context).colorScheme.error,
              fontSize: 12,
            ),
          ),
        ],
      ),
    ),
  );
}

class _AppearanceSlider extends StatelessWidget {
  const _AppearanceSlider({
    required this.label,
    required this.value,
    required this.max,
    required this.valueLabel,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final String label;
  final double value;
  final double max;
  final String valueLabel;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 92, child: Text(label)),
        Expanded(
          child: Slider(
            value: value,
            max: max,
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
          ),
        ),
        SizedBox(width: 48, child: Text(valueLabel, textAlign: TextAlign.end)),
      ],
    );
  }
}

class _ThemeSelector extends StatelessWidget {
  const _ThemeSelector({
    required this.compact,
    required this.selected,
    required this.onSelected,
  });

  final bool compact;
  final ResonanceThemePreset selected;
  final ValueChanged<ResonanceThemePreset> onSelected;

  @override
  Widget build(BuildContext context) {
    const entries = [
      (ResonanceThemePreset.graphite, 'Графит', Icons.contrast_rounded),
      (ResonanceThemePreset.midnight, 'Полночь', Icons.nightlight_round),
      (
        ResonanceThemePreset.ember,
        'Эмбер',
        Icons.local_fire_department_outlined,
      ),
    ];
    if (compact) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final entry in entries)
            ChoiceChip(
              selected: selected == entry.$1,
              onSelected: (_) => onSelected(entry.$1),
              avatar: Icon(entry.$3, size: 18),
              label: Text(entry.$2),
            ),
        ],
      );
    }
    return SegmentedButton<ResonanceThemePreset>(
      segments: [
        for (final entry in entries)
          ButtonSegment(
            value: entry.$1,
            icon: Icon(entry.$3),
            label: Text(entry.$2),
          ),
      ],
      selected: {selected},
      showSelectedIcon: false,
      onSelectionChanged: (selection) => onSelected(selection.first),
    );
  }
}

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({
    required this.provider,
    required this.title,
    required this.subtitle,
    required this.connected,
    required this.serverConnected,
    this.child,
  });

  final MusicProvider provider;
  final String title;
  final String subtitle;
  final bool connected;
  final bool serverConnected;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ProviderBadge(provider: provider),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: ResonanceColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: connected || serverConnected
                        ? ResonanceColors.success.withValues(alpha: 0.12)
                        : ResonanceColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    connected
                        ? 'Свой ключ'
                        : serverConnected
                        ? 'Сервер'
                        : 'Не настроено',
                    style: TextStyle(
                      color: connected || serverConnected
                          ? ResonanceColors.success
                          : ResonanceColors.muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            if (child != null) ...[const SizedBox(height: 18), child!],
          ],
        ),
      ),
    );
  }
}
