import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/app/providers.dart';
import 'package:resonance/core/networking/backend_endpoint.dart';
import 'package:resonance/core/playback/loudness_normalization.dart';
import 'package:resonance/core/playback/stream_quality.dart';
import 'package:resonance/core/preferences/playback_flow_preferences.dart';
import 'package:resonance/features/auth/account_controller.dart';
import 'package:resonance_alpha/design/accent.dart';
import 'package:resonance_alpha/design/tokens.dart';
import 'package:resonance_alpha/design/widgets.dart';
import 'package:resonance_alpha/screens/account_sheet.dart';
import 'package:resonance_alpha/state.dart';
import 'package:resonance_alpha/update.dart';


class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static Route<void> route() => PageRouteBuilder<void>(
    transitionDuration: Motion.base,
    reverseTransitionDuration: Motion.base,
    pageBuilder: (_, _, _) => const SettingsScreen(),
    transitionsBuilder: (_, animation, _, child) {
      final curved = CurvedAnimation(parent: animation, curve: Motion.curve);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, .04),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );

  Future<void> _flow(WidgetRef ref, PlaybackFlowSettings next) async {
    await ref.read(playbackFlowControllerProvider.notifier).update(next);
    final service = await ref.read(playbackServiceProvider.future);
    await service.setFlowSettings(next);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final pad = wide ? 48.0 : 20.0;
    final flow = ref.watch(playbackFlowControllerProvider);
    final accentPrefs = ref.watch(accentPrefsProvider);
    final accent = ref.watch(currentAccentProvider);
    final user = ref.watch(accountControllerProvider).valueOrNull;

    void setFlow(PlaybackFlowSettings next) =>
        run(context, () => _flow(ref, next));

    return Scaffold(
      backgroundColor: Pal.stage,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: ListView(
              padding: EdgeInsets.fromLTRB(pad, 12, pad, 80),
              children: [
                Row(
                  children: [
                    Knob(
                      icon: Icons.arrow_back_rounded,
                      size: 44,
                      tooltip: 'Назад',
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                    const Spacer(),
                    Text('НАСТРОЙКИ', style: Txt.mono(12)),
                  ],
                ),
                SizedBox(height: wide ? 56 : 36),
                Text('Настройки', style: Txt.display(wide ? 72 : 44)),
                const SizedBox(height: 48),

                const SectionHead(index: '01', title: 'Аккаунт'),
                _Row(
                  title: user?.email ?? 'Не выполнен вход',
                  subtitle: user == null
                      ? 'Войди, чтобы лайки и плейлисты были на всех устройствах'
                      : 'Лайки и плейлисты синхронизируются',
                  trailing: Pill(
                    label: user == null ? 'Войти' : 'Управлять',
                    active: user == null,
                    accent: accent,
                    onTap: () => showAccountSheet(context),
                  ),
                ),
                const SizedBox(height: 48),

                const SectionHead(index: '02', title: 'Звук'),
                _Row(
                  title: 'Качество',
                  subtitle: switch (flow.qualityMode) {
                    StreamQualityMode.auto =>
                      'Высокое по Wi‑Fi, экономное в мобильной сети',
                    StreamQualityMode.high => 'Всегда высокое',
                    StreamQualityMode.lossless =>
                      'Lossless, где источник его отдаёт',
                  },
                ),
                _Choices(
                  values: StreamQualityMode.values,
                  selected: flow.qualityMode,
                  label: (value) => value.label,
                  accent: accent,
                  onSelect: (value) =>
                      setFlow(flow.copyWith(qualityMode: value)),
                ),
                const _Divider(),
                _Row(
                  title: 'Плавный переход',
                  subtitle: flow.enabled
                      ? 'Треки перетекают друг в друга за '
                            '${(flow.transitionMs / 1000).toStringAsFixed(1)} с'
                      : 'Выключен',
                  trailing: _Toggle(
                    value: flow.enabled,
                    accent: accent,
                    onChanged: (value) =>
                        setFlow(flow.copyWith(enabled: value)),
                  ),
                ),
                if (flow.enabled)
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: accent,
                      inactiveTrackColor: Pal.line,
                      thumbColor: Pal.paper,
                    ),
                    child: Slider(
                      value: flow.transitionMs.clamp(0, 12000).toDouble(),
                      max: 12000,
                      divisions: 24,
                      onChanged: (value) => ref
                          .read(playbackFlowControllerProvider.notifier)
                          .update(flow.copyWith(transitionMs: value.round())),
                      onChangeEnd: (value) =>
                          setFlow(flow.copyWith(transitionMs: value.round())),
                    ),
                  ),
                const _Divider(),
                _Row(
                  title: 'Без пауз между треками',
                  subtitle: 'Альбомы играют слитно, как задумано',
                  trailing: _Toggle(
                    value: flow.gapless,
                    accent: accent,
                    onChanged: (value) =>
                        setFlow(flow.copyWith(gapless: value)),
                  ),
                ),
                const _Divider(),
                const _Row(
                  title: 'Выравнивание громкости',
                  subtitle: 'Тихие и громкие треки звучат ровно',
                ),
                _Choices(
                  values: LoudnessNormalizationMode.values,
                  selected: flow.normalization,
                  label: (value) => value.label,
                  accent: accent,
                  onSelect: (value) =>
                      setFlow(flow.copyWith(normalization: value)),
                ),
                const SizedBox(height: 48),

                const SectionHead(index: '03', title: 'Вид'),
                _Row(
                  title: 'Цвет из обложки',
                  subtitle: accentPrefs.fromCover
                      ? 'Интерфейс подстраивается под то, что играет'
                      : 'Всегда один цвет',
                  trailing: _Toggle(
                    value: accentPrefs.fromCover,
                    accent: accent,
                    onChanged: (value) => run(
                      context,
                      () => ref
                          .read(accentPrefsProvider.notifier)
                          .setFromCover(value),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  accentPrefs.fromCover
                      ? 'ЦВЕТ, ПОКА НИЧЕГО НЕ ИГРАЕТ'
                      : 'ЦВЕТ ИНТЕРФЕЙСА',
                  style: Txt.mono(11),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final (name, color) in accentSwatches)
                      Press(
                        tooltip: name,
                        onTap: () => run(
                          context,
                          () => ref
                              .read(accentPrefsProvider.notifier)
                              .setFixed(color),
                        ),
                        child: AnimatedContainer(
                          duration: Motion.base,
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: accentPrefs.fixed == color
                                  ? Pal.paper
                                  : Colors.transparent,
                              width: 3,
                              strokeAlign: BorderSide.strokeAlignOutside,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 48),

                const SectionHead(index: '04', title: 'О приложении'),
                _Row(
                  title: 'Resonance α $alphaVersion',
                  subtitle:
                      'Альфа нового интерфейса. Что-то может '
                      'работать не так — это нормально.',
                ),
                const _Divider(),
                const _UpdateRow(),
                const _Divider(),
                _Row(
                  title: 'Сервер',
                  subtitle: BackendEndpoint.displayValue.isEmpty
                      ? 'Не задан'
                      : BackendEndpoint.displayValue,
                ),
                const _Divider(),
                _Row(
                  title: 'Кэш обложек',
                  subtitle: 'Очистить картинки в памяти',
                  trailing: Pill(
                    label: 'Очистить',
                    onTap: () {
                      PaintingBinding.instance.imageCache
                        ..clear()
                        ..clearLiveImages();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Кэш обложек очищен')),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.title, this.subtitle, this.trailing});

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Txt.body(17, weight: 700)),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(subtitle!, style: Txt.body(14, color: Pal.muted)),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 16), trailing!],
        ],
      ),
    );
  }
}

class _Choices<T> extends StatelessWidget {
  const _Choices({
    required this.values,
    required this.selected,
    required this.label,
    required this.accent,
    required this.onSelect,
  });

  final List<T> values;
  final T selected;
  final String Function(T) label;
  final Color accent;
  final ValueChanged<T> onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final value in values)
            Pill(
              label: label(value),
              active: value == selected,
              accent: accent,
              onTap: () => onSelect(value),
            ),
        ],
      ),
    );
  }
}

