import 'package:resonance/domain/entities/music_enums.dart';
import 'package:resonance/domain/entities/provider_capabilities.dart';
import 'package:resonance/domain/entities/unified_track.dart';

abstract interface class MusicCatalogProvider {
  MusicProvider get provider;

  ProviderCapabilities get capabilities;

  Future<List<UnifiedTrack>> searchTracks(
    String query, {
    int limit = 20,
    String? cursor,
  });

  Future<UnifiedTrack?> getTrack(String externalId);

  Future<List<UnifiedTrack>> getPlaylistTracks(String playlistId);

  Future<UnifiedTrack?> resolvePublicUrl(Uri url);
}
