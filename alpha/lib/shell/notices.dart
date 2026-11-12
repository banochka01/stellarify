import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/app/providers.dart';
import 'package:resonance/domain/entities/music_enums.dart';
import 'package:resonance/domain/entities/unified_track.dart';
import 'package:resonance_alpha/design/accent.dart';
import 'package:resonance_alpha/design/tokens.dart';
import 'package:resonance_alpha/design/widgets.dart';
import 'package:resonance_alpha/state.dart';
import 'package:resonance_alpha/update.dart';

/// A failed track gets a plain reason and a way out, not a dead button.
final class PlaybackIssue {
  const PlaybackIssue(this.title, this.hint, this.details);

  final String title;
  final String hint;
  final String details;

  static PlaybackIssue from(String message) {
    final text = message.toLowerCase();
    if (text.contains('нет доступных источников')) {
      return PlaybackIssue(
        'У трека нет рабочего источника',
        'Попробуйте найти его в другом каталоге.',
        message,
      );
    }
    if (text.contains('войд') ||
        text.contains('авториз') ||
        text.contains('токен') ||
        text.contains('401') ||
        text.contains('403')) {
      return PlaybackIssue(
        'Источник просит войти',
        'Подключите аккаунт в настройках или возьмите другой каталог.',
        message,
      );
    }
    if (text.contains('socket') ||
        text.contains('timeout') ||
        text.contains('тайм') ||
        text.contains('connection') ||
        text.contains('нет связи')) {
      return PlaybackIssue(
        'Нет связи',
        'Проверьте интернет и попробуйте ещё раз.',
        message,
      );
    }
    if (text.contains('недоступен') || text.contains('сервер')) {
      return PlaybackIssue(
        'Каталог сейчас не отвечает',
        'Обычно это ненадолго. Можно взять трек из другого каталога.',
        message,
      );
    }
    if (text.contains('прервано')) {
      return PlaybackIssue(
        'Воспроизведение оборвалось',
        'Поток закончился раньше времени.',
        message,
      );
    }
    return PlaybackIssue(
      'Трек не включился',
      'Попробуйте ещё раз или другой каталог.',
      message,
    );
  }
}

String providerName(MusicProvider provider) => switch (provider) {
  MusicProvider.yandex => 'Яндекс',
  MusicProvider.soundcloud => 'SoundCloud',
  MusicProvider.spotify => 'Spotify',
  MusicProvider.vk => 'VK',
  _ => provider.name,
};

class PlaybackIssueBar extends ConsumerStatefulWidget {
  const PlaybackIssueBar({super.key});

  @override
  ConsumerState<PlaybackIssueBar> createState() => _PlaybackIssueBarState();
}

class _PlaybackIssueBarState extends ConsumerState<PlaybackIssueBar> {
  bool _expanded = false;
  bool _busy = false;

