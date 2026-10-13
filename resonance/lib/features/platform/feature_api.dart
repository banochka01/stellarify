import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/app/providers.dart';
import 'package:resonance/core/networking/backend_endpoint.dart';
import 'package:resonance/domain/entities/unified_track.dart';
import 'package:resonance/features/wave/daily_mixes.dart';

/// Raised when a server-side feature is missing (404/501), disabled, the
/// account is absent or the network is down. Screens hide the feature instead
/// of failing loudly.
final class FeatureUnavailableException implements Exception {
  const FeatureUnavailableException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  bool get authRequired => statusCode == 401 || statusCode == 403;

  @override
  String toString() => message;
}

/// Thin transport for the Resonance 5 feature endpoints. Every feature API
/// talks only through this interface, so the wire contract stays in one DTO
/// file per feature and tests can swap the transport.
abstract interface class FeatureTransport {
  Future<Map<String, dynamic>> request(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    bool providerTokens = false,
  });
}

typedef FeatureHeaders = Future<Map<String, String>> Function();

final class DioFeatureTransport implements FeatureTransport {
  DioFeatureTransport(
    this._dio,
    this._endpoint,
    this._headers, {
    this.providerHeaders,
  });

  final Dio _dio;
  final Uri Function() _endpoint;
  final FeatureHeaders _headers;

  /// Provider tokens (`x-soundcloud-token`, …) for catalog-backed endpoints.
  final FeatureHeaders? providerHeaders;

  @override
  Future<Map<String, dynamic>> request(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    bool providerTokens = false,
  }) async {
    final headers = <String, String>{};
    try {
      headers.addAll(await _headers());
    } on Object {
      // Anonymous request; the server answers 401 where auth is required.
    }
    final provider = providerHeaders;
    if (providerTokens && provider != null) {
      try {
        headers.addAll(await provider());
      } on Object {
        // Provider tokens are optional.
      }
    }
    final base = _endpoint().resolve(path);
    final uri = query == null || query.isEmpty
        ? base
        : base.replace(queryParameters: query);
    try {
      final response = await _dio.requestUri<dynamic>(
        uri,
        data: body,
        options: Options(
          method: method,
          headers: headers,
          receiveTimeout: const Duration(seconds: 12),
        ),
      );
      final data = response.data;
      if (data is Map<String, dynamic>) return data;
      if (data is Map) return Map<String, dynamic>.from(data);
      return const {};
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      final payload = error.response?.data;
      String? message;
      if (payload is Map && payload['error'] is Map) {
        message = (payload['error'] as Map)['message']?.toString();
      }
      throw FeatureUnavailableException(
        message ??
            switch (status) {
              401 || 403 => 'Войдите в аккаунт Resonance',
              404 || 501 => 'Раздел пока недоступен на сервере',
              _ => 'Сервер недоступен',
            },
        statusCode: status,
      );
    }
  }
}

final featureTransportProvider = Provider<FeatureTransport>((ref) {
  return DioFeatureTransport(
    ref.watch(resonanceHttpClientProvider).dio,
    BackendEndpoint.requireCurrent,
    () => ref.read(clientIdentityServiceProvider).headers(),
    providerHeaders: () async {
      final options = await providerTokenOptions(
        ref.read(secureTokenRepositoryProvider),
      );
      return {
        for (final entry in (options?.headers ?? const {}).entries)
          entry.key: entry.value.toString(),
      };
    },
  );
});

// ---- tolerant JSON helpers shared by feature DTOs ----

Map<String, dynamic> jsonMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const {};
}

List<Map<String, dynamic>> jsonList(Object? value) => value is List
    ? value.map(jsonMap).where((item) => item.isNotEmpty).toList()
    : const [];

String jsonString(Object? value, [String fallback = '']) =>
    value == null ? fallback : value.toString();

String? jsonOptString(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

int jsonInt(Object? value, [int fallback = 0]) => switch (value) {
  final num number => number.toInt(),
  final String text => int.tryParse(text) ?? fallback,
  _ => fallback,
};

bool jsonBool(Object? value, [bool fallback = false]) =>
    value is bool ? value : fallback;

DateTime? jsonDate(Object? value) => switch (value) {
  final num ms => DateTime.fromMillisecondsSinceEpoch(ms.toInt(), isUtc: true),
  final String text => DateTime.tryParse(text),
  _ => null,
};

/// Parses an embedded track: either a server ProviderTrack/WaveItem
/// (`{provider, id, title, artist, externalUrl}`) or a full UnifiedTrack.
/// Malformed tracks are dropped, never fatal.
UnifiedTrack? jsonTrack(Object? value) {
  final map = jsonMap(value);
  if (map.isEmpty) return null;
  if (map['sources'] == null) {
    final wave = unifiedTrackFromWaveItem(map);
    if (wave != null) return wave;
  }
  try {
    return UnifiedTrack.fromJson(map);
  } on Object {
    return null;
  }
}

List<UnifiedTrack> jsonTracks(Object? value) => value is List
    ? value.map(jsonTrack).whereType<UnifiedTrack>().toList()
    : const [];

String formatShortDate(DateTime? date) {
  if (date == null) return '';
  final local = date.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(local.day)}.${two(local.month)}.${local.year}';
}
