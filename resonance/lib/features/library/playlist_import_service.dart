import 'package:dio/dio.dart';
import 'package:resonance/core/errors/app_exception.dart';
import 'package:resonance/domain/entities/music_enums.dart';
import 'package:resonance/domain/entities/unified_track.dart';
import 'package:resonance/domain/repositories/secure_token_repository.dart';
import 'package:resonance/providers/yandex/backend_yandex_provider.dart';
import 'package:resonance/providers/youtube/backend_youtube_provider.dart';

class ImportedPlaylist {
  const ImportedPlaylist({
    required this.name,
    required this.provider,
    required this.tracks,
  });
  final String name;
  final MusicProvider provider;
  final List<UnifiedTrack> tracks;
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
            return resolvedProvider == MusicProvider.youtube
                ? youtubeTrackFromJson(json)
                : yandexTrackFromJson(json);
          })
          .toList(growable: false);
      return ImportedPlaylist(
        name: playlist['title'] as String? ?? 'Импортированный плейлист',
        provider: resolvedProvider,
        tracks: tracks,
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
}
