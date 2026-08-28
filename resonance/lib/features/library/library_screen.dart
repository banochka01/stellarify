import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/app/providers.dart';
import 'package:resonance/core/database/app_database.dart';
import 'package:resonance/domain/entities/music_enums.dart';
import 'package:resonance/domain/entities/unified_track.dart';
import 'package:resonance/features/library/library_actions.dart';
import 'package:resonance/features/library/library_controller.dart';
import 'package:resonance/features/player/track_action.dart';
import 'package:resonance/shared/theme/resonance_theme.dart';
import 'package:resonance/shared/widgets/track_artwork.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(libraryControllerProvider);
    final compact = MediaQuery.sizeOf(context).width < 650;
    return RefreshIndicator(
      onRefresh: () => ref.read(libraryControllerProvider.notifier).refresh(),
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              compact ? 18 : 38,
              compact ? 24 : 34,
              compact ? 18 : 38,
              130,
            ),
            sliver: SliverList.list(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ВАША КОЛЛЕКЦИЯ',
                            style: TextStyle(
                              color: ResonanceColors.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.8,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Медиатека',
                            style: Theme.of(context).textTheme.displaySmall,
                          ),
                        ],
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _importPlaylist(context, ref),
                          icon: const Icon(Icons.link_rounded),
                          label: Text(compact ? 'Импорт' : 'Импорт по ссылке'),
                        ),
                        FilledButton.icon(
                          onPressed: () => _createPlaylist(context, ref),
                          icon: const Icon(Icons.add_rounded),
                          label: Text(compact ? 'Создать' : 'Новый плейлист'),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 34),
                library.when(
                  loading: () => const LinearProgressIndicator(minHeight: 2),
                  error: (error, _) => _ErrorState(
                    message: error.toString(),
                    onRetry: () =>
                        ref.read(libraryControllerProvider.notifier).refresh(),
                  ),
                  data: (state) => _LibraryContent(state: state),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createPlaylist(BuildContext context, WidgetRef ref) async {
    final name = await showCreatePlaylistDialog(context);
    if (name == null || !context.mounted) return;
    await ref.read(libraryControllerProvider.notifier).createPlaylist(name);
  }

  Future<void> _importPlaylist(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Перенести плейлист'),
        content: SizedBox(
          width: 520,
          child: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'Ссылка Яндекс Музыки или YouTube',
              hintText: 'https://music.yandex.ru/users/…/playlists/…',
              prefixIcon: Icon(Icons.link_rounded),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Перенести'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (url == null || url.isEmpty || !context.mounted) return;
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      ),
    );
    try {
      final imported = await ref
          .read(playlistImportServiceProvider)
          .importUrl(url);
      await ref
          .read(libraryControllerProvider.notifier)
          .importPlaylist(imported);
      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '«${imported.name}»: перенесено ${imported.tracks.length} треков',
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst(RegExp(r'^\w+: '), '')),
        ),
      );
    }
  }
}

class _LibraryContent extends ConsumerWidget {
  const _LibraryContent({required this.state});

  final LibraryState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'Избранное',
          count: state.favorites.length,
          icon: Icons.favorite_rounded,
        ),
        const SizedBox(height: 14),
        if (state.favorites.isEmpty)
          const _EmptyCard(
            icon: Icons.favorite_border_rounded,
            title: 'Сердца пока пусты',
            subtitle: 'Нажмите на сердце у трека — он сохранится здесь.',
          )
        else
          ...state.favorites.map((track) => _FavoriteTrack(track: track)),
        const SizedBox(height: 38),
        _SectionHeader(
          title: 'Плейлисты',
          count: state.playlists.length,
          icon: Icons.playlist_play_rounded,
        ),
        const SizedBox(height: 14),
        if (state.playlists.isEmpty)
          const _EmptyCard(
            icon: Icons.queue_music_rounded,
            title: 'Соберите первый плейлист',
            subtitle: 'Создайте подборку и добавляйте треки из поиска.',
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth >= 900
                  ? (constraints.maxWidth - 24) / 3
                  : constraints.maxWidth >= 560
                  ? (constraints.maxWidth - 12) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final playlist in state.playlists)
                    SizedBox(
                      width: width,
                      child: _PlaylistCard(playlist: playlist),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }
}

