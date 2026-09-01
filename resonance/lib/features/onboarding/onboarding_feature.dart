import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/app/providers.dart';
import 'package:resonance/core/preferences/appearance_preferences.dart';
import 'package:resonance/domain/entities/music_enums.dart';
import 'package:resonance/features/library/library_controller.dart';
import 'package:resonance/shared/theme/resonance_theme.dart';

class OnboardingGate extends ConsumerWidget {
  const OnboardingGate({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (Platform.environment.containsKey('FLUTTER_TEST')) return child;
    final settings = ref.watch(onboardingSettingsProvider);
    return settings.when(
      data: (value) => value.completed
          ? child
          : OnboardingScreen(
              onCompleted: () => ref.invalidate(onboardingSettingsProvider),
            ),
      loading: () => const _StartupSplash(),
      error: (_, _) => child,
    );
  }
}

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({this.onCompleted, super.key});

  final VoidCallback? onCompleted;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _providers = <MusicProvider>{
    MusicProvider.soundcloud,
    MusicProvider.yandex,
  };
  final _tokens = <MusicProvider, TextEditingController>{
    for (final provider in MusicProvider.values)
      provider: TextEditingController(),
  };
  final _connected = <MusicProvider, bool>{};
  final _serverAvailable = <MusicProvider, bool>{};
  final _messages = <MusicProvider, String>{};
  final _playlistController = TextEditingController();

  int _step = 0;
  AudioQuality _quality = AudioQuality.high;
  ResonanceThemePreset _theme = ResonanceThemePreset.graphite;
  MusicProvider? _savingProvider;
  bool _finishing = false;
  String? _finishError;

  @override
  void initState() {
    super.initState();
    _theme = ref.read(appearanceControllerProvider).theme;
    unawaited(_loadConnections());
  }

  @override
  void dispose() {
    for (final controller in _tokens.values) {
      controller.dispose();
    }
    _playlistController.dispose();
    super.dispose();
  }

  Future<void> _loadConnections() async {
    final repository = ref.read(secureTokenRepositoryProvider);
    final stored = await Future.wait(MusicProvider.values.map(repository.read));
    Map<MusicProvider, bool> server = const {};
    try {
      server = await ref
          .read(resonanceBackendClientProvider)
          .serverCredentialStatus();
    } on Object {
      // Offline onboarding still works and can be completed later.
    }
    if (!mounted) return;
    setState(() {
      for (var index = 0; index < MusicProvider.values.length; index++) {
        _connected[MusicProvider.values[index]] =
            stored[index]?.isNotEmpty == true;
      }
      _serverAvailable.addAll(server);
    });
  }

  Future<void> _saveToken(MusicProvider provider) async {
    final token = _tokens[provider]!.text.trim();
    if (token.isEmpty) {
      setState(() => _messages[provider] = 'Вставьте данные подключения.');
      return;
    }
    setState(() {
      _savingProvider = provider;
      _messages.remove(provider);
    });
    try {
      await ref
          .read(resonanceBackendClientProvider)
          .validateProvider(provider: provider, token: token);
      await ref.read(secureTokenRepositoryProvider).write(provider, token);
      if (!mounted) return;
      _tokens[provider]!.clear();
      setState(() {
        _connected[provider] = true;
        _messages[provider] = 'Подключение проверено и сохранено.';
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _messages[provider] = error.toString().replaceFirst(
          RegExp(r'^\w+:\s*'),
          '',
        );
      });
    } finally {
      if (mounted) setState(() => _savingProvider = null);
    }
  }

