import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/app/providers.dart';
import 'package:resonance/core/networking/backend_endpoint.dart';
import 'package:resonance/domain/entities/unified_track.dart';

class StageClip {
  const StageClip({
    required this.id,
    required this.url,
    required this.title,
    required this.source,
    required this.sourceUrl,
    required this.ambient,
    this.offset = Duration.zero,
  });
  final String id;
  final Uri url;
  final String title;
  final String source;
  final Uri sourceUrl;
  final bool ambient;
  final Duration offset;

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

    if (json['kind'] != 'ambient' && json['kind'] != 'musicVideo') {
      throw const FormatException('Invalid clip kind');
    }
    return StageClip(
      id: json['id'] as String,
      url: secureUri('url'),
      title: json['title'] as String,
      source: json['source'] as String,
      sourceUrl: secureUri('sourceUrl'),
      ambient: json['kind'] == 'ambient',
      offset: Duration(milliseconds: (json['offsetMs'] as num? ?? 0).round()),
    );
  }
}

class ClipService {
  ClipService(this.dio, this.baseUri);
  final Dio dio;
  final Uri Function() baseUri;

  Future<List<StageClip>> find(
    UnifiedTrack track,
    CancelToken cancelToken,
  ) async {
    final response = await dio.getUri<Map<String, dynamic>>(
      baseUri()
          .resolve('/api/v1/clips')
          .replace(
            queryParameters: {'title': track.title, 'artist': track.artist},
          ),
      cancelToken: cancelToken,
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
  ),
);

final stageClipsProvider = FutureProvider.autoDispose
    .family<List<StageClip>, UnifiedTrack>((ref, track) {
      final cancel = CancelToken();
      ref.onDispose(cancel.cancel);
      return ref.watch(clipServiceProvider).find(track, cancel);
    });