class _FavoriteTrack extends ConsumerWidget {
  const _FavoriteTrack({required this.track});

  final UnifiedTrack track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: ResonanceColors.border)),
      ),
      child: ListTile(
        minTileHeight: 72,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        leading: TrackArtwork(track: track, size: 50, borderRadius: 4),
        title: Text(
          track.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          track.artist,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: ResonanceColors.muted),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Добавить в плейлист',
              onPressed: () => showAddToPlaylistDialog(context, ref, track),
              icon: const Icon(Icons.playlist_add_rounded),
            ),
            IconButton(
              tooltip: 'Убрать из избранного',
              onPressed: () => unawaited(
                ref
                    .read(libraryControllerProvider.notifier)
                    .toggleFavorite(track),
              ),
              icon: const Icon(
                Icons.favorite_rounded,
                color: ResonanceColors.primary,
              ),
            ),
            IconButton(
              tooltip: 'Воспроизвести',
              onPressed: () => unawaited(playTrackOrOpenOfficial(ref, track)),
              icon: const Icon(Icons.play_arrow_rounded),
            ),
          ],
        ),
        onTap: () => unawaited(playTrackOrOpenOfficial(ref, track)),
      ),
    );
  }
}

class _PlaylistCard extends ConsumerWidget {
  const _PlaylistCard({required this.playlist});

  final LocalPlaylistSummary playlist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: ResonanceColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: ResonanceColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openPlaylist(context, ref),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              const Icon(
                Icons.queue_music_rounded,
                size: 32,
                color: ResonanceColors.primary,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      playlist.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${playlist.trackCount} треков',
                      style: const TextStyle(
                        color: ResonanceColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'delete') {
                    unawaited(
                      ref
                          .read(libraryControllerProvider.notifier)
                          .deletePlaylist(playlist.id),
                    );
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'delete', child: Text('Удалить')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openPlaylist(BuildContext context, WidgetRef ref) async {
    final tracks = await ref
        .read(libraryControllerProvider.notifier)
        .loadPlaylistTracks(playlist.id);
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * .68,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        playlist.name,
                        style: Theme.of(sheetContext).textTheme.headlineSmall,
                      ),
                    ),
                    if (tracks.isNotEmpty)
                      FilledButton.icon(
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          if (tracks.first.preferredProvider ==
                              MusicProvider.youtube) {
                            unawaited(
                              playTrackOrOpenOfficial(ref, tracks.first),
                            );
                          } else {
                            unawaited(
                              ref
                                  .read(playbackServiceProvider.future)
                                  .then(
                                    (service) => service.setQueue(
                                      tracks,
                                      autoplay: true,
                                    ),
                                  ),
                            );
                          }
                        },
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('Слушать'),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: tracks.isEmpty
                    ? const Center(child: Text('В плейлисте пока нет треков'))
                    : ListView.builder(
                        itemCount: tracks.length,
                        itemBuilder: (context, index) => ListTile(
                          leading: TrackArtwork(
                            track: tracks[index],
                            size: 44,
                            borderRadius: 4,
                          ),
                          title: Text(tracks[index].title),
                          subtitle: Text(tracks[index].artist),
                          onTap: () {
                            Navigator.pop(sheetContext);
                            final track = tracks[index];
                            if (track.preferredProvider ==
                                MusicProvider.youtube) {
                              unawaited(playTrackOrOpenOfficial(ref, track));
                            } else {
                              unawaited(
                                ref
                                    .read(playbackServiceProvider.future)
                                    .then(
                                      (service) => service.setQueue(
                                        tracks,
                                        startIndex: index,
                                        autoplay: true,
                                      ),
                                    ),
                              );
                            }
                          },
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.count,
    required this.icon,
  });

  final String title;
  final int count;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 19, color: ResonanceColors.primary),
        const SizedBox(width: 9),
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(width: 9),
        Text('$count', style: const TextStyle(color: ResonanceColors.muted)),
      ],
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: ResonanceColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ResonanceColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 28, color: ResonanceColors.muted),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(color: ResonanceColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded, size: 40),
          const SizedBox(height: 10),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Повторить')),
        ],
      ),
    );
  }
}