  Future<void> _finish({bool importPlaylist = true}) async {
    if (_finishing) return;
    setState(() {
      _finishing = true;
      _finishError = null;
    });
    try {
      final playlistUrl = _playlistController.text.trim();
      if (importPlaylist && playlistUrl.isNotEmpty) {
        final playlist = await ref
            .read(playlistImportServiceProvider)
            .importUrl(playlistUrl);
        await ref
            .read(libraryControllerProvider.notifier)
            .importPlaylist(playlist);
      }
      await ref
          .read(onboardingPreferencesProvider)
          .complete(providers: _providers, quality: _quality);
      ref.invalidate(onboardingSettingsProvider);
      widget.onCompleted?.call();
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _finishError = error.toString().replaceFirst(RegExp(r'^\w+:\s*'), '');
      });
    } finally {
      if (mounted) setState(() => _finishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 720;
    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1080),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 18 : 44,
                vertical: compact ? 14 : 28,
              ),
              child: Column(
                children: [
                  _OnboardingHeader(
                    step: _step,
                    compact: compact,
                    onSkip: _finishing
                        ? null
                        : () => _finish(importPlaylist: false),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 280),
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position:
                              Tween(
                                begin: const Offset(.025, 0),
                                end: Offset.zero,
                              ).animate(
                                CurvedAnimation(
                                  parent: animation,
                                  curve: Curves.easeOutCubic,
                                ),
                              ),
                          child: child,
                        ),
                      ),
                      child: KeyedSubtree(
                        key: ValueKey(_step),
                        child: _buildStep(compact),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildFooter(compact),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep(bool compact) => switch (_step) {
    0 => _WelcomeStep(compact: compact),
    1 => _ProviderStep(
      compact: compact,
      selected: _providers,
      onChanged: (provider, selected) {
        setState(() {
          if (selected) {
            _providers.add(provider);
          } else if (_providers.length > 1) {
            _providers.remove(provider);
          }
        });
      },
    ),
    2 => _ConnectionStep(
      providers: _providers,
      controllers: _tokens,
      connected: _connected,
      serverAvailable: _serverAvailable,
      messages: _messages,
      savingProvider: _savingProvider,
      onSave: _saveToken,
    ),
    _ => _PersonalizationStep(
      theme: _theme,
      quality: _quality,
      playlistController: _playlistController,
      error: _finishError,
      onThemeChanged: (theme) {
        setState(() => _theme = theme);
        unawaited(
          ref.read(appearanceControllerProvider.notifier).setTheme(theme),
        );
      },
      onQualityChanged: (quality) => setState(() => _quality = quality),
    ),
  };

  Widget _buildFooter(bool compact) {
    return Row(
      children: [
        if (_step > 0)
          TextButton.icon(
            onPressed: _finishing ? null : () => setState(() => _step--),
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Назад'),
          )
        else
          const Spacer(),
        if (_step > 0) const Spacer(),
        FilledButton.icon(
          key: const ValueKey('onboarding-next'),
          onPressed: _finishing
              ? null
              : () {
                  if (_step < 3) {
                    setState(() => _step++);
                  } else {
                    _finish();
                  }
                },
          icon: _finishing
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  _step == 3
                      ? Icons.rocket_launch_rounded
                      : Icons.arrow_forward_rounded,
                ),
          label: Text(
            _step == 3
                ? compact
                      ? 'Готово'
                      : 'Запустить Resonance'
                : compact
                ? 'Далее'
                : 'Продолжить',
          ),
        ),
      ],
    );
  }
}

class _OnboardingHeader extends StatelessWidget {
  const _OnboardingHeader({
    required this.step,
    required this.compact,
    required this.onSkip,
  });

  final int step;
  final bool compact;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(11),
          ),
          child: const Icon(Icons.graphic_eq_rounded, color: Colors.black),
        ),
        if (!compact) ...[
          const SizedBox(width: 12),
          const Text(
            'RESONANCE',
            style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2.2),
          ),
        ],
        const Spacer(),
        ...List.generate(4, (index) {
          final active = index <= step;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: index == step ? 30 : 8,
            height: 8,
            margin: const EdgeInsets.only(left: 6),
            decoration: BoxDecoration(
              color: active
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outline,
              borderRadius: BorderRadius.circular(8),
            ),
          );
        }),
        const SizedBox(width: 12),
        if (compact)
          IconButton(
            tooltip: 'Настроить позже',
            onPressed: onSkip,
            icon: const Icon(Icons.fast_forward_rounded),
          )
        else
          TextButton(onPressed: onSkip, child: const Text('Настроить позже')),
      ],
    );
  }
}

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.only(top: compact ? 26 : 70),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ВАША МУЗЫКА.\nОДИН ПУЛЬС.',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontSize: compact ? 46 : 76,
                height: .9,
                letterSpacing: compact ? -2 : -4.5,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Подключите любимые сервисы, выберите звучание и перенесите '
              'плейлист. Настройка займёт меньше двух минут.',
              style: TextStyle(
                color: ResonanceColors.muted,
                fontSize: 17,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 42),
            const Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _FeaturePill(Icons.hub_rounded, '3 источника'),
                _FeaturePill(Icons.lock_rounded, 'Токены защищены'),
                _FeaturePill(Icons.queue_music_rounded, 'Импорт плейлистов'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProviderStep extends StatelessWidget {
  const _ProviderStep({
    required this.compact,
    required this.selected,
    required this.onChanged,
  });

  final bool compact;
  final Set<MusicProvider> selected;
  final void Function(MusicProvider, bool) onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _StepTitle(
            eyebrow: '01 · ИСТОЧНИКИ',
            title: 'Где живёт ваша музыка?',
            subtitle:
                'Выберите сервисы, которые хотите настроить сейчас. Остальные останутся доступны, и к ним можно вернуться позже.',
          ),
          const SizedBox(height: 28),
          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = compact
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 24) / 3;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final provider in [
                    MusicProvider.soundcloud,
                    MusicProvider.yandex,
                  ])
                    SizedBox(
                      width: cardWidth,
                      child: _ProviderChoice(
                        provider: provider,
                        selected: selected.contains(provider),
                        onChanged: (value) => onChanged(provider, value),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          const Text(
            'Воспроизведение — только в собственном плеере Resonance; Яндекс Музыка '
            'и SoundCloud поддерживают нативное воспроизведение.',
            style: TextStyle(color: ResonanceColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _ConnectionStep extends StatelessWidget {
  const _ConnectionStep({
    required this.providers,
    required this.controllers,
    required this.connected,
    required this.serverAvailable,
    required this.messages,
    required this.savingProvider,
    required this.onSave,
  });

  final Set<MusicProvider> providers;
  final Map<MusicProvider, TextEditingController> controllers;
  final Map<MusicProvider, bool> connected;
  final Map<MusicProvider, bool> serverAvailable;
  final Map<MusicProvider, String> messages;
  final MusicProvider? savingProvider;
  final ValueChanged<MusicProvider> onSave;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _StepTitle(
            eyebrow: '02 · ПОДКЛЮЧЕНИЕ',
            title: 'Войдите в свой ритм',
            subtitle:
                'Проверка выполняется до сохранения. Значения хранятся только в защищённом хранилище устройства.',
          ),
          const SizedBox(height: 24),
          for (final provider in [
            MusicProvider.soundcloud,
            MusicProvider.yandex,
          ])
            if (providers.contains(provider))
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ConnectionCard(
                  provider: provider,
                  controller: controllers[provider]!,
                  connected: connected[provider] == true,
                  serverAvailable: serverAvailable[provider] == true,
                  message: messages[provider],
                  saving: savingProvider == provider,
                  onSave: () => onSave(provider),
                ),
              ),
        ],
      ),
    );
  }
}

