import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/app/providers.dart';
import 'package:resonance/core/networking/backend_endpoint.dart';
import 'package:resonance/domain/entities/music_enums.dart';
import 'package:resonance/domain/repositories/secure_token_repository.dart';

/// Источники, из которых сервер умеет забирать всю медиатеку.
const migrationSources = [
  MusicProvider.yandex,
  MusicProvider.spotify,
  MusicProvider.vk,
];

/// Куда можно перенести: каталоги, в которых сервер ищет совпадения.
const migrationTargets = [
  MusicProvider.yandex,
  MusicProvider.vk,
  MusicProvider.soundcloud,
  MusicProvider.spotify,
];

enum MigrationConfidence { exact, high, low, none }

MigrationConfidence? _confidence(Object? value) =>
    MigrationConfidence.values.where((item) => item.name == value).firstOrNull;

MusicProvider? _provider(Object? value) =>
    MusicProvider.values.where((item) => item.name == value).firstOrNull;

class MigrationTrack {
  const MigrationTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.externalUrl,
    this.album,
    this.durationMs,
    this.artworkUrl,
    this.provider,
  });

  factory MigrationTrack.fromJson(Map<String, dynamic> json) => MigrationTrack(
    id: json['id'].toString(),
    title: json['title']?.toString() ?? '',
    artist: json['artist']?.toString() ?? '',
    album: json['album'] as String?,
    durationMs: (json['durationMs'] as num?)?.toInt(),
    artworkUrl: json['artworkUrl'] as String?,
    externalUrl: json['externalUrl']?.toString() ?? '',
    provider: _provider(json['provider']),
  );

  final String id;
  final String title;
  final String artist;
  final String? album;
  final int? durationMs;
  final String? artworkUrl;
  final String externalUrl;
  final MusicProvider? provider;

  Map<String, dynamic> toReplaceJson() => {
    'id': id,
    'title': title,
    'artist': artist,
    if (album != null && album!.isNotEmpty) 'album': album,
    if (durationMs != null) 'durationMs': durationMs,
    if (artworkUrl != null && artworkUrl!.startsWith('https://'))
      'artworkUrl': artworkUrl,
    'externalUrl': externalUrl,
  };
}

class MigrationJob {
  const MigrationJob({
    required this.id,
    required this.source,
    required this.target,
    required this.kind,
    required this.status,
    required this.total,
    required this.processed,
    required this.progress,
    this.error,
    this.warning,
    this.truncated = false,
    this.lastSyncedAt,
  });

  factory MigrationJob.fromJson(Map<String, dynamic> json) => MigrationJob(
    id: json['id'].toString(),
    source: _provider(json['source']) ?? MusicProvider.yandex,
    target: _provider(json['target']) ?? MusicProvider.yandex,
    kind: json['kind']?.toString() ?? 'full',
    status: json['status']?.toString() ?? 'queued',
    total: (json['total'] as num?)?.toInt() ?? 0,
    processed: (json['processed'] as num?)?.toInt() ?? 0,
    progress: (json['progress'] as num?)?.toDouble() ?? 0,
    error: json['error'] as String?,
    warning: json['warning'] as String?,
    truncated: json['truncated'] == true,
    lastSyncedAt: DateTime.tryParse(json['lastSyncedAt']?.toString() ?? ''),
  );

  final String id;
  final MusicProvider source;
  final MusicProvider target;
  final String kind;
  final String status;
  final int total;
  final int processed;
  final double progress;
  final String? error;
  final String? warning;
  final bool truncated;
  final DateTime? lastSyncedAt;

  bool get isActive =>
      const {'queued', 'fetching', 'matching', 'saving'}.contains(status);
  bool get isCompleted => status == 'completed';
  bool get canResume => status == 'paused' || status == 'failed';
}

class MigrationItem {
  const MigrationItem({
    required this.itemId,
    required this.section,
    required this.status,
    required this.source,
    this.collectionTitle,
    this.confidence,
    this.score,
    this.match,
  });

