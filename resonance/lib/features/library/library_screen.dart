import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/app/providers.dart';
import 'package:resonance/core/database/app_database.dart';
import 'package:resonance/domain/entities/music_enums.dart';
import 'package:resonance/domain/entities/unified_track.dart';
import 'package:resonance/features/library/library_actions.dart';
import 'package:resonance/features/library/library_controller.dart';
import 'package:resonance/features/library/library_transfer_dialog.dart';
import 'package:resonance/features/player/track_action.dart';
import 'package:resonance/shared/theme/resonance_theme.dart';
import 'package:resonance/shared/widgets/track_artwork.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(libraryControllerProvider);
    final compact = MediaQuery.sizeOf(context).width < 650;
    final heading = Column(
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
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            'Медиатека',
            maxLines: 1,
            style: Theme.of(context).textTheme.displaySmall,
          ),
        ),
      ],
    );
    final actions = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton.icon(
          onPressed: () => _transferLibrary(context, ref),
          icon: const Icon(Icons.auto_awesome_rounded),
          label: Text(compact ? 'Перенести' : 'Перенести медиатеку'),
        ),
        OutlinedButton.icon(
          onPressed: () => _importPlaylist(context, ref),
          icon: const Icon(Icons.link_rounded),
          label: Text(compact ? 'Ссылка' : 'Импорт по ссылке'),
        ),
        OutlinedButton.icon(
          onPressed: () => _createPlaylist(context, ref),
          icon: const Icon(Icons.add_rounded),
          label: Text(compact ? 'Создать' : 'Новый плейлист'),
        ),
      ],
    );
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
                if (compact)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [heading, const SizedBox(height: 18), actions],
                  )
                else
                  Row(
                    children: [
                      Expanded(child: heading),
                      actions,
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

  Future<void> _transferLibrary(BuildContext context, WidgetRef ref) async {
    final imported = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (_) => const LibraryTransferDialog(),
    );
    if (imported == true) {
      await ref.read(libraryControllerProvider.notifier).refresh();
    }
  }

  Future<void> _createPlaylist(BuildContext context, WidgetRef ref) async {
    final name = await showCreatePlaylistDialog(context);
    if (name == null || !context.mounted) return;
    await ref.read(libraryControllerProvider.notifier).createPlaylist(name);
  }

  Future<void> _importPlaylist(BuildContext context, WidgetRef ref) async {
    final url = await showDialog<String>(
      context: context,
      builder: (dialogContext) => const ImportPlaylistDialog(),
    );
    if (url == null || url.isEmpty || !context.mounted) return;
    // Диалог загрузки открывается на ROOT-навигаторе (useRootNavigator),
    // а контекст экрана библиотеки принадлежит навигатору ShellRoute:
    // Navigator.pop(context) попнул бы единственную страницу shell'а и
    // валил go_router (чёрный экран). Закрываем диалог через root.
    final rootNavigator = Navigator.of(context, rootNavigator: true);
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
      rootNavigator.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '«${imported.name}»: перенесено ${imported.tracks.length} треков',
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      rootNavigator.pop();
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
    final albums = <String, UnifiedTrack>{};
    final artists = <String, int>{};
    for (final track in state.tracks) {
      final album = track.album?.trim();
      if (album != null && album.isNotEmpty) {
        albums.putIfAbsent(album, () => track);
      }
      artists[track.artist] = (artists[track.artist] ?? 0) + 1;
    }
    final topArtists = artists.entries.toList()
      ..sort((left, right) => right.value.compareTo(left.value));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LibraryHero(
          state: state,
          albumCount: albums.length,
          artistCount: artists.length,
        ),
        if (state.tracks.isNotEmpty) ...[
          const SizedBox(height: 42),
          _SectionHeader(
            title: 'Недавно добавлено',
            count: state.tracks.length,
            icon: Icons.bolt_rounded,
          ),
          const SizedBox(height: 16),
          _TrackShelf(tracks: state.tracks.take(12).toList(growable: false)),
        ],
        if (albums.isNotEmpty) ...[
          const SizedBox(height: 42),
          _SectionHeader(
            title: 'Альбомы',
            count: albums.length,
            icon: Icons.album_rounded,
          ),
          const SizedBox(height: 16),
          _AlbumShelf(albums: albums.entries.take(10).toList(growable: false)),
        ],
        if (topArtists.isNotEmpty) ...[
          const SizedBox(height: 42),
          _SectionHeader(
            title: 'Исполнители',
            count: artists.length,
            icon: Icons.graphic_eq_rounded,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: [
              for (final artist in topArtists.take(14))
                Chip(
                  avatar: CircleAvatar(
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: .2),
                    child: Text(artist.key.characters.first.toUpperCase()),
                  ),
                  label: Text('${artist.key} · ${artist.value}'),
                ),
            ],
          ),
        ],
        const SizedBox(height: 42),
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

class _LibraryHero extends ConsumerWidget {
  const _LibraryHero({
    required this.state,
    required this.albumCount,
    required this.artistCount,
  });

  final LibraryState state;
  final int albumCount;
  final int artistCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final compact = MediaQuery.sizeOf(context).width < 720;
    final intro = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ЕДИНАЯ МЕДИАТЕКА',
          style: TextStyle(
            color: ResonanceColors.primary,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.7,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          state.tracks.isEmpty
              ? 'Здесь поселится\nтвоя музыка'
              : '${state.tracks.length} треков.\nОдин дом.',
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
            fontSize: compact ? 36 : 46,
            height: .98,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          state.tracks.isEmpty
              ? 'Перенеси коллекцию из сервиса или добавь первый плейлист.'
              : '${state.playlists.length} плейлистов · $albumCount альбомов · $artistCount исполнителей',
          style: const TextStyle(color: ResonanceColors.muted, height: 1.45),
        ),
      ],
    );
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 22 : 30),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x55FF5A36)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF22100C), Color(0xFF11100F), Color(0xFF0B0B0B)],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 32,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: Flex(
        direction: compact ? Axis.vertical : Axis.horizontal,
        crossAxisAlignment: compact
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          if (compact) intro else Expanded(child: intro),
          SizedBox(width: compact ? 0 : 28, height: compact ? 24 : 0),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _HeroMetric(
                icon: Icons.favorite_rounded,
                value: '${state.favorites.length}',
                label: 'любимых',
              ),
              _HeroMetric(
                icon: Icons.queue_music_rounded,
                value: '${state.playlists.length}',
                label: 'плейлистов',
              ),
              if (state.tracks.isNotEmpty)
                IconButton.filled(
                  tooltip: 'Перемешать всю медиатеку',
                  onPressed: () => unawaited(
                    ref.read(playbackServiceProvider.future).then((
                      service,
                    ) async {
                      final tracks = [...state.tracks]..shuffle();
                      await service.setQueue(tracks, autoplay: true);
                    }),
                  ),
                  icon: const Icon(Icons.shuffle_rounded),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.icon,
    required this.value,
    required this.label,
  });
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    width: 104,
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: const Color(0xAA0A0A0A),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: ResonanceColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: ResonanceColors.primary),
        const SizedBox(height: 14),
        Text(
          value,
          style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
        ),
        Text(
          label,
          style: const TextStyle(color: ResonanceColors.muted, fontSize: 10),
        ),
      ],
    ),
  );
}