class _PersonalizationStep extends StatelessWidget {
  const _PersonalizationStep({
    required this.theme,
    required this.quality,
    required this.playlistController,
    required this.error,
    required this.onThemeChanged,
    required this.onQualityChanged,
  });

  final ResonanceThemePreset theme;
  final AudioQuality quality;
  final TextEditingController playlistController;
  final String? error;
  final ValueChanged<ResonanceThemePreset> onThemeChanged;
  final ValueChanged<AudioQuality> onQualityChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _StepTitle(
            eyebrow: '03 · ПЕРСОНАЛИЗАЦИЯ',
            title: 'Настройте Resonance под себя',
            subtitle:
                'Тему можно менять мгновенно. Качество применяется ко всем нативным источникам.',
          ),
          const SizedBox(height: 24),
          Text('ТЕМА', style: _sectionLabelStyle),
          const SizedBox(height: 10),
          SegmentedButton<ResonanceThemePreset>(
            segments: const [
              ButtonSegment(
                value: ResonanceThemePreset.graphite,
                label: Text('Графит'),
                icon: Icon(Icons.circle_outlined),
              ),
              ButtonSegment(
                value: ResonanceThemePreset.midnight,
                label: Text('Полночь'),
                icon: Icon(Icons.nights_stay_rounded),
              ),
              ButtonSegment(
                value: ResonanceThemePreset.ember,
                label: Text('Жар'),
                icon: Icon(Icons.local_fire_department_rounded),
              ),
            ],
            selected: {theme},
            onSelectionChanged: (value) => onThemeChanged(value.first),
          ),
          const SizedBox(height: 24),
          Text('КАЧЕСТВО', style: _sectionLabelStyle),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: AudioQuality.values
                .map((item) {
                  return ChoiceChip(
                    label: Text(_qualityLabel(item)),
                    selected: quality == item,
                    onSelected: (_) => onQualityChanged(item),
                  );
                })
                .toList(growable: false),
          ),
          const SizedBox(height: 24),
          Text('БЫСТРЫЙ ИМПОРТ · НЕОБЯЗАТЕЛЬНО', style: _sectionLabelStyle),
          const SizedBox(height: 10),
          TextField(
            key: const ValueKey('onboarding-playlist-url'),
            controller: playlistController,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.link_rounded),
              labelText: 'Ссылка на плейлист Яндекс Музыки или YouTube',
              hintText: 'https://music.yandex.ru/users/…/playlists/…',
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProviderChoice extends StatelessWidget {
  const _ProviderChoice({
    required this.provider,
    required this.selected,
    required this.onChanged,
  });

  final MusicProvider provider;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final color = _providerColor(provider);
    return Card(
      color: selected ? color.withValues(alpha: .11) : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => onChanged(!selected),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(_providerIcon(provider), color: color, size: 30),
                  const Spacer(),
                  Checkbox(
                    value: selected,
                    onChanged: (value) => onChanged(value ?? false),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              Text(
                _providerName(provider),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _providerDescription(provider),
                style: const TextStyle(
                  color: ResonanceColors.muted,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({
    required this.provider,
    required this.controller,
    required this.connected,
    required this.serverAvailable,
    required this.message,
    required this.saving,
    required this.onSave,
  });

  final MusicProvider provider;
  final TextEditingController controller;
  final bool connected;
  final bool serverAvailable;
  final String? message;
  final bool saving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final ready = connected || serverAvailable;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  _providerIcon(provider),
                  color: _providerColor(provider),
                  size: 25,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _providerName(provider),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        connected
                            ? 'Личное подключение активно'
                            : serverAvailable
                            ? 'Доступен серверный режим'
                            : 'Требуются данные подключения',
                        style: TextStyle(
                          color: ready
                              ? ResonanceColors.success
                              : ResonanceColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  ready
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: ready
                      ? ResonanceColors.success
                      : ResonanceColors.muted,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    key: ValueKey('onboarding-${provider.name}-token'),
                    controller: controller,
                    obscureText: true,
                    enableSuggestions: false,
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: _credentialLabel(provider),
                      helperText: _credentialHint(provider),
                      helperMaxLines: 2,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: saving ? null : onSave,
                  child: saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Проверить'),
                ),
              ],
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  message!,
                  style: TextStyle(
                    color: connected
                        ? ResonanceColors.success
                        : Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StepTitle extends StatelessWidget {
  const _StepTitle({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
  });

  final String eyebrow;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow,
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.8,
          ),
        ),
        const SizedBox(height: 10),
        Text(title, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(subtitle, style: const TextStyle(color: ResonanceColors.muted)),
      ],
    );
  }
}

class _FeaturePill extends StatelessWidget {
  const _FeaturePill(this.icon, this.label);

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: .86),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _StartupSplash extends StatelessWidget {
  const _StartupSplash();

  @override
  Widget build(BuildContext context) {
    return const Material(
      color: Colors.transparent,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.graphic_eq_rounded, size: 42),
            SizedBox(height: 16),
            SizedBox(width: 120, child: LinearProgressIndicator(minHeight: 2)),
          ],
        ),
      ),
    );
  }
}

