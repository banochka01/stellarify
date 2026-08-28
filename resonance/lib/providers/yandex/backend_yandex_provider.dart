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

abstract interface class YandexBackendClient {
  Future<List<Map<String, dynamic>>> searchYandex(
    String query, {
    required int limit,
    String? token,
  });

  Future<Map<String, dynamic>> resolveYandex(
    String externalId, {
    required AudioQuality quality,
    String? token,
  });
}

final class DioYandexBackendClient implements YandexBackendClient {
  DioYandexBackendClient(this._dio, this._baseUri);

  final Dio _dio;
  final Uri Function() _baseUri;

  @override
  Future<List<Map<String, dynamic>>> searchYandex(
    String query, {
    required int limit,
    String? token,
  }) async {
    try {
      final uri = _baseUri()
          .resolve('/api/v1/catalog/search')
          .replace(
            queryParameters: {
              'provider': 'yandex',
              'q': query,
              'limit': '$limit',
            },
          );
      final response = await _dio.getUri<Map<String, dynamic>>(
        uri,
        options: _tokenOptions(token),
      );
      final tracks = response.data?['tracks'];
      if (tracks is! List) throw const FormatException('Missing tracks list');
      return tracks
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList(growable: false);
    } on DioException catch (error) {
      throw ProviderUnavailableException(
        error.response?.statusCode == 401
            ? 'Подключите действующий токен Яндекс Музыки.'
            : 'Сервер каталога Яндекс Музыки недоступен.',
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
  Future<Map<String, dynamic>> resolveYandex(
    String externalId, {
    required AudioQuality quality,
    String? token,
  }) async {
    try {
      final response = await _dio.postUri<Map<String, dynamic>>(
        _baseUri().resolve('/api/v1/playback/resolve'),
        data: {
          'provider': 'yandex',
          'externalId': externalId,
          'quality': quality.name,
        },
        options: _tokenOptions(token),
      );
      final source = response.data?['source'];
      if (source is! Map) throw const FormatException('Missing source');
      return Map<String, dynamic>.from(source);
    } on DioException catch (error) {
      throw AudioResolutionException(
        error.response?.statusCode == 401
            ? 'Токен Яндекс Музыки отсутствует или недействителен.'
            : 'Не удалось получить поток Яндекс Музыки.',
        cause: error,
      );
    } on FormatException catch (error) {
      throw AudioResolutionException(
        'Сервер воспроизведения вернул некорректный ответ.',
        cause: error,
      );
    }
  }

  Options? _tokenOptions(String? token) {
    final value = token?.trim();
    if (value == null || value.isEmpty) return null;
    return Options(headers: {'X-Provider-Token': value});
  }
}

final class BackendYandexProvider
    implements MusicCatalogProvider, AudioSourceResolver {
  BackendYandexProvider(this._client, this._tokens);

  final YandexBackendClient _client;
  final SecureTokenRepository _tokens;

  @override
  MusicProvider get provider => MusicProvider.yandex;

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
    final tracks = await _client.searchYandex(
      value,
      limit: limit.clamp(1, 50),
      token: await _tokens.read(MusicProvider.yandex),
    );
    return tracks.map(yandexTrackFromJson).toList(growable: false);
  }

  @override
  Future<ResolvedAudioSource> resolve(
    TrackSource source, {
    AudioQuality quality = AudioQuality.high,
  }) async {
    final json = await _client.resolveYandex(
      source.externalId,
      quality: quality,
      token: await _tokens.read(MusicProvider.yandex),
    );
    try {
      final streamUrl = Uri.parse(_requiredString(json, 'streamUrl'));
      if (!streamUrl.isScheme('https')) {
        throw const FormatException('Stream URL must use HTTPS');
      }
      return ResolvedAudioSource(
        streamUrl: streamUrl,
        protocol: _protocolFromJson(_requiredString(json, 'protocol')),
        codec: json['codec'] as String?,
        bitrate: (json['bitrate'] as num?)?.toInt(),
        expiresAt: json['expiresAt'] is String
            ? DateTime.parse(json['expiresAt'] as String).toUtc()
            : null,
        headers: json['headers'] is Map
            ? Map<String, String>.from(json['headers'] as Map)
            : const {},
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
}

UnifiedTrack yandexTrackFromJson(Map<String, dynamic> json) {
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
    return UnifiedTrack(
      id: 'yandex:$externalId',
      title: title,
      normalizedTitle: title.trim().toLowerCase(),
      artist: artist,
      normalizedArtist: artist.trim().toLowerCase(),
      album: json['album'] as String?,
      duration: json['durationMs'] is num
          ? Duration(milliseconds: (json['durationMs'] as num).toInt())
          : null,
      artworkUrl: artwork?.isScheme('https') == true ? artwork : null,
      preferredProvider: MusicProvider.yandex,
      sources: [
        TrackSource(
          provider: MusicProvider.yandex,
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
