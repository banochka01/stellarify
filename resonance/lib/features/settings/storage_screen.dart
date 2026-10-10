import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:resonance/app/providers.dart';
import 'package:resonance/core/networking/network_status.dart';
import 'package:resonance/core/playback/offline_downloads.dart';
import 'package:resonance/core/preferences/offline_preferences.dart';
import 'package:resonance/domain/entities/music_enums.dart';
import 'package:resonance/features/offline/offline_controller.dart';
import 'package:resonance/shared/russian_plural.dart';
import 'package:resonance/shared/theme/resonance_theme.dart';

/// Кэш обложек cached_network_image (flutter_cache_manager по умолчанию).
Future<Directory> coverCacheDirectory() async => Directory(
  p.join((await getTemporaryDirectory()).path, 'libCachedImageData'),
);

Future<int> directorySize(Directory directory) async {
  var total = 0;
  try {
    if (!await directory.exists()) return 0;
    await for (final entity in directory.list(recursive: true)) {
      if (entity is File) total += await entity.length();
    }
  } on Object {
    // Недоступные файлы не считаем.
  }
  return total;
}

/// «1,2 ГБ», «340 МБ», «12 КБ».
String formatBytes(int bytes) {
  const kb = 1024, mb = kb * 1024, gb = mb * 1024;
  String fixed(double value) =>
      (value >= 10 ? value.toStringAsFixed(0) : value.toStringAsFixed(1))
          .replaceAll('.', ',');
  if (bytes >= gb) return '${fixed(bytes / gb)} ГБ';
  if (bytes >= mb) return '${fixed(bytes / mb)} МБ';
  if (bytes >= kb) return '${fixed(bytes / kb)} КБ';
  return '$bytes Б';
}

String _limitLabel(int mb) => mb == 0 ? 'Выкл.' : formatBytes(mb * 1024 * 1024);

String _qualityName(AudioQuality quality) => switch (quality) {
  AudioQuality.low => 'Экономия · 128',
  AudioQuality.medium => 'Баланс · 192',
  AudioQuality.high => 'Высокое · 320',
  AudioQuality.lossless => 'Лучшее доступное',
};

/// Занятое место; отдельный провайдер, чтобы экран можно было обновить.
final storageUsageProvider =
    FutureProvider.autoDispose<({OfflineUsage offline, int covers})>((
      ref,
    ) async {
      final downloads = ref.watch(offlineDownloadsProvider);
      final offline = await downloads.usage();
      var covers = 0;
      try {
        covers = await directorySize(await coverCacheDirectory());
      } on Object {
        // Нет временной папки (тесты, редкие платформы).
      }
      return (offline: offline, covers: covers);
    });

class StorageScreen extends ConsumerStatefulWidget {
  const StorageScreen({super.key});

  @override
  ConsumerState<StorageScreen> createState() => _StorageScreenState();
}

class _StorageScreenState extends ConsumerState<StorageScreen> {
  double? _dragLimit;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 650;
    final usage = ref.watch(storageUsageProvider);
    final settings = ref.watch(offlineSettingsProvider);
    final network =
        ref.watch(networkKindProvider).valueOrNull ?? NetworkKind.wifi;
    final wifiQuality =
        ref.watch(onboardingSettingsProvider).valueOrNull?.quality ??
        AudioQuality.high;
    final data = usage.valueOrNull;
    final total = data == null
        ? 0
        : data.offline.downloadsBytes +
              data.offline.autoCacheBytes +
              data.offline.lyricsBytes +
              data.covers;
    final steps = OfflineSettings.limitStepsMb;
    final stepIndex = steps
        .indexOf(settings.autoCacheLimitMb)
        .clamp(0, steps.length - 1);
    final sliderValue = _dragLimit ?? stepIndex.toDouble();

