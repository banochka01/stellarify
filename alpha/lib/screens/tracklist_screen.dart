import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/domain/entities/unified_track.dart';
import 'package:resonance/features/library/library_controller.dart';
import 'package:resonance/shared/widgets/track_artwork.dart';
import 'package:resonance_alpha/design/accent.dart';
import 'package:resonance_alpha/design/tokens.dart';
import 'package:resonance_alpha/design/widgets.dart';
import 'package:resonance_alpha/screens/track_row.dart';
import 'package:resonance_alpha/state.dart';

/// Any list of tracks: a mix, a playlist, the likes. The header is a poster —
/// the first cover blown up behind a giant title.
class TracklistScreen extends ConsumerStatefulWidget {
  const TracklistScreen({
    required this.title,
    required this.load,
    this.subtitle,
    this.playlistId,
    this.reloadOn,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Future<List<UnifiedTrack>> Function() load;

  /// A local playlist: adds rename / delete and per-track removal.
  final String? playlistId;

  /// Reloads the list whenever this provider changes (likes, downloads…).
  final ProviderListenable<Object?>? reloadOn;

  static Route<void> route({
    required String title,
    required Future<List<UnifiedTrack>> Function() load,
    String? subtitle,
    String? playlistId,
    ProviderListenable<Object?>? reloadOn,
  }) => alphaRoute(
    TracklistScreen(
      title: title,
      subtitle: subtitle,
      load: load,
      playlistId: playlistId,
      reloadOn: reloadOn,
    ),
  );

  @override
  ConsumerState<TracklistScreen> createState() => _TracklistScreenState();
}

class _TracklistScreenState extends ConsumerState<TracklistScreen> {
  late Future<List<UnifiedTrack>> _tracks = widget.load();
  List<UnifiedTrack> _last = const [];

  void _reload() => setState(() => _tracks = widget.load());

  Future<void> _rename(String id, String current) async {
    final name = await askText(
      context,
      title: 'Переименовать',
      action: 'Сохранить',
      initial: current,
    );
    if (name == null || name == current || !mounted) return;
    run(
      context,
      () =>
          ref.read(libraryControllerProvider.notifier).renamePlaylist(id, name),
    );
  }

  Future<void> _delete(String id, String name) async {
    final yes = await confirm(
      context,
      title: 'Удалить «$name»?',
      body: 'Треки останутся в каталоге и в «Мне нравится».',
      action: 'Удалить',
    );
    if (!yes || !mounted) return;
    final navigator = Navigator.of(context);
    run(context, () async {
      await ref.read(libraryControllerProvider.notifier).deletePlaylist(id);
      await navigator.maybePop();
    });
  }

  void _download(List<UnifiedTrack> tracks) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(
      SnackBar(
        content: Text('Скачиваю ${tracks.length} — можно слушать дальше'),
      ),
    );
    run(context, () async {
      final saved = await downloadAll(ref, tracks);
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            saved == tracks.length
                ? 'Всё сохранено на устройстве'
                : 'Сохранено $saved из ${tracks.length}',
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final playlistId = widget.playlistId;
    if (widget.reloadOn case final source?) {
      ref.listen(source, (_, _) => _reload());
    }
    if (playlistId != null) {
      ref.listen(libraryControllerProvider, (_, next) {
        if (next.hasValue) _reload();
      });
    }
    final title = playlistId == null
        ? widget.title
        : ref
                  .watch(libraryControllerProvider)
                  .valueOrNull
                  ?.playlists
                  .where((p) => p.id == playlistId)
                  .firstOrNull
                  ?.name ??
              widget.title;
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final pad = wide ? 48.0 : 20.0;
    return Scaffold(
      backgroundColor: Pal.stage,
      body: FutureBuilder<List<UnifiedTrack>>(
        future: _tracks,
        builder: (context, snapshot) {
          // Keep the old list on screen while a reload is in flight.
          if (snapshot.hasData) _last = snapshot.data!;
          final tracks = snapshot.data ?? _last;
          final loading =
              snapshot.connectionState != ConnectionState.done && _last.isEmpty;
          final cover = tracks.isEmpty ? null : tracks.first;
          final accent = cover == null
              ? Pal.acid
              : ref.watch(trackAccentProvider(cover));
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Stack(
                  children: [
                    if (cover != null)
                      Positioned.fill(
                        child: Opacity(
                          opacity: .28,
                          child: ShaderMask(
                            shaderCallback: (rect) => const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.white, Colors.transparent],
                            ).createShader(rect),
                            blendMode: BlendMode.dstIn,
                            child: FittedBox(
                              fit: BoxFit.cover,
                              clipBehavior: Clip.hardEdge,
                              child: TrackArtwork(
                                track: cover,
                                size: 640,
                                borderRadius: 0,
                              ),
                            ),
                          ),
                        ),
                      ),
                    SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(pad, 12, pad, 28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
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
                                if (playlistId != null) ...[
                                  Knob(
                                    icon: Icons.edit_rounded,
                                    size: 44,
                                    tooltip: 'Переименовать',
                                    onTap: () => _rename(playlistId, title),
                                  ),
                                  const SizedBox(width: 10),
                                  Knob(
                                    icon: Icons.delete_outline_rounded,
                                    size: 44,
                                    tooltip: 'Удалить плейлист',
                                    onTap: () => _delete(playlistId, title),
                                  ),
                                ],
                              ],
                            ),
                            SizedBox(height: wide ? 120 : 72),
                            Text(
                              title,
                              style: Txt.display(
                                wide
                                    ? (title.length > 18 ? 64 : 88)
                                    : (title.length > 16 ? 34 : 46),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              [
                                ?widget.subtitle,
                                if (!loading)
                                  '${tracks.length} ${plural(tracks.length, 'трек', 'трека', 'треков')}',
                              ].join(' · '),
                              style: Txt.mono(13),
                            ),
                            const SizedBox(height: 24),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                Pill(
                                  large: true,
                                  active: true,
                                  accent: accent,
                                  icon: Icons.play_arrow_rounded,
                                  label: 'Слушать',
                                  onTap: tracks.isEmpty
                                      ? null
                                      : () => run(
                                          context,
                                          () => playList(ref, tracks),
                                        ),
                                ),
                                Pill(
                                  large: true,
                                  icon: Icons.shuffle_rounded,
                                  label: 'Вперемешку',
                                  onTap: tracks.isEmpty
                                      ? null
                                      : () => run(
                                          context,
                                          () => playList(
                                            ref,
                                            [...tracks]..shuffle(),
                                          ),
                                        ),
                                ),
                                Pill(
                                  large: true,
                                  icon: Icons.download_rounded,
                                  label: 'Скачать',
                                  onTap: tracks.isEmpty
                                      ? null
                                      : () => _download(tracks),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (loading)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(48),
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              else if (snapshot.hasError && tracks.isEmpty)
                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: pad),
                  sliver: SliverToBoxAdapter(
                    child: Hollow(
                      title: 'Не загрузилось',
                      body: '${snapshot.error}',
                      action: Pill(label: 'Ещё раз', onTap: _reload),
                    ),
                  ),
                )
              else if (tracks.isEmpty)
                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: pad),
                  sliver: const SliverToBoxAdapter(
                    child: Hollow(title: 'Здесь пока тихо'),
                  ),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(pad - 12, 0, pad - 12, 160),
                  sliver: SliverList.builder(
                    itemCount: tracks.length,
                    itemBuilder: (context, index) => TrackRow(
                      track: tracks[index],
                      index: index,
                      playlistId: playlistId,
                      onTap: () => run(
                        context,
                        () => playList(ref, tracks, index: index),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
