import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/app/providers.dart';
import 'package:resonance/core/networking/backend_endpoint.dart';
import 'package:resonance/domain/entities/music_enums.dart';
import 'package:resonance/domain/entities/unified_track.dart';
import 'package:resonance/domain/repositories/secure_token_repository.dart';

enum StageClipKind { musicVideo, preview, ambient }

class StageClip {
  const StageClip({
    required this.id,
    this.url,
    required this.title,
    required this.source,
    required this.sourceUrl,
    required this.kind,
    required this.playable,
    this.offset = Duration.zero,
  });
  final String id;
  final Uri? url;
  final String title;
  final String source;
  final Uri sourceUrl;
  final StageClipKind kind;
  final bool playable;
  final Duration offset;

  bool get ambient => kind == StageClipKind.ambient;
  bool get preview => kind == StageClipKind.preview;

  factory StageClip.fromJson(Map<String, dynamic> json) {
    Uri secureUri(String key) {
      final uri = Uri.parse(json[key] as String);
      if (uri.scheme != 'https' ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty) {
        throw const FormatException('Invalid clip URL');
      }
      return uri;
    }

    final kind = switch (json['kind']) {
      'musicVideo' => StageClipKind.musicVideo,
      'preview' => StageClipKind.preview,
      'ambient' => StageClipKind.ambient,
      _ => throw const FormatException('Invalid clip kind'),
    };
    final playable = json['playback'] != 'external';
    final mediaUrl = json['url'] == null ? null : secureUri('url');
    if (playable && mediaUrl == null) {
      throw const FormatException('Invalid clip kind');
    }
    return StageClip(
      id: json['id'] as String,
      url: mediaUrl,
      title: json['title'] as String,
      source: json['source'] as String,
      sourceUrl: secureUri('sourceUrl'),
      kind: kind,
      playable: playable,
      offset: Duration(milliseconds: (json['offsetMs'] as num? ?? 0).round()),
    );
  }
}

class ClipService {
  ClipService(this.dio, this.baseUri, this.tokens);
  final Dio dio;
  final Uri Function() baseUri;
  final SecureTokenRepository tokens;

  Future<List<StageClip>> find(
    UnifiedTrack track,
    CancelToken cancelToken,
  ) async {
    final yandexSource = track.sourceFor(MusicProvider.yandex);
    final yandexToken = yandexSource == null
        ? null
        : await tokens.read(MusicProvider.yandex);
    final response = await dio.getUri<Map<String, dynamic>>(
      baseUri()
          .resolve('/api/v1/clips')
          .replace(
            queryParameters: {
              'title': track.title,
              'artist': track.artist,
              if (yandexSource != null) 'yandexId': yandexSource.externalId,
            },
          ),
      cancelToken: cancelToken,
      options: yandexToken?.trim().isNotEmpty == true
          ? Options(headers: {'X-Provider-Token': yandexToken})
          : null,
    );
    return (response.data?['clips'] as List<dynamic>? ?? [])
        .map((item) => StageClip.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }
}

final clipServiceProvider = Provider<ClipService>(
  (ref) => ClipService(
    ref.watch(resonanceHttpClientProvider).dio,
    BackendEndpoint.requireCurrent,
    ref.watch(secureTokenRepositoryProvider),
  ),
);

final stageClipsProvider = FutureProvider.autoDispose
    .family<List<StageClip>, UnifiedTrack>((ref, track) {
      final cancel = CancelToken();
      ref.onDispose(cancel.cancel);
      return ref.watch(clipServiceProvider).find(track, cancel);
    });