    return ListView(
      padding: EdgeInsets.fromLTRB(
        compact ? 18 : 34,
        26,
        compact ? 18 : 34,
        130,
      ),
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Назад',
              onPressed: () => context.go('/settings'),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Хранилище',
                style: Theme.of(context).textTheme.displaySmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          usage.hasError && data == null
              ? 'Не удалось посчитать занятое место'
              : data == null
              ? 'Считаем занятое место…'
              : 'Resonance занимает ${formatBytes(total)}'
                    '${network == NetworkKind.offline ? ' · сейчас без сети' : ''}',
          style: const TextStyle(color: ResonanceColors.muted),
        ),
        const SizedBox(height: 18),
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              _UsageTile(
                icon: Icons.download_done_rounded,
                title: 'Загрузки',
                subtitle: data == null
                    ? '…'
                    : '${tracksLabel(data.offline.downloadsCount)} · '
                          '${formatBytes(data.offline.downloadsBytes)} · '
                          'не удаляются автоматически',
                onClear: () => _confirmClear(
                  'Удалить все загрузки?',
                  'Скачанные вручную треки станут недоступны офлайн.',
                  () => ref.read(offlineDownloadsProvider).clearDownloads(),
                ),
              ),
              const Divider(height: 1),
              _UsageTile(
                icon: Icons.offline_bolt_rounded,
                title: 'Автокэш',
                subtitle: data == null
                    ? '…'
                    : '${tracksLabel(data.offline.autoCacheCount)} · '
                          '${formatBytes(data.offline.autoCacheBytes)}',
                onClear: () => _confirmClear(
                  'Очистить автокэш?',
                  'Частые треки и «Моя волна» скачаются снова по Wi‑Fi.',
                  () => ref.read(offlineDownloadsProvider).clearAutoCache(),
                ),
              ),
              const Divider(height: 1),
              _UsageTile(
                icon: Icons.lyrics_rounded,
                title: 'Тексты песен',
                subtitle: data == null
                    ? '…'
                    : '${data.offline.lyricsCount} '
                          '${ruPlural(data.offline.lyricsCount, 'текст', 'текста', 'текстов')} · '
                          '${formatBytes(data.offline.lyricsBytes)}',
                onClear: () => _confirmClear(
                  'Удалить сохранённые тексты?',
                  'Аудио останется, тексты загрузятся из сети при показе.',
                  () => ref.read(offlineDownloadsProvider).clearLyrics(),
                ),
              ),
              const Divider(height: 1),
              _UsageTile(
                icon: Icons.image_rounded,
                title: 'Обложки',
                subtitle: data == null ? '…' : formatBytes(data.covers),
                onClear: () => _confirmClear(
                  'Очистить кэш обложек?',
                  'Обложки загрузятся снова при просмотре.',
                  _clearCovers,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 34),
        Text('Автокэш', style: Theme.of(context).textTheme.displaySmall),
        const SizedBox(height: 8),
        const Text(
          'Топ-50 треков за 30 дней и сегодняшняя «Моя волна» сохраняются '
          'сами. Старые вытесняются первыми, ручные загрузки — никогда.',
          style: TextStyle(color: ResonanceColors.muted),
        ),
        const SizedBox(height: 18),
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.auto_mode_rounded),
                title: const Text('Кэшировать автоматически'),
                value: settings.autoCache,
                onChanged: (value) =>
                    _update(settings.copyWith(autoCache: value)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
                child: Row(
                  children: [
                    const Text('Лимит'),
                    Expanded(
                      child: Slider(
                        value: sliderValue,
                        max: (steps.length - 1).toDouble(),
                        divisions: steps.length - 1,
                        label: _limitLabel(steps[sliderValue.round()]),
                        onChanged: settings.autoCache
                            ? (value) => setState(() => _dragLimit = value)
                            : null,
                        onChangeEnd: (value) {
                          setState(() => _dragLimit = null);
                          _update(
                            settings.copyWith(
                              autoCacheLimitMb: steps[value.round()],
                            ),
                          );
                        },
                      ),
                    ),
                    SizedBox(
                      width: MediaQuery.textScalerOf(context).scale(64),
                      child: Text(
                        _limitLabel(steps[sliderValue.round()]),
                        textAlign: TextAlign.end,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: const Icon(Icons.signal_cellular_alt_rounded),
                title: const Text('Автокэш по мобильной сети'),
                subtitle: const Text('По умолчанию — только Wi‑Fi'),
                value: settings.autoCacheOnMobile,
                onChanged: settings.autoCache
                    ? (value) =>
                          _update(settings.copyWith(autoCacheOnMobile: value))
                    : null,
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: const Icon(Icons.skip_next_rounded),
                title: const Text('Предзагрузка следующего трека'),
                subtitle: const Text(
                  'Скачивает следующий трек очереди, пока играет текущий',
                ),
                value: settings.preloadNext,
                onChanged: (value) =>
                    _update(settings.copyWith(preloadNext: value)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 34),
        Text('Качество', style: Theme.of(context).textTheme.displaySmall),
        const SizedBox(height: 8),
        Text(switch (network) {
          NetworkKind.wifi => 'Сейчас: Wi‑Fi',
          NetworkKind.mobile => 'Сейчас: мобильная сеть',
          NetworkKind.offline => 'Сейчас: нет сети — играет только скачанное',
        }, style: const TextStyle(color: ResonanceColors.muted)),
        const SizedBox(height: 18),
        _QualityCard(
          icon: Icons.wifi_rounded,
          title: 'По Wi‑Fi',
          value: wifiQuality,
          onChanged: _setWifiQuality,
        ),
        const SizedBox(height: 12),
        _QualityCard(
          icon: Icons.signal_cellular_alt_rounded,
          title: 'По мобильной сети',
          value: settings.mobileQuality,
          onChanged: (quality) =>
              _update(settings.copyWith(mobileQuality: quality)),
        ),
      ],
    );
  }

  void _update(OfflineSettings value) {
    unawaited(
      ref
          .read(offlineSettingsProvider.notifier)
          .update(value)
          .then((_) {
            if (mounted) ref.invalidate(storageUsageProvider);
          })
          .catchError((Object _) {}),
    );
  }

  Future<void> _setWifiQuality(AudioQuality quality) async {
    await ref.read(onboardingPreferencesProvider).setQuality(quality);
    ref.invalidate(onboardingSettingsProvider);
  }

  Future<void> _clearCovers() async {
    final directory = await coverCacheDirectory();
    if (await directory.exists()) {
      await for (final entity in directory.list()) {
        try {
          await entity.delete(recursive: true);
        } on Object {
          // Занятый файл удалим в следующий раз.
        }
      }
    }
    PaintingBinding.instance.imageCache.clear();
  }

  Future<void> _confirmClear(
    String title,
    String message,
    Future<void> Function() action,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Очистить'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await action();
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не удалось очистить. Попробуйте ещё раз.'),
          ),
        );
      }
    }
    if (mounted) ref.invalidate(storageUsageProvider);
  }
}

class _UsageTile extends StatelessWidget {
  const _UsageTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onClear,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon),
    title: Text(title),
    subtitle: Text(subtitle),
    trailing: TextButton(onPressed: onClear, child: const Text('Очистить')),
  );
}

class _QualityCard extends StatelessWidget {
  const _QualityCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final AudioQuality value;
  final ValueChanged<AudioQuality> onChanged;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon),
              const SizedBox(width: 10),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final quality in AudioQuality.values)
                ChoiceChip(
                  label: Text(_qualityName(quality)),
                  selected: value == quality,
                  onSelected: (_) => onChanged(quality),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}
