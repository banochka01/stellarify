import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/app/providers.dart';
import 'package:resonance/core/preferences/appearance_preferences.dart';
import 'package:resonance/core/preferences/onboarding_preferences.dart';
import 'package:resonance/core/security/flutter_secure_token_repository.dart';
import 'package:resonance/domain/entities/music_enums.dart';
import 'package:resonance/features/onboarding/onboarding_feature.dart';
import 'package:resonance/providers/soundcloud/backend_soundcloud_provider.dart';
import 'package:resonance/shared/theme/resonance_theme.dart';

void main() {
  testWidgets('completes the four-step first-run flow', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final store = _MemoryStore();
    var completed = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          secureKeyValueStoreProvider.overrideWithValue(store),
          resonanceBackendClientProvider.overrideWithValue(_FakeBackend()),
        ],
        child: MaterialApp(
          theme: ResonanceTheme.forPreset(ResonanceThemePreset.graphite),
          home: OnboardingScreen(onCompleted: () => completed = true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ВАША МУЗЫКА.\nОДИН ПУЛЬС.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('onboarding-next')));
    await tester.pumpAndSettle();
    expect(find.text('Где живёт ваша музыка?'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('onboarding-next')));
    await tester.pumpAndSettle();
    expect(find.text('Войдите в свой ритм'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('onboarding-next')));
    await tester.pumpAndSettle();
    expect(find.text('Настройте Resonance под себя'), findsOneWidget);
    await tester.tap(find.text('Лучшее доступное'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('onboarding-next')));
    await tester.pumpAndSettle();

    expect(completed, isTrue);
    final settings = await OnboardingPreferences(store).read();
    expect(settings.completed, isTrue);
    expect(settings.quality, AudioQuality.lossless);
  });
}

final class _MemoryStore implements SecureKeyValueStore {
  final values = <String, String>{};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

final class _FakeBackend implements ResonanceBackendClient {
  @override
  Future<Map<MusicProvider, bool>> serverCredentialStatus() async => {
    MusicProvider.soundcloud: true,
  };

  @override
  Future<void> validateProvider({
    required MusicProvider provider,
    required String token,
    bool useProxy = false,
  }) async {}

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
