import 'package:dio/dio.dart';
import 'package:resonance/core/errors/app_exception.dart';
import 'package:resonance/core/networking/soundcloud_proxy_preference.dart';
import 'package:resonance/domain/entities/music_enums.dart';
import 'package:resonance/domain/entities/provider_capabilities.dart';
import 'package:resonance/domain/entities/resolved_audio_source.dart';
import 'package:resonance/domain/entities/track_source.dart';
import 'package:resonance/domain/entities/unified_track.dart';
import 'package:resonance/domain/providers/audio_source_resolver.dart';
import 'package:resonance/domain/providers/music_catalog_provider.dart';
import 'package:resonance/domain/repositories/secure_token_repository.dart';

abstract interface class ResonanceBackendClient {
  Future<void> validateProvider({
    required MusicProvider provider,
    required String token,
    bool useProxy = false,
  });

  Future<Map<MusicProvider, bool>> serverCredentialStatus();

  Future<List<Map<String, dynamic>>> searchSoundCloud(
    String query, {
    required int limit,
    String? token,
    bool useProxy = false,
  });

  Future<Map<String, dynamic>> resolveSoundCloud(
    String externalId, {
    required AudioQuality quality,
    String? token,
    bool useProxy = false,
  });
}

final class DioResonanceBackendClient implements ResonanceBackendClient {
  DioResonanceBackendClient(this._dio, this._baseUri);

  final Dio _dio;
  final Uri Function() _baseUri;

  @override
  Future<void> validateProvider({
    required MusicProvider provider,
    required String token,
    bool useProxy = false,
  }) async {
    try {
      final uri = _baseUri()
          .resolve('/api/v1/auth/validate')
          .replace(queryParameters: {'provider': provider.name});
      await _dio.getUri<Map<String, dynamic>>(
        uri,
        options: _requestOptions(
          token,
          useProxy && provider == MusicProvider.soundcloud,
        ),
      );
    } on DioException catch (error) {
      throw ProviderUnavailableException(
        provider == MusicProvider.soundcloud
            ? _soundCloudErrorMessage(error, validating: true)
            : _credentialErrorMessage(provider, error),
        cause: error,
      );
    }
  }

  @override
  Future<Map<MusicProvider, bool>> serverCredentialStatus() async {
    try {
      final response = await _dio.getUri<Map<String, dynamic>>(
        _baseUri().resolve('/api/v1/playback/providers'),
      );
      final providers = response.data?['providers'];
      if (providers is! List) {
        throw const FormatException('Missing providers list');
      }
      final result = <MusicProvider, bool>{};
      for (final raw in providers.whereType<Map>()) {
        final name = raw['name'];
        for (final provider in MusicProvider.values) {
          if (provider.name == name) {
            result[provider] = raw['serverCredentialConfigured'] == true;
          }
        }
      }
      return result;
    } on (DioException, FormatException) catch (error) {
      throw ProviderUnavailableException(
        'Не удалось проверить серверные подключения.',
        cause: error,
      );
    }
  }

