import 'dart:async';

import 'package:audio_service/audio_service.dart' as audio_service;
import 'package:resonance/core/database/app_database.dart';
import 'package:resonance/domain/entities/unified_track.dart';

/// Data needed by car/watch media browsers (Android Auto, CarPlay bridge).
abstract interface class MediaBrowseSource {
  Future<List<UnifiedTrack>> recentTracks();
  Future<List<LocalPlaylistSummary>> playlists();
  Future<List<UnifiedTrack>> playlistTracks(String playlistId);
  Future<List<UnifiedTrack>> favoriteTracks();
  Future<void> startWave();
  Future<void> playTracks(List<UnifiedTrack> tracks, int startIndex);
}

/// Browsing tree exposed through audio_service's MediaBrowserService:
/// root → Недавнее / Плейлисты / Волна / Миксы.
final class MediaBrowseCatalog {
  MediaBrowseCatalog(this._source);

  static const recentId = 'resonance:recent';
  static const playlistsId = 'resonance:playlists';
  static const waveId = 'resonance:wave';
  static const mixesId = 'resonance:mixes';
  static const favoritesMixId = 'resonance:mix:favorites';
  static const libraryMixId = 'resonance:mix:library';
  static const _playlistPrefix = 'resonance:playlist:';
  static const _trackSeparator = '|track:';
  static const _maxItems = 100;

  final MediaBrowseSource _source;

  Future<List<audio_service.MediaItem>> children(String parentId) async {
    switch (parentId) {
      case audio_service.AudioService.browsableRootId:
        return const [
          audio_service.MediaItem(
            id: recentId,
            title: 'Недавнее',
            playable: false,
          ),
          audio_service.MediaItem(
            id: playlistsId,
            title: 'Плейлисты',
            playable: false,
          ),
          audio_service.MediaItem(
            id: waveId,
            title: 'Волна',
            playable: true,
          ),
          audio_service.MediaItem(
            id: mixesId,
            title: 'Миксы',
            playable: false,
          ),
        ];
      case audio_service.AudioService.recentRootId:
      case recentId:
        return _tracks(recentId, await _source.recentTracks());
      case playlistsId:
        final playlists = await _source.playlists();
        return [
          for (final playlist in playlists.take(_maxItems))
            audio_service.MediaItem(
              id: '$_playlistPrefix${playlist.id}',
              title: playlist.name,
              album: '${playlist.trackCount} треков',
              playable: false,
            ),
        ];
      case mixesId:
        return const [
          audio_service.MediaItem(
            id: favoritesMixId,
            title: 'Избранное',
            playable: true,
          ),
          audio_service.MediaItem(
            id: libraryMixId,
            title: 'Микс библиотеки',
            playable: true,
          ),
        ];
    }
    if (parentId.startsWith(_playlistPrefix)) {
      final playlistId = parentId.substring(_playlistPrefix.length);
      return _tracks(parentId, await _source.playlistTracks(playlistId));
    }
    return const [];
  }

  Future<void> playFromMediaId(String mediaId) async {
    switch (mediaId) {
      case waveId:
        return _source.startWave();
      case favoritesMixId:
        final tracks = await _source.favoriteTracks();
        return _playShuffled(tracks);
      case libraryMixId:
        final tracks = await _source.recentTracks();
        return _playShuffled(tracks);
    }
    final separator = mediaId.indexOf(_trackSeparator);
    if (separator < 0) return;
    final parentId = mediaId.substring(0, separator);
    final trackId = mediaId.substring(separator + _trackSeparator.length);
    final tracks = switch (parentId) {
      recentId => await _source.recentTracks(),
      _ when parentId.startsWith(_playlistPrefix) =>
        await _source.playlistTracks(
          parentId.substring(_playlistPrefix.length),
        ),
      _ => const <UnifiedTrack>[],
    };
    final limited = tracks.take(_maxItems).toList(growable: false);
    final index = limited.indexWhere((track) => track.id == trackId);
    if (index < 0) return;
    await _source.playTracks(limited, index);
  }

  Future<void> _playShuffled(List<UnifiedTrack> tracks) async {
    if (tracks.isEmpty) return;
    final shuffled = tracks.take(_maxItems).toList()..shuffle();
    await _source.playTracks(shuffled, 0);
  }

  List<audio_service.MediaItem> _tracks(
    String parentId,
    List<UnifiedTrack> tracks,
  ) => [
    for (final track in tracks.take(_maxItems))
      audio_service.MediaItem(
        id: '$parentId$_trackSeparator${track.id}',
        title: track.title,
        artist: track.artist,
        album: track.album,
        duration: track.duration,
        artUri: track.artworkUrl,
        playable: true,
      ),
  ];
}
