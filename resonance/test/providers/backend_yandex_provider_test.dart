import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/domain/entities/music_enums.dart';
import 'package:resonance/domain/entities/track_source.dart';
import 'package:resonance/domain/repositories/secure_token_repository.dart';
import 'package:resonance/providers/yandex/backend_yandex_provider.dart';

void main() {
  test('passes the secure Yandex token and maps search results', () async {
    final client = _FakeYandexBackendClient();
    final provider = BackendYandexProvider(
      client,
      _FakeTokens('secure-user-token'),
    );

    final tracks = await provider.searchTracks('Кино', limit: 10);

    expect(client.lastToken, 'secure-user-token');
    expect(tracks, hasLength(1));
    expect(tracks.single.title, 'Пачка сигарет');
    expect(tracks.single.artist, 'Кино');
    expect(tracks.single.preferredProvider, MusicProvider.yandex);
    expect(tracks.single.sourceFor(MusicProvider.yandex)?.externalId, '42');
  });

  test('maps an expiring Yandex stream response', () async {
    final client = _FakeYandexBackendClient();
    final provider = BackendYandexProvider(client, _FakeTokens('token'));
    final source = TrackSource(
      provider: MusicProvider.yandex,
      externalId: '42',
      externalUrl: Uri.parse('https://music.yandex.ru/track/42'),
    );

    final resolved = await provider.resolve(source);

    expect(client.lastToken, 'token');
    expect(resolved.protocol, StreamProtocol.progressive);
    expect(resolved.codec, 'mp3');
    expect(resolved.bitrate, 320000);
    expect(resolved.streamUrl.host, 'strm.yandex.net');
  });
}

final class _FakeYandexBackendClient implements YandexBackendClient {
  String? lastToken;

  @override
  Future<List<Map<String, dynamic>>> searchYandex(
    String query, {
    required int limit,
    String? token,
  }) async {
    lastToken = token;
    return [
      {
        'id': '42',
        'title': 'Пачка сигарет',
        'artist': 'Кино',
        'album': 'Звезда по имени Солнце',
        'durationMs': 275000,
        'artworkUrl':
            'https://avatars.yandex.net/get-music-content/cover/400x400',
        'externalUrl': 'https://music.yandex.ru/track/42',
      },
    ];
  }

  @override
  Future<Map<String, dynamic>> resolveYandex(
    String externalId, {
    required AudioQuality quality,
    String? token,
  }) async {
    lastToken = token;
    return {
      'streamUrl': 'https://strm.yandex.net/audio.mp3',
      'protocol': 'progressive',
      'codec': 'mp3',
      'bitrate': 320000,
      'expiresAt': '2033-05-18T03:33:20.000Z',
    };
  }
}

final class _FakeTokens implements SecureTokenRepository {
  _FakeTokens(this.token);

  String? token;

  @override
  Future<void> delete(MusicProvider provider) async => token = null;

  @override
  Future<String?> read(MusicProvider provider) async => token;

  @override
  Future<void> write(MusicProvider provider, String token) async {
    this.token = token;
  }
}
