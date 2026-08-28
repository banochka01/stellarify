import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/app/providers.dart';
import 'package:resonance/domain/entities/music_enums.dart';
import 'package:resonance/domain/entities/unified_track.dart';
import 'package:resonance/features/library/library_actions.dart';
import 'package:resonance/features/library/library_controller.dart';
import 'package:resonance/features/player/track_action.dart';
import 'package:resonance/shared/theme/resonance_theme.dart';
import 'package:resonance/shared/widgets/provider_badges.dart';
import 'package:resonance/shared/widgets/track_artwork.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _enabledProviders = {
    MusicProvider.yandex,
    MusicProvider.soundcloud,
    MusicProvider.youtube,
  };
  Timer? _debounce;
  List<UnifiedTrack> _tracks = const [];
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _scheduleSearch(String value) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () => _search(value));
  }

  Future<void> _search(String rawQuery) async {
    final query = rawQuery.trim();
    if (query.isEmpty || _enabledProviders.isEmpty) {
      setState(() {
        _tracks = const [];
        _loading = false;
        _error = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final registry = ref.read(providerRegistryProvider);
    final searches = <Future<_ProviderSearchResult>>[];
    for (final provider in _enabledProviders) {
      final catalog = registry.catalogFor(provider);
      if (catalog != null) {
        searches.add(
          catalog
              .searchTracks(query, limit: 20)
              .then(_ProviderSearchResult.success)
              .onError(_ProviderSearchResult.failure),
        );
      }
    }
    try {
      final batches = await Future.wait(searches);
      if (!mounted || query != _controller.text.trim()) return;
      final tracks = batches
          .expand((batch) => batch.tracks)
          .toList(growable: false);
      final failures = batches.where((batch) => batch.error != null).toList();
      setState(() {
        _tracks = tracks;
        _loading = false;
        _error =
            tracks.isEmpty &&
                failures.isNotEmpty &&
                failures.length == batches.length
            ? _cleanError(failures.first.error!)
            : null;
      });
    } catch (error) {
      if (!mounted || query != _controller.text.trim()) return;
      setState(() {
        _tracks = const [];
        _loading = false;
        _error = _cleanError(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 650;
    final query = _controller.text.trim();
    return CustomScrollView(
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
              const Row(
                children: [
                  Text(
                    'ПОИСК',
                    style: TextStyle(
                      color: ResonanceColors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.8,
                    ),
                  ),
                  Spacer(),
                  _LivePill(),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                query.isEmpty ? 'НАЙТИ МУЗЫКУ' : query.toUpperCase(),
                maxLines: compact ? 2 : 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontSize: compact ? 42 : 66,
                  height: .9,
                  letterSpacing: compact ? -2 : -3.2,
                ),
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _controller,
                autofocus: !compact,
                textInputAction: TextInputAction.search,
                onChanged: _scheduleSearch,
                onSubmitted: _search,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _controller.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _controller.clear();
                            _search('');
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                  hintText: 'Трек, артист или альбом',
                ),
              ),
              const SizedBox(height: 18),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterPill(
                      label: 'Все',
                      selected: _enabledProviders.length == 3,
                      onTap: _setAllProviders,
                    ),
                    const SizedBox(width: 8),
                    for (final provider in [
                      MusicProvider.yandex,
                      MusicProvider.soundcloud,
                      MusicProvider.youtube,
                    ]) ...[
                      _FilterPill(
                        label: _providerName(provider),
                        provider: provider,
                        selected: _enabledProviders.contains(provider),
                        onTap: () => _toggleProvider(provider),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 38),
              if (_loading) const LinearProgressIndicator(minHeight: 2),
              if (_error != null) _SearchMessage.error(_error!),
              if (!_loading && _error == null && _tracks.isEmpty)
                _SearchMessage.empty(
                  hasQuery: _controller.text.trim().isNotEmpty,
                ),
              if (_tracks.isNotEmpty) ...[
                Row(
                  children: [
                    Text(
                      'РЕЗУЛЬТАТЫ: ${_tracks.length}',
                      style: const TextStyle(
                        color: ResonanceColors.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const Spacer(),
                    const Text(
                      'Сначала лучшее',
                      style: TextStyle(
                        color: ResonanceColors.muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                for (final track in _tracks) _TrackResult(track: track),
              ],
            ],
          ),
        ),
      ],
    );
  }

  void _setAllProviders() {
    setState(() {
      _enabledProviders
        ..clear()
        ..addAll([
          MusicProvider.yandex,
          MusicProvider.soundcloud,
          MusicProvider.youtube,
        ]);
    });
    _search(_controller.text);
  }

  void _toggleProvider(MusicProvider provider) {
    setState(() {
      if (!_enabledProviders.remove(provider)) _enabledProviders.add(provider);
    });
    _search(_controller.text);
  }

  String _providerName(MusicProvider provider) => switch (provider) {
    MusicProvider.yandex => 'Яндекс',
    MusicProvider.soundcloud => 'SoundCloud',
    MusicProvider.youtube => 'YouTube',
  };

  String _cleanError(Object error) =>
      error.toString().replaceFirst(RegExp(r'^\w+: '), '');
}

final class _ProviderSearchResult {
  const _ProviderSearchResult(this.tracks, this.error);

  factory _ProviderSearchResult.success(List<UnifiedTrack> tracks) =>
      _ProviderSearchResult(tracks, null);

  factory _ProviderSearchResult.failure(Object error, StackTrace _) =>
      _ProviderSearchResult(const [], error);

  final List<UnifiedTrack> tracks;
  final Object? error;
}

class _TrackResult extends ConsumerWidget {
  const _TrackResult({required this.track});

  final UnifiedTrack track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = track.preferredProvider ?? track.sources.first.provider;
    final favorite =
        ref
            .watch(libraryControllerProvider)
            .valueOrNull
            ?.favoriteIds
            .contains(track.id) ??
        false;
    return Padding(
      padding: EdgeInsets.zero,
      child: ListTile(
        minTileHeight: 70,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10),
        shape: const Border(top: BorderSide(color: ResonanceColors.border)),
        leading: TrackArtwork(track: track, size: 48, borderRadius: 3),
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
            ProviderBadge(provider: provider, compact: true),
            const SizedBox(width: 4),
            PopupMenuButton<String>(
              tooltip: 'Действия',
              onSelected: (value) {
                if (value == 'favorite') {
                  unawaited(
                    ref
                        .read(libraryControllerProvider.notifier)
                        .toggleFavorite(track),
                  );
                } else if (value == 'playlist') {
                  unawaited(showAddToPlaylistDialog(context, ref, track));
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'favorite',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      favorite
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: favorite ? ResonanceColors.primary : null,
                    ),
                    title: Text(
                      favorite ? 'Убрать из избранного' : 'В избранное',
                    ),
                  ),
                ),
                const PopupMenuItem(
                  value: 'playlist',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.playlist_add_rounded),
                    title: Text('Добавить в плейлист'),
                  ),
                ),
              ],
            ),
            IconButton(
              tooltip: 'Воспроизвести',
              onPressed: () => unawaited(playTrackOrOpenOfficial(ref, track)),
              icon: const Icon(
                Icons.play_arrow_rounded,
                color: ResonanceColors.primary,
              ),
            ),
          ],
        ),
        onTap: () => unawaited(playTrackOrOpenOfficial(ref, track)),
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.provider,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final MusicProvider? provider;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      selected: selected,
      onSelected: (_) => onTap(),
      avatar: provider == null
          ? const Icon(Icons.grid_view_rounded, size: 16)
          : ProviderBadge(provider: provider!, compact: true),
      label: Text(label),
    );
  }
}

class _LivePill extends StatelessWidget {
  const _LivePill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border.all(color: ResonanceColors.border),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: 6,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: ResonanceColors.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
          SizedBox(width: 8),
          Text(
            '2 ИСТОЧНИКА',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _SearchMessage extends StatelessWidget {
  const _SearchMessage(this.icon, this.title, this.subtitle);

  factory _SearchMessage.empty({required bool hasQuery}) => _SearchMessage(
    hasQuery ? Icons.search_off_rounded : Icons.travel_explore_rounded,
    hasQuery ? 'Ничего не найдено' : 'Начните с любимого трека',
    hasQuery
        ? 'Попробуйте другой запрос или источник.'
        : 'Результаты Яндекса и SoundCloud появятся здесь.',
  );

  factory _SearchMessage.error(String error) =>
      _SearchMessage(Icons.key_off_rounded, 'Источник недоступен', error);

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 70),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 46, color: ResonanceColors.muted),
            const SizedBox(height: 14),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: ResonanceColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}
