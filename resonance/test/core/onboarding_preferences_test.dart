import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/core/preferences/onboarding_preferences.dart';
import 'package:resonance/core/security/flutter_secure_token_repository.dart';
import 'package:resonance/domain/entities/music_enums.dart';

void main() {
  test('uses safe onboarding defaults', () async {
    final preferences = OnboardingPreferences(_MemoryStore());

    final settings = await preferences.read();

    expect(settings.completed, isFalse);
    expect(settings.providers, containsAll(MusicProvider.values));
    expect(settings.quality, AudioQuality.high);
  });

  test('persists completion, providers and playback quality', () async {
    final preferences = OnboardingPreferences(_MemoryStore());

    await preferences.complete(
      providers: const {MusicProvider.yandex, MusicProvider.soundcloud},
      quality: AudioQuality.lossless,
    );
    final settings = await preferences.read();

    expect(settings.completed, isTrue);
    expect(settings.providers, {
      MusicProvider.yandex,
      MusicProvider.soundcloud,
    });
    expect(settings.quality, AudioQuality.lossless);
  });

  test('rejects an empty provider selection', () {
    final preferences = OnboardingPreferences(_MemoryStore());

    expect(
      () =>
          preferences.complete(providers: const {}, quality: AudioQuality.high),
      throwsArgumentError,
    );
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
