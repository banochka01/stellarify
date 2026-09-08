import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/app/providers.dart';
import 'package:resonance/domain/entities/music_enums.dart';
import 'package:resonance/features/library/library_controller.dart';
import 'package:resonance/shared/theme/resonance_theme.dart';

class LibraryTransferDialog extends ConsumerStatefulWidget {
  const LibraryTransferDialog({super.key});

  @override
  ConsumerState<LibraryTransferDialog> createState() =>
      _LibraryTransferDialogState();
}

class _LibraryTransferDialogState extends ConsumerState<LibraryTransferDialog> {
  static const _providers = [
    MusicProvider.yandex,
    MusicProvider.spotify,
    MusicProvider.vk,
  ];
  static const _phases = [
    'Подключаемся к сервису',
    'Забираем любимые треки',
    'Собираем плейлисты',
    'Раскладываем коллекцию',
    'Сохраняем в Resonance',
  ];

  final Map<MusicProvider, bool> _connected = {};
  MusicProvider _selected = MusicProvider.yandex;
  bool _loadingTokens = true;
  bool _working = false;
  int _phase = 0;
  Timer? _phaseTimer;
  LibraryImportResult? _result;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_loadTokens());
  }

  Future<void> _loadTokens() async {
    final tokens = ref.read(secureTokenRepositoryProvider);
    for (final provider in _providers) {
      _connected[provider] = (await tokens.read(provider))?.isNotEmpty == true;
    }
    if (!mounted) return;
    final firstConnected = _providers.where((item) => _connected[item] == true);
    setState(() {
      _loadingTokens = false;
      if (firstConnected.isNotEmpty) _selected = firstConnected.first;
    });
  }

  Future<void> _start() async {
    if (_working) return;
    setState(() {
      _working = true;
      _phase = 0;
      _error = null;
    });
    _phaseTimer?.cancel();
    _phaseTimer = Timer.periodic(const Duration(milliseconds: 1350), (_) {
      if (mounted && _phase < _phases.length - 1) {
        setState(() => _phase++);
      }
    });
    try {
      final library = await ref
          .read(playlistImportServiceProvider)
          .importLibrary(_selected);
      if (mounted) setState(() => _phase = _phases.length - 1);
      final result = await ref
          .read(libraryControllerProvider.notifier)
          .importProviderLibrary(library);
      if (!mounted) return;
      setState(() {
        _result = result;
        _working = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst(RegExp(r'^\w+: '), '');
        _working = false;
      });
    } finally {
      _phaseTimer?.cancel();
    }
  }

  @override
  void dispose() {
    _phaseTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 680;
    return Dialog.fullscreen(
      backgroundColor: ResonanceColors.background,
      child: Stack(
        children: [
          const Positioned.fill(child: _TransferBackdrop()),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 12 : 28,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Закрыть',
                        onPressed: _working
                            ? null
                            : () => Navigator.pop(context, _result != null),
                        icon: const Icon(Icons.close_rounded),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'RESONANCE TRANSFER',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.8,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      compact ? 20 : 48,
                      compact ? 20 : 42,
                      compact ? 20 : 48,
                      40,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 880),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 260),
                          child: _result != null
                              ? _ResultStage(result: _result!)
                              : _working
                              ? _ProgressStage(
                                  phase: _phase,
                                  phases: _phases,
                                  provider: _selected,
                                )
                              : _ChooseStage(
                                  selected: _selected,
                                  connected: _connected,
                                  loading: _loadingTokens,
                                  error: _error,
                                  onSelected: (provider) =>
                                      setState(() => _selected = provider),
                                  onStart: _start,
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChooseStage extends StatelessWidget {
  const _ChooseStage({
    required this.selected,
    required this.connected,
    required this.loading,
    required this.error,
    required this.onSelected,
    required this.onStart,
  });

  final MusicProvider selected;
  final Map<MusicProvider, bool> connected;
  final bool loading;
  final String? error;
  final ValueChanged<MusicProvider> onSelected;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('choose'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Твоя музыка.\nТеперь здесь.',
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
            fontSize: MediaQuery.sizeOf(context).width < 600 ? 42 : 68,
            height: .94,
            letterSpacing: -3,
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Перенесём любимые треки и плейлисты целиком. '
          'Оригиналы останутся в сервисе — Resonance создаст свою копию.',
          style: TextStyle(
            color: ResonanceColors.muted,
            fontSize: 16,
            height: 1.55,
          ),
        ),
        const SizedBox(height: 38),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth >= 720
                ? (constraints.maxWidth - 24) / 3
                : constraints.maxWidth;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final provider in const [
                  MusicProvider.yandex,
                  MusicProvider.spotify,
                  MusicProvider.vk,
                ])
                  SizedBox(
                    width: width,
                    child: _ProviderChoice(
                      provider: provider,
                      selected: selected == provider,
                      connected: connected[provider] == true,
                      loading: loading,
                      onTap: () => onSelected(provider),
                    ),
                  ),
              ],
            );
          },
        ),
        if (error != null) ...[
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0x22FF5A63),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0x66FF5A63)),
            ),
            child: Text(
              error!,
              style: const TextStyle(color: Color(0xFFFFA69D)),
            ),
          ),
        ],
        const SizedBox(height: 30),
        FilledButton.icon(
          onPressed: loading ? null : onStart,
          icon: const Icon(Icons.arrow_forward_rounded),
          label: Text(
            connected[selected] == true
                ? 'Начать перенос'
                : 'Проверить подключение',
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'До 1 500 любимых треков и 50 плейлистов за один перенос.',
          style: TextStyle(color: ResonanceColors.muted, fontSize: 12),
        ),
      ],
    );
  }
}

