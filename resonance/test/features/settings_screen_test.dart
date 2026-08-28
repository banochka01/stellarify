import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/app/providers.dart';
import 'package:resonance/app/resonance_app.dart';
import 'package:resonance/app/router.dart';
import 'package:resonance/core/networking/soundcloud_proxy_preference.dart';
import 'package:resonance/domain/entities/music_enums.dart';
import 'package:resonance/domain/repositories/secure_token_repository.dart';
import 'package:resonance/providers/soundcloud/backend_soundcloud_provider.dart';

import '../helpers/fake_playback_engine.dart';

void main() {
  testWidgets('stores a SoundCloud Client ID from Settings', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final tokens = _MemoryTokens();
    final proxy = _MemoryProxyPreference();
    final backend = _FakeBackendClient();
    resonanceRouter.go('/settings');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          secureTokenRepositoryProvider.overrideWithValue(tokens),
          soundCloudProxyPreferenceProvider.overrideWithValue(proxy),
          resonanceBackendClientProvider.overrideWithValue(backend),
          playbackEngineProvider.overrideWithValue(FakePlaybackEngine()),
          playbackPersistenceProvider.overrideWithValue(null),
        ],
        child: const ResonanceApp(),
      ),
    );
    await tester.pumpAndSettle();

    final field = find.byKey(const ValueKey('soundcloud-token-field'));
    await tester.scrollUntilVisible(
      field,
      260,
      scrollable: find.byType(Scrollable).first,
    );
    const clientId = '12345678901234567890123456789012';
    await tester.enterText(field, '  $clientId  ');
    final card = find.ancestor(of: field, matching: find.byType(Card)).first;
    final saveButton = find.descendant(
      of: card,
      matching: find.text('Сохранить безопасно'),
    );
    await tester.scrollUntilVisible(
      saveButton,
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(tokens.values[MusicProvider.soundcloud], clientId);
    expect(backend.validatedToken, clientId);
    expect(
      find.text('SoundCloud Client ID проверен и подключён.'),
      findsOneWidget,
    );

    final proxySwitch = find.byKey(const ValueKey('soundcloud-proxy-switch'));
    await tester.scrollUntilVisible(
      proxySwitch,
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(proxySwitch);
    await tester.pumpAndSettle();
    await tester.tap(proxySwitch);
    await tester.pumpAndSettle();
    expect(proxy.enabled, isTrue);
    resonanceRouter.go('/');
  });
}

final class _MemoryProxyPreference implements SoundCloudProxyPreference {
  bool enabled = false;

  @override
  Future<bool> read() async => enabled;

  @override
  Future<void> write(bool enabled) async => this.enabled = enabled;
}

final class _FakeBackendClient implements ResonanceBackendClient {
  String? validatedToken;

  @override
  Future<void> validateProvider({
    required MusicProvider provider,
    required String token,
    bool useProxy = false,
  }) async {
    validatedToken = token;
  }

  @override
  Future<Map<MusicProvider, bool>> serverCredentialStatus() async => {
    MusicProvider.soundcloud: true,
  };

  @override
  Future<Map<String, dynamic>> resolveSoundCloud(
    String externalId, {
    required AudioQuality quality,
    String? token,
    bool useProxy = false,
  }) => throw UnimplementedError();

  @override
  Future<List<Map<String, dynamic>>> searchSoundCloud(
    String query, {
    required int limit,
    String? token,
    bool useProxy = false,
  }) => throw UnimplementedError();
}

final class _MemoryTokens implements SecureTokenRepository {
  final values = <MusicProvider, String>{};

  @override
  Future<void> delete(MusicProvider provider) async {
    values.remove(provider);
  }

  @override
  Future<String?> read(MusicProvider provider) async => values[provider];

  @override
  Future<void> write(MusicProvider provider, String token) async {
    values[provider] = token.trim();
  }
}
