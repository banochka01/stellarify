import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/app/providers.dart';
import 'package:resonance/core/playback/audio_effects.dart';
import 'package:resonance/shared/theme/resonance_theme.dart';

/// Эквалайзер: пресеты, 10 полос и отдельная настройка для устройства.
class EqualizerCard extends ConsumerWidget {
  const EqualizerCard({super.key});

  static const presets = [
    EqualizerPreset.flat,
    EqualizerPreset.bass,
    EqualizerPreset.voice,
    EqualizerPreset.headphones,
    EqualizerPreset.night,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final effects = ref.watch(audioEffectsControllerProvider);
    final controller = ref.read(audioEffectsControllerProvider.notifier);
    final profile = effects.current;
    final support = effects.support;
    final available = support?.equalizer ?? false;
    final devices = ref.watch(audioOutputControllerProvider).devices;
    final deviceLabel = devices
        .where((device) => device.id == effects.deviceId)
        .map((device) => device.label)
        .firstOrNull;
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            value: available && profile.enabled,
            onChanged: available
                ? (enabled) => unawaited(
                    controller.update(profile.copyWith(enabled: enabled)),
                  )
                : null,
            secondary: const Icon(Icons.equalizer_rounded),
            title: const Text('Эквалайзер'),
            subtitle: Text(switch (support) {
              null => 'Проверяем возможности плеера…',
              AudioFilterSupport(equalizer: false) =>
                'Недоступен в этой сборке плеера.',
              _ => '10 полос. Действует на все источники и офлайн-треки.',
            }),
          ),
          if (available) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 4),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final preset in presets)
                    ChoiceChip(
                      selected: profile.enabled && profile.preset == preset,
                      label: Text(preset.label),
                      onSelected: (_) => unawaited(
                        controller.update(
                          EqualizerProfile.fromPreset(
                            preset,
                          ).copyWith(enabled: preset != EqualizerPreset.flat),
                        ),
                      ),
                    ),
                  if (profile.preset == EqualizerPreset.custom)
                    const Chip(label: Text('Свой')),
                ],
              ),
            ),
            SizedBox(
              height: 190,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Row(
                  children: [
                    for (var i = 0; i < equalizerBands.length; i++)
                      Expanded(
                        child: _BandSlider(
                          label: _bandLabel(equalizerBands[i]),
                          value: profile.gains[i],
                          enabled: profile.enabled,
                          onChanged: (value) => unawaited(
                            controller.update(profile.withBand(i, value)),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (effects.deviceId != 'auto') ...[
              const Divider(height: 1),
              SwitchListTile(
                value: effects.hasOwnProfile,
                onChanged: (value) =>
                    unawaited(controller.setDeviceSpecific(value)),
                secondary: const Icon(Icons.headphones_rounded),
                title: Text(
                  'Отдельно для «${deviceLabel ?? effects.deviceId}»',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: const Text(
                  'Своя настройка включается сама, когда звук идёт на это устройство.',
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  static String _bandLabel(int hz) =>
      hz >= 1000 ? '${hz ~/ 1000}к' : hz.toString();
}

class _BandSlider extends StatefulWidget {
  const _BandSlider({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final double value;
  final bool enabled;

  /// Вызывается, когда палец отпущен: перестраивать фильтры libmpv на каждом
  /// кадре перетаскивания — это щелчки в звуке.
  final ValueChanged<double> onChanged;

  @override
  State<_BandSlider> createState() => _BandSliderState();
}

class _BandSliderState extends State<_BandSlider> {
  double? _dragging;

  @override
  Widget build(BuildContext context) {
    final value = (_dragging ?? widget.value).clamp(
      -equalizerMaxGainDb,
      equalizerMaxGainDb,
    );
    return Column(
      children: [
        Text(
          value.round() == 0
              ? '0'
              : '${value > 0 ? '+' : ''}${value.toStringAsFixed(0)}',
          style: const TextStyle(fontSize: 11, color: ResonanceColors.muted),
        ),
        Expanded(
          child: RotatedBox(
            quarterTurns: 3,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              ),
              child: Slider(
                value: value,
                min: -equalizerMaxGainDb,
                max: equalizerMaxGainDb,
                divisions: (equalizerMaxGainDb * 2).round(),
                onChanged: widget.enabled
                    ? (next) => setState(() => _dragging = next)
                    : null,
                onChangeEnd: widget.enabled
                    ? (next) {
                        setState(() => _dragging = null);
                        widget.onChanged(next);
                      }
                    : null,
              ),
            ),
          ),
        ),
        Text(
          widget.label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
