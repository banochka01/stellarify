import 'package:dio/dio.dart';
import 'package:resonance/core/errors/app_exception.dart';
import 'package:resonance/domain/entities/music_enums.dart';
import 'package:resonance/domain/entities/provider_capabilities.dart';
import 'package:resonance/domain/entities/track_source.dart';
import 'package:resonance/domain/entities/unified_track.dart';
import 'package:resonance/domain/providers/music_catalog_provider.dart';
import 'package:resonance/domain/repositories/secure_token_repository.dart';

class BackendYouTubeProvider implements MusicCatalogProvider {
  BackendYouTubeProvider(this._dio, this._baseUri, this._tokens);

  final Dio _dio;
  final Uri Function() _baseUri;
  final SecureTokenRepository _tokens;

  @override
  MusicProvider get provider => MusicProvider.youtube;

  @override
  ProviderCapabilities get capabilities => const ProviderCapabilities(
    supportsSearch: true,
    supportsAuthentication: true,
  );

  @override
  Future<List<UnifiedTrack>> searchTracks(
    String query, {
    int limit = 20,
    String? cursor,
  }) async {
    final token = await _tokens.read(MusicProvider.youtube);
    try {
      final response = await _dio.getUri<Map<String, dynamic>>(
        _baseUri()
            .resolve('/api/v1/catalog/search')
            .replace(
              queryParameters: {
                'provider': 'youtube',
                'q': query.trim(),
                'limit': '${limit.clamp(1, 50)}',
              },
            ),
        options: token?.isNotEmpty == true
            ? Options(headers: {'X-Provider-Token': token})
            : null,
      );
      final tracks = response.data?['tracks'];
      if (tracks is! List) throw const FormatException('Missing tracks');
      return tracks
          .map(
            (item) =>
                youtubeTrackFromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(growable: false);
    } on DioException catch (error) {
      throw ProviderUnavailableException(
        error.response?.statusCode == 401
            ? 'Добавьте YouTube Data API key в настройках.'
            : 'YouTube Data API недоступен.',
        cause: error,
      );
    }
  }

  @override
  Future<UnifiedTrack?> getTrack(String externalId) async => null;

  @override
  Future<List<UnifiedTrack>> getPlaylistTracks(String playlistId) async =>
      const [];

  @override
  Future<UnifiedTrack?> resolvePublicUrl(Uri url) async => null;
}

UnifiedTrack youtubeTrackFromJson(Map<String, dynamic> json) {
  final id = json['id'] as String?;
  final title = json['title'] as String?;
  final artist = json['artist'] as String?;
  final externalUrl = Uri.tryParse(json['externalUrl'] as String? ?? '');
  if (id == null ||
      title == null ||
      artist == null ||
      externalUrl == null ||
      !externalUrl.isScheme('https')) {
    throw const FormatException('Invalid YouTube track');
  }
  final artwork = Uri.tryParse(json['artworkUrl'] as String? ?? '');
  return UnifiedTrack(
    id: 'youtube:$id',
    title: title,
    normalizedTitle: title.trim().toLowerCase(),
    artist: artist,
    normalizedArtist: artist.trim().toLowerCase(),
    artworkUrl: artwork?.isScheme('https') == true ? artwork : null,
    preferredProvider: MusicProvider.youtube,
    sources: [
      TrackSource(
        provider: MusicProvider.youtube,
        externalId: id,
        externalUrl: externalUrl,
      ),
    ],
  );
}