  @override
  Future<List<Map<String, dynamic>>> searchSoundCloud(
    String query, {
    required int limit,
    String? token,
    bool useProxy = false,
  }) async {
    try {
      final uri = _baseUri()
          .resolve('/api/v1/catalog/search')
          .replace(
            queryParameters: {
              'provider': 'soundcloud',
              'q': query,
              'limit': '$limit',
            },
          );
      final response = await _dio.getUri<Map<String, dynamic>>(
        uri,
        options: _requestOptions(token, useProxy),
      );
      final tracks = response.data?['tracks'];
      if (tracks is! List) throw const FormatException('Missing tracks list');
      return tracks
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList(growable: false);
    } on DioException catch (error) {
      throw ProviderUnavailableException(
        _soundCloudErrorMessage(error),
        cause: error,
      );
    } on FormatException catch (error) {
      throw ProviderUnavailableException(
        'The Resonance catalog backend returned an invalid response.',
        cause: error,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> resolveSoundCloud(
    String externalId, {
    required AudioQuality quality,
    String? token,
    bool useProxy = false,
  }) async {
    try {
      final response = await _dio.postUri<Map<String, dynamic>>(
        _baseUri().resolve('/api/v1/playback/resolve'),
        data: {
          'provider': 'soundcloud',
          'externalId': externalId,
          'quality': quality.name,
        },
        options: _requestOptions(token, useProxy),
      );
      final source = response.data?['source'];
      if (source is! Map) throw const FormatException('Missing source');
      final normalized = Map<String, dynamic>.from(source);
      final streamUrl = normalized['streamUrl'];
      if (streamUrl is String) {
        normalized['streamUrl'] = resolveBackendStreamUrl(
          _baseUri(),
          streamUrl,
        ).toString();
      }
      return normalized;
    } on DioException catch (error) {
      throw AudioResolutionException(
        _soundCloudErrorMessage(error),
        cause: error,
      );
    } on FormatException catch (error) {
      throw AudioResolutionException(
        'The Resonance playback backend returned an invalid response.',
        cause: error,
      );
    }
  }

  Options? _requestOptions(String? token, bool useProxy) {
    final value = token?.trim();
    final headers = <String, String>{
      if (value != null && value.isNotEmpty) 'X-Provider-Token': value,
      if (useProxy) 'X-SoundCloud-Proxy': 'enabled',
    };
    return headers.isEmpty ? null : Options(headers: headers);
  }
}

String _credentialErrorMessage(MusicProvider provider, DioException error) {
  final code = error.response?.data is Map
      ? (error.response?.data as Map)['error'] is Map
            ? ((error.response?.data as Map)['error'] as Map)['code']
            : null
      : null;
  if (code == 'INVALID_PROVIDER_TOKEN' ||
      code == 'PROVIDER_AUTH_REQUIRED' ||
      error.response?.statusCode == 401) {
    return provider == MusicProvider.youtube
        ? 'YouTube отклонил API key.'
        : 'Яндекс Музыка отклонила OAuth-токен.';
  }
  return 'Не удалось проверить ключ ${provider == MusicProvider.youtube ? 'YouTube' : 'Яндекс Музыки'}.';
}

Uri resolveBackendStreamUrl(Uri baseUri, String value) {
  final streamUri = Uri.parse(value);
  return streamUri.hasScheme ? streamUri : baseUri.resolveUri(streamUri);
}

final class BackendSoundCloudProvider
    implements MusicCatalogProvider, AudioSourceResolver {
  BackendSoundCloudProvider(
    this._client,
    this._tokens,
    this._proxyPreference, [
    this._localFallback,
  ]);

  final ResonanceBackendClient _client;
  final SecureTokenRepository _tokens;
  final SoundCloudProxyPreference _proxyPreference;
  final AudioSourceResolver? _localFallback;

  @override
  MusicProvider get provider => MusicProvider.soundcloud;

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
    final tracks = await _client.searchSoundCloud(
      value,
      limit: limit.clamp(1, 50),
      token: await _effectiveCredential(),
      useProxy: await _proxyPreference.read(),
    );
    return tracks.map(_trackFromJson).toList(growable: false);
  }

  @override
  Future<ResolvedAudioSource> resolve(
    TrackSource source, {
    AudioQuality quality = AudioQuality.high,
  }) async {
    if (source.metadata['assetPath'] is String && _localFallback != null) {
      return _localFallback.resolve(source, quality: quality);
    }
    final json = await _client.resolveSoundCloud(
      source.externalId,
      quality: quality,
      token: await _effectiveCredential(),
      useProxy: await _proxyPreference.read(),
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
        'The Resonance playback backend returned an invalid stream.',
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

  Future<String?> _effectiveCredential() async {
    final value = await _tokens.read(MusicProvider.soundcloud);
    if (value != null && RegExp(r'^2-\d+-\d+-').hasMatch(value.trim())) {
      await _tokens.delete(MusicProvider.soundcloud);
      return null;
    }
    return value;
  }
}

String _soundCloudErrorMessage(DioException error, {bool validating = false}) {
  final data = error.response?.data;
  final body = data is Map ? data['error'] : null;
  final code = body is Map ? body['code'] : null;
  return switch (code) {
    'INVALID_PROVIDER_TOKEN' =>
      'SoundCloud отклонил API access token. Получите новый OAuth-токен приложения.',
    'PROVIDER_ACCESS_DENIED' =>
      'SoundCloud запретил API-доступ. Cookie oauth_token не является API access token.',
    'PROVIDER_RATE_LIMITED' =>
      'SoundCloud временно ограничил запросы. Попробуйте позже.',
    'PROXY_NOT_CONFIGURED' => 'Серверный прокси SoundCloud пока не настроен.',
    'PROXY_CONNECTION_FAILED' =>
      'Серверный прокси SoundCloud не смог подключиться.',
    'UPSTREAM_TIMEOUT' => 'SoundCloud не ответил вовремя.',
    _ when validating => 'Не удалось проверить токен SoundCloud.',
    _ => 'Сервер каталога SoundCloud недоступен.',
  };
}

UnifiedTrack _trackFromJson(Map<String, dynamic> json) {
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
      id: 'soundcloud:$externalId',
      title: title,
      normalizedTitle: title.trim().toLowerCase(),
      artist: artist,
      normalizedArtist: artist.trim().toLowerCase(),
      album: json['album'] as String?,
      duration: json['durationMs'] is num
          ? Duration(milliseconds: (json['durationMs'] as num).toInt())
          : null,
      artworkUrl: artwork?.isScheme('https') == true ? artwork : null,
      preferredProvider: MusicProvider.soundcloud,
      sources: [
        TrackSource(
          provider: MusicProvider.soundcloud,
          externalId: externalId,
          externalUrl: externalUrl,
        ),
      ],
    );
  } on (FormatException, TypeError) catch (error) {
    throw ProviderUnavailableException(
      'The Resonance catalog backend returned an invalid track.',
      cause: error,
    );
  }
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('Missing $key');
  }
  return value;
}

StreamProtocol _protocolFromJson(String value) => switch (value) {
  'progressive' => StreamProtocol.progressive,
  'hls' => StreamProtocol.hls,
  'dash' => StreamProtocol.dash,
  _ => throw FormatException('Unknown stream protocol: $value'),
};
