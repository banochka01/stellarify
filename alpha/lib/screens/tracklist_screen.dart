import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/domain/entities/unified_track.dart';
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
    super.key,
  });

  final String title;
  final String? subtitle;
  final Future<List<UnifiedTrack>> Function() load;

  static Route<void> route({
    required String title,
    required Future<List<UnifiedTrack>> Function() load,
    String? subtitle,
  }) => PageRouteBuilder<void>(
    transitionDuration: Motion.base,
    reverseTransitionDuration: Motion.base,
    pageBuilder: (_, _, _) =>
        TracklistScreen(title: title, subtitle: subtitle, load: load),
    transitionsBuilder: (_, animation, _, child) {
      final curved = CurvedAnimation(parent: animation, curve: Motion.curve);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(.06, 0),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );

  @override
  ConsumerState<TracklistScreen> createState() => _TracklistScreenState();
}

class _TracklistScreenState extends ConsumerState<TracklistScreen> {
  late Future<List<UnifiedTrack>> _tracks = widget.load();

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final pad = wide ? 48.0 : 20.0;
    return Scaffold(
      backgroundColor: Pal.stage,
      body: FutureBuilder<List<UnifiedTrack>>(
        future: _tracks,
        builder: (context, snapshot) {
          final tracks = snapshot.data ?? const <UnifiedTrack>[];
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
                            Knob(
                              icon: Icons.arrow_back_rounded,
                              size: 44,
                              tooltip: 'Назад',
                              onTap: () => Navigator.of(context).maybePop(),
                            ),
                            SizedBox(height: wide ? 120 : 72),
                            Text(
                              widget.title,
                              style: Txt.display(wide ? 88 : 46),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              [
                                ?widget.subtitle,
                                if (snapshot.hasData)
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
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (snapshot.connectionState != ConnectionState.done)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(48),
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              else if (snapshot.hasError)
                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: pad),
                  sliver: SliverToBoxAdapter(
                    child: Hollow(
                      title: 'Не загрузилось',
                      body: '${snapshot.error}',
                      action: Pill(
                        label: 'Ещё раз',
                        onTap: () => setState(() => _tracks = widget.load()),
                      ),
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