  Future<void> _guard(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _retry() async {
    final service = await ref.read(playbackServiceProvider.future);
    final position = service.state.position;
    await service.prepareCurrent(start: position);
    await service.play();
  }

  Future<void> _skip() async {
    final service = await ref.read(playbackServiceProvider.future);
    await service.next();
  }

  /// Same song from a catalog the failed track does not come from.
  Future<void> _elsewhere(UnifiedTrack track) async {
    final failed = {for (final source in track.sources) source.provider};
    final outcome = await ref.read(
      searchProvider('${track.artist} ${track.title}').future,
    );
    UnifiedTrack? match;
    for (final candidate in outcome.tracks) {
      final other = candidate.sources.any(
        (source) => !failed.contains(source.provider),
      );
      final same =
          candidate.normalizedTitle.contains(track.normalizedTitle) ||
          track.normalizedTitle.contains(candidate.normalizedTitle);
      final artist =
          candidate.normalizedArtist.contains(track.normalizedArtist) ||
          track.normalizedArtist.contains(candidate.normalizedArtist);
      if (other && same && artist) {
        match = candidate;
        break;
      }
    }
    if (match == null) {
      throw StateError('В других каталогах этот трек не нашёлся');
    }
    final service = await ref.read(playbackServiceProvider.future);
    await service.playNext(match);
    await service.next();
  }

  @override
  Widget build(BuildContext context) {
    final message = ref.watch(
      playbackStateProvider.select((s) => s.valueOrNull?.errorMessage),
    );
    final track = ref.watch(currentTrackProvider);
    final accent = ref.watch(currentAccentProvider);
    return AnimatedSize(
      duration: Motion.base,
      curve: Motion.curve,
      alignment: Alignment.bottomCenter,
      child: message == null || track == null
          ? const SizedBox(width: double.infinity)
          : _card(context, PlaybackIssue.from(message), track, accent),
    );
  }

  Widget _card(
    BuildContext context,
    PlaybackIssue issue,
    UnifiedTrack track,
    Color accent,
  ) {
    final providers = track.sources
        .map((source) => providerName(source.provider))
        .toSet()
        .join(', ');
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
      decoration: BoxDecoration(
        color: Color.lerp(accent, Pal.stage, .86),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: .28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(Icons.error_outline_rounded, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(issue.title, style: Txt.body(15, weight: 750)),
                    const SizedBox(height: 2),
                    Text(
                      providers.isEmpty
                          ? issue.hint
                          : '${issue.hint} Источник: $providers.',
                      style: Txt.body(13, color: Pal.muted),
                    ),
                  ],
                ),
              ),
              Press(
                tooltip: _expanded ? 'Скрыть подробности' : 'Подробности',
                onTap: () => setState(() => _expanded = !_expanded),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    _expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: Pal.muted,
                  ),
                ),
              ),
            ],
          ),
          if (_expanded) ...[
            const SizedBox(height: 8),
            SelectableText(
              issue.details,
              style: Txt.body(12, color: Pal.faint),
            ),
          ],
          const SizedBox(height: 10),
          Opacity(
            opacity: _busy ? .5 : 1,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Pill(
                  label: 'Ещё раз',
                  icon: Icons.refresh_rounded,
                  active: true,
                  accent: accent,
                  onTap: () => run(context, () => _guard(_retry)),
                ),
                Pill(
                  label: 'Другой каталог',
                  icon: Icons.swap_horiz_rounded,
                  onTap: () =>
                      run(context, () => _guard(() => _elsewhere(track))),
                ),
                Pill(
                  label: 'Дальше',
                  icon: Icons.skip_next_rounded,
                  onTap: () => run(context, () => _guard(_skip)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "There is a newer α" strip; hides for the build the user put off.
class UpdateBanner extends ConsumerWidget {
  const UpdateBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final release = ref.watch(alphaUpdateProvider).valueOrNull;
    final dismissed = ref.watch(dismissedUpdateProvider);
    final show =
        release != null && release.isNewer && release.build != dismissed;
    return AnimatedSize(
      duration: Motion.base,
      curve: Motion.curve,
      child: !show
          ? const SizedBox(width: double.infinity)
          : Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 10, 10, 10),
              decoration: const BoxDecoration(
                color: Pal.raised,
                border: Border(bottom: BorderSide(color: Pal.line)),
              ),
              child: Row(
                children: [
                  Text('α', style: Txt.display(20, color: Pal.acid)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      release.notes.isEmpty
                          ? 'Вышла α ${release.version}'
                          : 'Вышла α ${release.version} · ${release.notes}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Txt.body(13.5),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Pill(
                    label: 'Скачать',
                    active: true,
                    onTap: () => run(context, () => openUpdate(release)),
                  ),
                  const SizedBox(width: 4),
                  Press(
                    tooltip: 'Позже',
                    onTap: () => unawaited(
                      ref
                          .read(dismissedUpdateProvider.notifier)
                          .dismiss(release.build),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.close_rounded, color: Pal.muted),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