class _TrackShelf extends ConsumerWidget {
  const _TrackShelf({required this.tracks});
  final List<UnifiedTrack> tracks;

  @override
  Widget build(BuildContext context, WidgetRef ref) => SizedBox(
    height: 208,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: tracks.length,
      separatorBuilder: (_, _) => const SizedBox(width: 13),
      itemBuilder: (context, index) {
        final track = tracks[index];
        return SizedBox(
          width: 144,
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: () => unawaited(playTrackOrOpenOfficial(ref, track)),
              borderRadius: BorderRadius.circular(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TrackArtwork(track: track, size: 144, borderRadius: 14),
                  const SizedBox(height: 10),
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    track.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: ResonanceColors.muted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

class _AlbumShelf extends StatelessWidget {
  const _AlbumShelf({required this.albums});
  final List<MapEntry<String, UnifiedTrack>> albums;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 112,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: albums.length,
      separatorBuilder: (_, _) => const SizedBox(width: 11),
      itemBuilder: (context, index) {
        final album = albums[index];
        return Container(
          width: 250,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: ResonanceColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ResonanceColors.border),
          ),
          child: Row(
            children: [
              TrackArtwork(track: album.value, size: 86, borderRadius: 10),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      album.key,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      album.value.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: ResonanceColors.muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
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

class ImportPlaylistDialog extends StatefulWidget {
  const ImportPlaylistDialog({super.key});

  @override
  State<ImportPlaylistDialog> createState() => _ImportPlaylistDialogState();
}

class _ImportPlaylistDialogState extends State<ImportPlaylistDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Перенести плейлист'),
      content: SizedBox(
        width: 520,
        child: TextField(
          controller: _controller,
          autofocus: true,
          keyboardType: TextInputType.url,
          onSubmitted: (value) => Navigator.pop(context, value.trim()),
          decoration: const InputDecoration(
            labelText: 'Ссылка на плейлист',
            hintText: 'https://music.yandex.ru/users/…/playlists/…',
            prefixIcon: Icon(Icons.link_rounded),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: const Text('Перенести'),
        ),
      ],
    );
  }
}
