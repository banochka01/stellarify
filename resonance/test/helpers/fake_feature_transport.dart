import 'package:resonance/core/security/flutter_secure_token_repository.dart';
import 'package:resonance/features/platform/feature_api.dart';

typedef FakeRoute =
    Map<String, dynamic> Function(Map<String, String>? query, Object? body);

/// In-memory transport: `'GET /api/v1/flags'` → JSON. Unknown routes behave
/// like a missing server endpoint (404).
final class FakeFeatureTransport implements FeatureTransport {
  FakeFeatureTransport(this.routes);

  final Map<String, FakeRoute> routes;
  final List<({String method, String path, Object? body})> calls = [];

  @override
  Future<Map<String, dynamic>> request(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    bool providerTokens = false,
  }) async {
    calls.add((method: method, path: path, body: body));
    final route = routes['$method $path'];
    if (route == null) {
      throw const FeatureUnavailableException('missing', statusCode: 404);
    }
    return route(query, body);
  }
}

FakeRoute json(Map<String, dynamic> value) =>
    (_, _) => value;

FakeRoute flags(List<String> enabled) => json({
  'flags': {for (final key in enabled) key: true},
});

final class MemoryKeyValueStore implements SecureKeyValueStore {
  final values = <String, String>{};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

/// Server ProviderTrack / WaveItem payload.
Map<String, dynamic> waveItem(String id, {String title = 'Song'}) => {
  'provider': 'soundcloud',
  'id': id,
  'title': title,
  'artist': 'Artist',
  'externalUrl': 'https://soundcloud.com/a/$id',
};
