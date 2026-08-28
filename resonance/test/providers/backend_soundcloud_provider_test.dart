import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/core/networking/soundcloud_proxy_preference.dart';
import 'package:resonance/domain/entities/music_enums.dart';
import 'package:resonance/domain/entities/track_source.dart';
import 'package:resonance/domain/repositories/secure_token_repository.dart';
import 'package:resonance/providers/soundcloud/backend_soundcloud_provider.dart';

void main() {
  test('resolves a relative relay URL against the configured backend', () {
    expect(
      resolveBackendStreamUrl(
        Uri.parse('https://music.example/base'),
        '/api/v1/playback/soundcloud-relay/ticket',
      ).toString(),
      'https://music.example/api/v1/playback/soundcloud-relay/ticket',
    );
    expect(
      resolveBackendStreamUrl(
        Uri.parse('https://music.example'),
        'https://cf-media.sndcdn.com/track.mp3',
      ).toString(),
      'https://cf-media.sndcdn.com/track.mp3',
    );
  });

  test('maps backend search results to a provider-neutral track', () async {
    final client = _FakeBackendClient();
    final provider = BackendSoundCloudProvider(
      client,
      _FakeTokens('secure-soundcloud-token'),
      _FakeProxyPreference(true),
    );

    final tracks = await provider.searchTracks('Tycho', limit: 10);

    expect(tracks, hasLength(1));
    expect(tracks.single.title, 'Awake');
    expect(tracks.single.artist, 'Tycho');
    expect(tracks.single.duration, const Duration(seconds: 123));
    expect(
      tracks.single.sourceFor(MusicProvider.soundcloud)?.externalId,
      'soundcloud:tracks:42',
    );
    expect(client.lastToken, 'secure-soundcloud-token');
    expect(client.lastUseProxy, isTrue);
  });

  test('maps an expiring AAC HLS playback response', () async {
    final client = _FakeBackendClient();
    final provider = BackendSoundCloudProvider(
      client,
      _FakeTokens('token'),
      _FakeProxyPreference(false),
    );
    final source = TrackSource(
      provider: MusicProvider.soundcloud,
      externalId: 'soundcloud:tracks:42',
      externalUrl: Uri.parse('https://soundcloud.com/tycho/awake'),
    );

    final resolved = await provider.resolve(source);

    expect(resolved.protocol, StreamProtocol.hls);
    expect(resolved.codec, 'aac');
    expect(resolved.bitrate, 160000);
    expect(resolved.streamUrl.host, 'cf-hls-media.sndcdn.com');
    expect(resolved.expiresAt, DateTime.utc(2033, 5, 18, 3, 33, 20));
    expect(client.lastToken, 'token');
  });

  test('drops a stale browser cookie and uses server credentials', () async {
    final client = _FakeBackendClient();
    final tokens = _FakeTokens('2-329470-1718068196-example');
    final provider = BackendSoundCloudProvider(
      client,
      tokens,
      _FakeProxyPreference(false),
    );

    await provider.searchTracks('Tycho');

    expect(client.lastToken, isNull);
    expect(tokens.token, isNull);
  });
}

final class _FakeBackendClient implements ResonanceBackendClient {
  String? lastToken;
  bool? lastUseProxy;

  @override
  Future<void> validateProvider({
    required MusicProvider provider,
    required String token,
    bool useProxy = false,
  }) async {}

  @override
  Future<Map<MusicProvider, bool>> serverCredentialStatus() async => const {};

  @override
  Future<Map<String, dynamic>> resolveSoundCloud(
    String externalId, {
    required AudioQuality quality,
    String? token,
    bool useProxy = false,
  }) async {
    lastToken = token;
    lastUseProxy = useProxy;
    return {
      'streamUrl': 'https://cf-hls-media.sndcdn.com/awake.m3u8',
      'protocol': 'hls',
      'codec': 'aac',
      'bitrate': 160000,
      'expiresAt': '2033-05-18T03:33:20.000Z',
    };
  }

  @override
  Future<List<Map<String, dynamic>>> searchSoundCloud(
    String query, {
    required int limit,
    String? token,
    bool useProxy = false,
  }) async {
    lastToken = token;
    lastUseProxy = useProxy;
    return [
      {
        'id': 'soundcloud:tracks:42',
        'title': 'Awake',
        'artist': 'Tycho',
        'durationMs': 123000,
        'artworkUrl': 'https://i1.sndcdn.com/artwork.jpg',
        'externalUrl': 'https://soundcloud.com/tycho/awake',
      },
    ];
  }
}

final class _FakeProxyPreference implements SoundCloudProxyPreference {
  _FakeProxyPreference(this.enabled);

  bool enabled;

  @override
  Future<bool> read() async => enabled;

  @override
  Future<void> write(bool enabled) async => this.enabled = enabled;
}

final class _FakeTokens implements SecureTokenRepository {
  _FakeTokens(this.token);

  String? token;

  @override
  Future<String?> read(MusicProvider provider) async => token;

  @override
  Future<void> write(MusicProvider provider, String token) async {}

  @override
  Future<void> delete(MusicProvider provider) async => token = null;
}
