import 'package:dio/dio.dart';
import 'package:resonance/core/errors/app_exception.dart';
import 'package:resonance/domain/entities/music_enums.dart';
import 'package:resonance/domain/entities/provider_capabilities.dart';
import 'package:resonance/domain/entities/resolved_audio_source.dart';
import 'package:resonance/domain/entities/track_source.dart';
import 'package:resonance/domain/entities/unified_track.dart';
import 'package:resonance/domain/providers/audio_source_resolver.dart';
import 'package:resonance/domain/providers/music_catalog_provider.dart';
import 'package:resonance/domain/repositories/secure_token_repository.dart';

/// Catalog and audio resolver for providers that work entirely through the
/// Resonance backend catalog/playback endpoints and authenticate with an
/// optional per-user token sent as `X-Provider-Token` (Spotify, VK Music).
final class BackendTokenProvider
    implements MusicCatalogProvider, AudioSourceResolver {
  BackendTokenProvider(this.provider, this._dio, this._baseUri, this._tokens);

  final Dio _dio;
  final Uri Function() _baseUri;
  final SecureTokenRepository _tokens;

  @override
  final MusicProvider provider;

  @override
  ProviderCapabilities get capabilities => const ProviderCapabilities(
    supportsSearch: true,
    supportsAuthentication: true,
    supportsDirectResolution: true,
  );

  @override
  Future<List<UnifiedTrack>> searchTracks(
    String query, {
    int limit = 20,
    String? cursor,
  }) async {
    final value = query.trim();
    if (value.isEmpty) return const [];
    final token = await _tokens.read(provider);
    try {
      final uri = _baseUri()
          .resolve('/api/v1/catalog/search')
          .replace(
            queryParameters: {
              'provider': provider.name,
              'q': value,
              'limit': '${limit.clamp(1, 50)}',
            },
          );
      final response = await _dio.getUri<Map<String, dynamic>>(
        uri,
        options: _tokenOptions(token),
      );
      final tracks = response.data?['tracks'];
      if (tracks is! List) throw const FormatException('Missing tracks list');
      return tracks
          .map(
            (item) => tokenTrackFromJson(
              provider,
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false);
    } on DioException catch (error) {
      throw ProviderUnavailableException(
        error.response?.statusCode == 401
            ? 'Подключите действующий токен ${_providerTitle(provider)}.'
            : 'Сервер каталога ${_providerTitle(provider)} недоступен.',
        cause: error,
      );
    } on FormatException catch (error) {
      throw ProviderUnavailableException(
        'Сервер каталога вернул некорректный ответ.',
        cause: error,
      );
    }
  }

  @override
  Future<ResolvedAudioSource> resolve(
    TrackSource source, {
    AudioQuality quality = AudioQuality.high,
  }) async {
    final token = await _tokens.read(provider);
    try {
      final response = await _dio.postUri<Map<String, dynamic>>(
        _baseUri().resolve('/api/v1/playback/resolve'),
        data: {
          'provider': provider.name,
          'externalId': source.externalId,
          'quality': quality.name,
        },
        options: _tokenOptions(token),
      );
      final json = response.data?['source'];
      if (json is! Map) throw const FormatException('Missing source');
      final sourceJson = Map<String, dynamic>.from(json);
      final streamUrl = Uri.parse(_requiredString(sourceJson, 'streamUrl'));
      if (!streamUrl.isScheme('https')) {
        throw const FormatException('Stream URL must use HTTPS');
      }
      return ResolvedAudioSource(
        streamUrl: streamUrl,
        protocol: _protocolFromJson(_requiredString(sourceJson, 'protocol')),
        codec: sourceJson['codec'] as String?,
        bitrate: (sourceJson['bitrate'] as num?)?.toInt(),
        expiresAt: sourceJson['expiresAt'] is String
            ? DateTime.parse(sourceJson['expiresAt'] as String).toUtc()
            : null,
        headers: sourceJson['headers'] is Map
            ? Map<String, String>.from(sourceJson['headers'] as Map)
            : const {},
      );
    } on DioException catch (error) {
      throw AudioResolutionException(
        error.response?.statusCode == 401
            ? 'Токен ${_providerTitle(provider)} отсутствует или недействителен.'
            : 'Не удалось получить поток ${_providerTitle(provider)}.',
        cause: error,
      );
    } on (FormatException, TypeError) catch (error) {
      throw AudioResolutionException(
        'Сервер воспроизведения вернул некорректный поток.',
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

  Options? _tokenOptions(String? token) {
    final value = token?.trim();
    if (value == null || value.isEmpty) return null;
    return Options(headers: {'X-Provider-Token': value});
  }
}

/// Maps a backend `ProviderTrack` JSON payload into a [UnifiedTrack].
UnifiedTrack tokenTrackFromJson(
  MusicProvider provider,
  Map<String, dynamic> json,
) {
  try {
    final externalId = _requiredString(json, 'id');
    final title = _requiredString(json, 'title');
    final artist = _requiredString(json, 'artist');
    final externalUrl = Uri.parse(_requiredString(json, 'externalUrl'));
    if (!externalUrl.isScheme('https')) {
      throw const FormatException('Track URL must use HTTPS');
    }
    final artwork = json['artworkUrl'] is String
        ? Uri.tryParse(json['artworkUrl'] as String)
        : null;
    // The backend already returns namespaced ids (spotify:track:…,
    // vk:audio:…) that /playback/resolve accepts as externalId.
    return UnifiedTrack(
      id: externalId,
      title: title,
      normalizedTitle: title.trim().toLowerCase(),
      artist: artist,
      normalizedArtist: artist.trim().toLowerCase(),
      album: json['album'] as String?,
      duration: json['durationMs'] is num
          ? Duration(milliseconds: (json['durationMs'] as num).toInt())
          : null,
      artworkUrl: artwork?.isScheme('https') == true ? artwork : null,
      preferredProvider: provider,
      sources: [
        TrackSource(
          provider: provider,
          externalId: externalId,
          externalUrl: externalUrl,
        ),
      ],
    );
  } on (FormatException, TypeError) catch (error) {
    throw ProviderUnavailableException(
      'Сервер каталога вернул некорректный трек.',
      cause: error,
    );
  }
}

String _providerTitle(MusicProvider provider) => switch (provider) {
  MusicProvider.spotify => 'Spotify',
  MusicProvider.vk => 'VK Музыки',
  _ => provider.name,
};

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) throw FormatException('Missing $key');
  return value;
}

StreamProtocol _protocolFromJson(String value) => switch (value) {
  'progressive' => StreamProtocol.progressive,
  'hls' => StreamProtocol.hls,
  'dash' => StreamProtocol.dash,
  _ => throw FormatException('Unknown stream protocol: $value'),
};