/// Pill-shaped switch in the α style.
class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.value,
    required this.accent,
    required this.onChanged,
  });

  final bool value;
  final Color accent;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Press(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: Motion.base,
        curve: Motion.curve,
        width: 56,
        height: 32,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: value ? accent : Pal.line,
          borderRadius: BorderRadius.circular(16),
        ),
        child: AnimatedAlign(
          duration: Motion.base,
          curve: Motion.curve,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: value ? inkOn(accent) : Pal.muted,
            ),
          ),
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, color: Pal.line);
}

class _UpdateRow extends ConsumerWidget {
  const _UpdateRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final update = ref.watch(alphaUpdateProvider);
    final latest = update.valueOrNull;
    final subtitle = switch (update) {
      AsyncLoading() => 'Проверяю…',
      AsyncError() => 'Не получилось проверить',
      _ when latest == null => 'Сервер не ответил',
      _ when latest.isNewer => 'Доступна ${latest.version}',
      _ => 'У вас последняя версия',
    };
    return _Row(
      title: 'Обновления',
      subtitle: subtitle,
      trailing: latest != null && latest.isNewer
          ? Pill(
              label: 'Скачать',
              onTap: () => run(context, () => openUpdate(latest)),
            )
          : Pill(
              label: 'Проверить',
              onTap: () => ref.invalidate(alphaUpdateProvider),
            ),
    );
  }
}