const _sectionLabelStyle = TextStyle(
  color: ResonanceColors.muted,
  fontSize: 10,
  fontWeight: FontWeight.w900,
  letterSpacing: 1.5,
);

String _providerName(MusicProvider provider) => switch (provider) {
  MusicProvider.yandex => 'Яндекс Музыка',
  MusicProvider.soundcloud => 'SoundCloud',
  MusicProvider.youtube => 'YouTube Music',
};

String _providerDescription(MusicProvider provider) => switch (provider) {
  MusicProvider.yandex => 'Каталог, плейлисты и нативное воспроизведение.',
  MusicProvider.soundcloud => 'Ремиксы, независимые артисты и нативный звук.',
  MusicProvider.youtube => 'Только импорт метаданных, без воспроизведения.',
};

String _credentialLabel(MusicProvider provider) => switch (provider) {
  MusicProvider.yandex => 'OAuth-токен Яндекс Музыки',
  MusicProvider.soundcloud => 'SoundCloud Client ID или OAuth-токен',
  MusicProvider.youtube => 'Ключ YouTube Data API',
};

String _credentialHint(MusicProvider provider) => switch (provider) {
  MusicProvider.yandex => 'Нужен для личной библиотеки и будущей Волны.',
  MusicProvider.soundcloud =>
    'Можно пропустить, если доступен серверный режим.',
  MusicProvider.youtube =>
    'Внешний плеер не используется. Доступен только импорт метаданных.',
};

IconData _providerIcon(MusicProvider provider) => switch (provider) {
  MusicProvider.yandex => Icons.album_rounded,
  MusicProvider.soundcloud => Icons.cloud_rounded,
  MusicProvider.youtube => Icons.smart_display_rounded,
};

Color _providerColor(MusicProvider provider) => switch (provider) {
  MusicProvider.yandex => ResonanceColors.yandex,
  MusicProvider.soundcloud => ResonanceColors.soundcloud,
  MusicProvider.youtube => ResonanceColors.youtube,
};

String _qualityLabel(AudioQuality quality) => switch (quality) {
  AudioQuality.low => 'Экономия · 128',
  AudioQuality.medium => 'Баланс · 192',
  AudioQuality.high => 'Высокое · 320',
  AudioQuality.lossless => 'Лучшее доступное',
};
