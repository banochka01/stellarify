import 'dart:async';

import 'package:flutter/material.dart';
import 'package:resonance/core/playback/loudness_normalization.dart';
import 'package:resonance/core/playback/stream_quality.dart';
import 'package:resonance/core/preferences/playback_flow_preferences.dart';

/// Настройки звука в карточке Flow: выравнивание громкости, gapless и
/// выбор качества потока.
class SoundQualityOptions extends StatelessWidget {
  const SoundQualityOptions({
    required this.flow,
    required this.onChanged,
    this.dynamicFilterAvailable,
    super.key,
  });

  final PlaybackFlowSettings flow;
  final Future<void> Function(PlaybackFlowSettings) onChanged;

  /// `false`, если в сборке плеера нет фильтров громкости.
  final bool? dynamicFilterAvailable;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          leading: const Icon(Icons.graphic_eq_rounded),
          title: const Text('Выравнивание громкости'),
          subtitle: Text(switch (flow.normalization) {
            LoudnessNormalizationMode.off =>
              'Треки играют с громкостью источника.',
            LoudnessNormalizationMode.track =>
              'Каждый трек приводится к −14 LUFS: YouTube, Яндекс и SoundCloud звучат одинаково.',
            LoudnessNormalizationMode.album =>
              'Один гейн на весь альбом: тихие и громкие треки альбома сохраняют задуманный баланс.',
          }, style: TextStyle(color: muted)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: SegmentedButton<LoudnessNormalizationMode>(
            showSelectedIcon: false,
            segments: [
              for (final mode in LoudnessNormalizationMode.values)
                ButtonSegment(value: mode, label: Text(mode.label)),
            ],
            selected: {flow.normalization},
            onSelectionChanged: (value) =>
                unawaited(onChanged(flow.copyWith(normalization: value.first))),
          ),
        ),
        if (flow.normalizeLoudness)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              dynamicFilterAvailable == false
                  ? 'Гейн берётся из метаданных провайдера и сохранённой статистики. Анализа на лету в этой сборке плеера нет.'
                  : 'Гейн берётся из метаданных провайдера или сохранённой статистики; новые треки измеряются при первом прослушивании.',
              style: TextStyle(color: muted, fontSize: 12),
            ),
          ),
        const Divider(height: 1),
        SwitchListTile(
          value: flow.gapless,
          onChanged: (enabled) =>
              unawaited(onChanged(flow.copyWith(gapless: enabled))),
          secondary: const Icon(Icons.join_inner_rounded),
          title: const Text('Без пауз между треками альбома'),
          subtitle: const Text(
            'Следующий трек альбома загружается заранее и начинается бесшовно, когда затухание выключено или работает умный переход.',
          ),
        ),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.high_quality_rounded),
          title: const Text('Качество потока'),
          subtitle: Text(switch (flow.qualityMode) {
            StreamQualityMode.auto =>
              'По Wi‑Fi — выбранное ниже качество, в мобильной сети — экономное.',
            StreamQualityMode.high =>
              'Всегда высокое качество, в том числе в мобильной сети.',
            StreamQualityMode.lossless =>
              'Lossless по Wi‑Fi, где провайдер его отдаёт; в мобильной сети — не выше высокого.',
          }, style: TextStyle(color: muted)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: SegmentedButton<StreamQualityMode>(
            showSelectedIcon: false,
            segments: [
              for (final mode in StreamQualityMode.values)
                ButtonSegment(value: mode, label: Text(mode.label)),
            ],
            selected: {flow.qualityMode},
            onSelectionChanged: (value) =>
                unawaited(onChanged(flow.copyWith(qualityMode: value.first))),
          ),
        ),
        SwitchListTile(
          value: flow.highQualityOnMobile,
          onChanged: flow.qualityMode == StreamQualityMode.auto
              ? null
              : (enabled) => unawaited(
                  onChanged(flow.copyWith(highQualityOnMobile: enabled)),
                ),
          secondary: const Icon(Icons.signal_cellular_alt_rounded),
          title: const Text('Высокое качество в мобильной сети'),
          subtitle: const Text(
            'Иначе в сотовой сети действует мобильное качество из настроек офлайна. Lossless по мобильной сети не включается.',
          ),
        ),
      ],
    );
  }
}
