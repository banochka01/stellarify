import 'package:dio/dio.dart';
import 'package:resonance/core/errors/app_exception.dart';
import 'package:resonance/domain/entities/music_enums.dart';
import 'package:resonance/domain/entities/unified_track.dart';
import 'package:resonance/domain/repositories/secure_token_repository.dart';
import 'package:resonance/providers/common/backend_token_provider.dart';
import 'package:resonance/providers/yandex/backend_yandex_provider.dart';
import 'package:resonance/providers/youtube/backend_youtube_provider.dart';

class ImportedPlaylist {
  const ImportedPlaylist({
    required this.name,
    required this.provider,
    required this.tracks,
    this.externalId,
  });
  final String name;
  final MusicProvider provider;
  final List<UnifiedTrack> tracks;
  final String? externalId;
}

class ImportedProviderLibrary {
  const ImportedProviderLibrary({
    required this.provider,
    required this.title,
    required this.favorites,
    required this.playlists,
    required this.truncated,
  });

  final MusicProvider provider;
  final String title;
  final List<UnifiedTrack> favorites;
  final List<ImportedPlaylist> playlists;
  final bool truncated;

  int get trackCount => {
    ...favorites.map((track) => track.id),
    ...playlists.expand((playlist) => playlist.tracks).map((track) => track.id),
  }.length;
}

class PlaylistImportService {
  PlaylistImportService(this._dio, this._baseUri, this._tokens);
  final Dio _dio;
  final Uri Function() _baseUri;
  final SecureTokenRepository _tokens;

  Future<ImportedPlaylist> importUrl(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null || !uri.isScheme('https')) {
      throw const ProviderUnavailableException(
        'Нужна HTTPS-ссылка на плейлист.',
      );
    }
    final provider = uri.host.contains('youtube.com')
        ? MusicProvider.youtube
        : uri.host.contains('yandex.')
        ? MusicProvider.yandex
        : uri.host == 'open.spotify.com' || uri.host == 'play.spotify.com'
        ? MusicProvider.spotify
        : uri.host.endsWith('vk.com') || uri.host.endsWith('vk.ru')
        ? MusicProvider.vk
        : null;
    final token = provider == null ? null : await _tokens.read(provider);
    try {
      final response = await _dio.postUri<Map<String, dynamic>>(
        _baseUri().resolve('/api/v1/playlists/import'),
        data: {'url': uri.toString()},
        options: token?.isNotEmpty == true
            ? Options(headers: {'X-Provider-Token': token})
            : null,
      );
      final data = response.data?['playlist'];
      if (data is! Map) throw const FormatException('Missing playlist');
      final playlist = Map<String, dynamic>.from(data);
      final providerName = playlist['provider'] as String?;
      final resolvedProvider = MusicProvider.values
          .where((item) => item.name == providerName)
          .firstOrNull;
      if (resolvedProvider == null) {
        throw const FormatException('Unknown provider');
      }
      final rawTracks = playlist['tracks'];
      if (rawTracks is! List) throw const FormatException('Missing tracks');
      final tracks = rawTracks
          .map((raw) {
            final json = Map<String, dynamic>.from(raw as Map);
            return switch (resolvedProvider) {
              MusicProvider.youtube => youtubeTrackFromJson(json),
              MusicProvider.yandex => yandexTrackFromJson(json),
              _ => tokenTrackFromJson(resolvedProvider, json),
            };
          })
          .toList(growable: false);
      return ImportedPlaylist(
        name: playlist['title'] as String? ?? 'Импортированный плейлист',
        provider: resolvedProvider,
        tracks: tracks,
        externalId: playlist['externalId']?.toString(),
      );
    } on DioException catch (error) {
      final body = error.response?.data;
      final message = body is Map && body['error'] is Map
          ? (body['error'] as Map)['message']?.toString()
          : null;
      throw ProviderUnavailableException(
        message ?? 'Не удалось импортировать плейлист.',
        cause: error,
      );
    } on FormatException catch (error) {
      throw ProviderUnavailableException(
        'Сервер вернул некорректный плейлист.',
        cause: error,
      );
    }
  }

  Future<ImportedProviderLibrary> importLibrary(MusicProvider provider) async {
    if (!const {
      MusicProvider.yandex,
      MusicProvider.spotify,
      MusicProvider.vk,
    }.contains(provider)) {
      throw const ProviderUnavailableException(
        'Этот сервис пока не поддерживает перенос всей медиатеки.',
      );
    }
    final token = await _tokens.read(provider);
    if (token == null || token.trim().isEmpty) {
      throw ProviderUnavailableException(
        'Сначала подключите ${_providerTitle(provider)} в настройках.',
      );
    }
    try {
      final response = await _dio.postUri<Map<String, dynamic>>(
        _baseUri().resolve('/api/v1/library/import'),
        data: {'provider': provider.name},
        options: Options(headers: {'X-Provider-Token': token}),
      );
      final raw = response.data?['library'];
      if (raw is! Map) throw const FormatException('Missing library');
      final library = Map<String, dynamic>.from(raw);
      final resolvedProvider = MusicProvider.values
          .where((item) => item.name == library['provider'])
          .firstOrNull;
      if (resolvedProvider == null) {
        throw const FormatException('Unknown provider');
      }
      final favorites = _parseTracks(library['favorites'], resolvedProvider);
      final playlists = (library['playlists'] as List? ?? const [])
          .whereType<Map>()
          .map((value) {
            final playlist = Map<String, dynamic>.from(value);
            return ImportedPlaylist(
              name: playlist['title'] as String? ?? 'Импортированный плейлист',
              provider: resolvedProvider,
              tracks: _parseTracks(playlist['tracks'], resolvedProvider),
              externalId: playlist['externalId']?.toString(),
            );
          })
          .toList(growable: false);
      return ImportedProviderLibrary(
        provider: resolvedProvider,
        title: library['title'] as String? ?? _providerTitle(resolvedProvider),
        favorites: favorites,
        playlists: playlists,
        truncated: library['truncated'] == true,
      );
    } on DioException catch (error) {
      final body = error.response?.data;
      final message = body is Map && body['error'] is Map
          ? (body['error'] as Map)['message']?.toString()
          : null;
      throw ProviderUnavailableException(
        message ?? 'Не удалось перенести медиатеку.',
        cause: error,
      );
    } on FormatException catch (error) {
      throw ProviderUnavailableException(
        'Сервер вернул некорректную медиатеку.',
        cause: error,
      );
    }
  }

  List<UnifiedTrack> _parseTracks(Object? raw, MusicProvider provider) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((value) {
          final json = Map<String, dynamic>.from(value);
          return switch (provider) {
            MusicProvider.youtube => youtubeTrackFromJson(json),
            MusicProvider.yandex => yandexTrackFromJson(json),
            _ => tokenTrackFromJson(provider, json),
          };
        })
        .toList(growable: false);
  }
}

String _providerTitle(MusicProvider provider) => switch (provider) {
  MusicProvider.yandex => 'Яндекс Музыку',
  MusicProvider.spotify => 'Spotify',
  MusicProvider.vk => 'VK Музыку',
  MusicProvider.soundcloud => 'SoundCloud',
  MusicProvider.youtube => 'YouTube Music',
};