class _ProviderChoice extends StatelessWidget {
  const _ProviderChoice({
    required this.provider,
    required this.selected,
    required this.connected,
    required this.loading,
    required this.onTap,
  });

  final MusicProvider provider;
  final bool selected;
  final bool connected;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _providerColor(provider);
    return Material(
      color: selected ? color.withValues(alpha: .12) : ResonanceColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? color : ResonanceColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: .5),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                    color: selected ? color : ResonanceColors.muted,
                  ),
                ],
              ),
              const SizedBox(height: 30),
              Text(
                _providerName(provider),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                loading
                    ? 'Проверяем…'
                    : connected
                    ? 'Подключено'
                    : 'Нужен токен в настройках',
                style: TextStyle(
                  color: connected
                      ? ResonanceColors.success
                      : ResonanceColors.muted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressStage extends StatelessWidget {
  const _ProgressStage({
    required this.phase,
    required this.phases,
    required this.provider,
  });

  final int phase;
  final List<String> phases;
  final MusicProvider provider;

  @override
  Widget build(BuildContext context) {
    final progress = .12 + phase * .18;
    return Column(
      key: const ValueKey('progress'),
      children: [
        const SizedBox(height: 70),
        SizedBox(
          width: 190,
          height: 190,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox.expand(
                child: CircularProgressIndicator(
                  value: progress.clamp(0, .88),
                  strokeWidth: 3,
                  backgroundColor: ResonanceColors.border,
                  color: _providerColor(provider),
                ),
              ),
              Icon(
                Icons.library_music_rounded,
                size: 58,
                color: _providerColor(provider),
              ),
            ],
          ),
        ),
        const SizedBox(height: 42),
        Text(
          phases[phase],
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        Text(
          '${_providerName(provider)} · ${(progress * 100).round()}%',
          style: const TextStyle(color: ResonanceColors.muted),
        ),
        const SizedBox(height: 44),
        for (var index = 0; index < phases.length; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Icon(
                  index < phase
                      ? Icons.check_circle_rounded
                      : index == phase
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 18,
                  color: index <= phase
                      ? ResonanceColors.primary
                      : ResonanceColors.muted,
                ),
                const SizedBox(width: 12),
                Text(
                  phases[index],
                  style: TextStyle(
                    color: index <= phase
                        ? ResonanceColors.text
                        : ResonanceColors.muted,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ResultStage extends StatelessWidget {
  const _ResultStage({required this.result});
  final LibraryImportResult result;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('result'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: const BoxDecoration(
            color: ResonanceColors.primary,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_rounded, size: 38, color: Colors.black),
        ),
        const SizedBox(height: 30),
        Text(
          'Музыка дома.',
          style: Theme.of(
            context,
          ).textTheme.displaySmall?.copyWith(fontSize: 62),
        ),
        const SizedBox(height: 14),
        const Text(
          'Коллекция перенесена и уже доступна в медиатеке.',
          style: TextStyle(color: ResonanceColors.muted, fontSize: 17),
        ),
        const SizedBox(height: 36),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _ResultMetric(
              value: '${result.tracks}',
              label: 'уникальных треков',
            ),
            _ResultMetric(value: '${result.favorites}', label: 'в избранном'),
            _ResultMetric(value: '${result.playlists}', label: 'плейлистов'),
          ],
        ),
        if (result.truncated) ...[
          const SizedBox(height: 20),
          const Text(
            'Очень большая медиатека перенесена в безопасных лимитах. Остальное можно добавить повторным импортом по ссылке.',
            style: TextStyle(color: ResonanceColors.muted),
          ),
        ],
        const SizedBox(height: 38),
        FilledButton.icon(
          onPressed: () => Navigator.pop(context, true),
          icon: const Icon(Icons.library_music_rounded),
          label: const Text('Открыть медиатеку'),
        ),
      ],
    );
  }
}

class _ResultMetric extends StatelessWidget {
  const _ResultMetric({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    width: 190,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: ResonanceColors.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: ResonanceColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: const TextStyle(color: ResonanceColors.muted, fontSize: 12),
        ),
      ],
    ),
  );
}

class _TransferBackdrop extends StatelessWidget {
  const _TransferBackdrop();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: RadialGradient(
        center: Alignment(1.1, -.9),
        radius: 1.25,
        colors: [Color(0x334B1D13), ResonanceColors.background],
      ),
    ),
  );
}

String _providerName(MusicProvider provider) => switch (provider) {
  MusicProvider.yandex => 'Яндекс Музыка',
  MusicProvider.spotify => 'Spotify',
  MusicProvider.vk => 'VK Музыка',
  MusicProvider.soundcloud => 'SoundCloud',
  MusicProvider.youtube => 'YouTube Music',
};

Color _providerColor(MusicProvider provider) => switch (provider) {
  MusicProvider.yandex => ResonanceColors.yandex,
  MusicProvider.spotify => ResonanceColors.spotify,
  MusicProvider.vk => ResonanceColors.vk,
  MusicProvider.soundcloud => ResonanceColors.soundcloud,
  MusicProvider.youtube => ResonanceColors.youtube,
};
