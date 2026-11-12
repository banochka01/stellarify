import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/core/playback/audio_effects.dart';

void main() {
  test('level meter goes last in the chain and only when supported', () {
    const support = AudioFilterSupport(equalizer: true, astats: true);
    final chain = buildAudioFilterChain(
      support: support,
      equalizerGains: List<double>.filled(equalizerBands.length, 3),
      level: true,
    );
    expect(chain.split(',').last, '@level:astats=metadata=1:reset=1');
    expect(
      buildAudioFilterChain(
        support: const AudioFilterSupport(equalizer: true),
        level: true,
      ),
      isNot(contains('astats')),
    );
    expect(buildAudioFilterChain(support: support), isNot(contains('astats')));
  });

  test('astats peak is parsed from mpv metadata', () {
    expect(
      parseAstatsPeakDb('{"lavfi.astats.Overall.Peak_level":"-6.020600"}'),
      closeTo(-6.02, .001),
    );
    expect(
      parseAstatsPeakDb('lavfi.astats.Overall.Peak_level=-inf'),
      -120,
    );
    expect(parseAstatsPeakDb('{"lavfi.r128.M":"-20"}'), isNull);
    expect(parseAstatsPeakDb(null), isNull);
  });
}