  factory MigrationItem.fromJson(Map<String, dynamic> json) => MigrationItem(
    itemId: (json['itemId'] as num).toInt(),
    section: json['section']?.toString() ?? 'favorite',
    status: json['status']?.toString() ?? 'pending',
    collectionTitle: json['collectionTitle'] as String?,
    confidence: _confidence(json['confidence']),
    score: (json['score'] as num?)?.toDouble(),
    source: MigrationTrack.fromJson(
      Map<String, dynamic>.from(json['source'] as Map),
    ),
    match: json['match'] is Map
        ? MigrationTrack.fromJson(
            Map<String, dynamic>.from(json['match'] as Map),
          )
        : null,
  );

  final int itemId;
  final String section;
  final String status;
  final String? collectionTitle;
  final MigrationConfidence? confidence;
  final double? score;
  final MigrationTrack source;
  final MigrationTrack? match;

  bool get resolved => status == 'confirmed' || status == 'replaced';
}

class MigrationReport {
  const MigrationReport({
    required this.job,
    required this.total,
    required this.migrated,
    required this.percent,
    required this.exact,
    required this.high,
    required this.low,
    required this.none,
    required this.manual,
    required this.lowConfidence,
    required this.unmatched,
    required this.artists,
    required this.collections,
  });

  factory MigrationReport.fromJson(Map<String, dynamic> json) {
    final summary = Map<String, dynamic>.from(json['summary'] as Map);
    int count(String key) => (summary[key] as num?)?.toInt() ?? 0;
    List<MigrationItem> items(String key) => (json[key] as List? ?? const [])
        .whereType<Map>()
        .map((raw) => MigrationItem.fromJson(Map<String, dynamic>.from(raw)))
        .toList(growable: false);
    return MigrationReport(
      job: MigrationJob.fromJson(Map<String, dynamic>.from(json['job'] as Map)),
      total: count('total'),
      migrated: count('migrated'),
      percent: (summary['percent'] as num?)?.toDouble() ?? 0,
      exact: count('exact'),
      high: count('high'),
      low: count('low'),
      none: count('none'),
      manual: count('manual'),
      lowConfidence: items('lowConfidence'),
      unmatched: items('unmatched'),
      artists: (json['artists'] as List? ?? const [])
          .whereType<Map>()
          .map((raw) => raw['name']?.toString() ?? '')
          .where((name) => name.isNotEmpty)
          .toList(growable: false),
      collections: (json['collections'] as List? ?? const []).length,
    );
  }

  final MigrationJob job;
  final int total;
  final int migrated;
  final double percent;
  final int exact;
  final int high;
  final int low;
  final int none;
  final int manual;
  final List<MigrationItem> lowConfidence;
  final List<MigrationItem> unmatched;
  final List<String> artists;
  final int collections;
}

class MigrationCandidate {
  const MigrationCandidate({
    required this.track,
    required this.confidence,
    required this.score,
  });

  factory MigrationCandidate.fromJson(Map<String, dynamic> json) =>
      MigrationCandidate(
        track: MigrationTrack.fromJson(
          Map<String, dynamic>.from(json['track'] as Map),
        ),
        confidence: _confidence(json['confidence']) ?? MigrationConfidence.none,
        score: (json['score'] as num?)?.toDouble() ?? 0,
      );

  final MigrationTrack track;
  final MigrationConfidence confidence;
  final double score;
}

class MigrationException implements Exception {
  const MigrationException(this.message, {this.code});
  final String message;
  final String? code;

  @override
  String toString() => message;
}

/// Клиент «Переезда»: задачи переноса живут на сервере и привязаны к Resonance ID.
class MigrationApi {
  MigrationApi(this._dio, this._endpoint, this._accessToken, this._tokens);

  final Dio _dio;
  final Uri Function() _endpoint;
  final Future<String?> Function() _accessToken;
  final SecureTokenRepository _tokens;

  Future<List<MigrationJob>> jobs() async {
    final data = await _request('GET', '/api/v1/migrations');
    return (data['jobs'] as List? ?? const [])
        .whereType<Map>()
        .map((raw) => MigrationJob.fromJson(Map<String, dynamic>.from(raw)))
        .toList(growable: false);
  }

  Future<MigrationJob> start(
    MusicProvider source,
    MusicProvider target, {
    bool resync = false,
  }) async {
    final data = await _request(
      'POST',
      resync ? '/api/v1/migrations/resync' : '/api/v1/migrations',
      body: {'source': source.name, 'target': target.name},
      headers: await _providerHeaders(source, target),
    );
    return MigrationJob.fromJson(Map<String, dynamic>.from(data['job'] as Map));
  }

