import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/app/providers.dart';
import 'package:resonance/core/database/app_database.dart';
import 'package:resonance/core/playback/media_browse_catalog.dart';
import 'package:resonance/core/playback/playback_service.dart';
import 'package:resonance/domain/entities/unified_track.dart';
import 'package:resonance/features/wave/wave_controller.dart';

/// [MediaBrowseSource] backed by the local library and the Wave controller.
final class AppMediaBrowseSource implements MediaBrowseSource {
  AppMediaBrowseSource(this._ref, this._service);

  final Ref _ref;
  final PlaybackService _service;

  AppDatabase get _database => _ref.read(appDatabaseProvider);

  @override
  Future<List<UnifiedTrack>> recentTracks() =>
      _database.loadStoredTracks(limit: 100);

  @override
  Future<List<LocalPlaylistSummary>> playlists() =>
      _database.loadLocalPlaylistSummaries();

  @override
  Future<List<UnifiedTrack>> playlistTracks(String playlistId) =>
      _database.loadLocalPlaylistTracks(playlistId);

  @override
  Future<List<UnifiedTrack>> favoriteTracks() => _database.loadFavoriteTracks();

  @override
  Future<void> startWave() async {
    final wave = _ref.read(waveControllerProvider.notifier);
    await wave.start(taste: await _database.loadFavoriteTracks());
  }

  @override
  Future<void> playTracks(List<UnifiedTrack> tracks, int startIndex) =>
      _service.setQueue(tracks, startIndex: startIndex, autoplay: true);
}