  Future<MigrationJob> resume(MigrationJob job) async {
    final data = await _request(
      'POST',
      '/api/v1/migrations/${job.id}/resume',
      headers: await _providerHeaders(job.source, job.target),
    );
    return MigrationJob.fromJson(Map<String, dynamic>.from(data['job'] as Map));
  }

  Future<MigrationJob> job(String id) async {
    final data = await _request('GET', '/api/v1/migrations/$id');
    return MigrationJob.fromJson(Map<String, dynamic>.from(data['job'] as Map));
  }

  Future<MigrationReport> report(String id) async => MigrationReport.fromJson(
    await _request('GET', '/api/v1/migrations/$id/report'),
  );

  Future<List<MigrationCandidate>> candidates(
    MigrationJob job,
    int itemId, {
    String? query,
  }) async {
    final q = query?.trim();
    final data = await _request(
      'GET',
      '/api/v1/migrations/${job.id}/items/$itemId/candidates'
          '${q == null || q.isEmpty ? '' : '?q=${Uri.encodeQueryComponent(q)}'}',
      headers: await _providerHeaders(null, job.target),
    );
    return (data['candidates'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (raw) => MigrationCandidate.fromJson(Map<String, dynamic>.from(raw)),
        )
        .toList(growable: false);
  }

  Future<void> confirm(String jobId, int itemId) =>
      _request('POST', '/api/v1/migrations/$jobId/items/$itemId/confirm');

  Future<void> replace(String jobId, int itemId, MigrationTrack track) =>
      _request(
        'POST',
        '/api/v1/migrations/$jobId/items/$itemId/replace',
        body: {
          'track': track.toReplaceJson(),
          if (track.provider != null) 'provider': track.provider!.name,
        },
      );

  Future<Map<String, String>> _providerHeaders(
    MusicProvider? source,
    MusicProvider target,
  ) async {
    final headers = <String, String>{};
    if (source != null) {
      final token = await _tokens.read(source);
      if (token == null || token.trim().isEmpty) {
        throw MigrationException(
          'Сначала подключите ${migrationProviderTitle(source)} в настройках.',
          code: 'PROVIDER_AUTH_REQUIRED',
        );
      }
      headers['X-Source-Token'] = token.trim();
    }
    final targetToken = await _tokens.read(target);
    if (targetToken != null && targetToken.trim().isNotEmpty) {
      headers['X-Target-Token'] = targetToken.trim();
    }
    return headers;
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Object? body,
    Map<String, String> headers = const {},
  }) async {
    final token = await _accessToken();
    if (token == null) {
      throw const MigrationException(
        'Войдите в Resonance ID, чтобы перенести медиатеку.',
        code: 'AUTH_REQUIRED',
      );
    }
    try {
      final response = await _dio.requestUri<dynamic>(
        _endpoint().resolve(path),
        data: body,
        options: Options(
          method: method,
          headers: {'Authorization': 'Bearer $token', ...headers},
        ),
      );
      final data = response.data;
      return data is Map
          ? Map<String, dynamic>.from(data)
          : <String, dynamic>{};
    } on DioException catch (error) {
      final data = error.response?.data;
      final payload = data is Map && data['error'] is Map
          ? Map<String, dynamic>.from(data['error'] as Map)
          : const <String, dynamic>{};
      throw MigrationException(
        payload['message']?.toString() ??
            'Сервер переноса недоступен. Попробуйте позже.',
        code: payload['code']?.toString(),
      );
    }
  }
}

String migrationProviderTitle(MusicProvider provider) => switch (provider) {
  MusicProvider.yandex => 'Яндекс Музыка',
  MusicProvider.spotify => 'Spotify',
  MusicProvider.vk => 'VK Музыка',
  MusicProvider.soundcloud => 'SoundCloud',
  MusicProvider.youtube => 'YouTube Music',
};

final migrationApiProvider = Provider<MigrationApi>((ref) {
  final account = ref.watch(accountApiProvider);
  return MigrationApi(
    ref.watch(resonanceHttpClientProvider).dio,
    BackendEndpoint.requireCurrent,
    account.accessToken,
    ref.watch(secureTokenRepositoryProvider),
  );
});
