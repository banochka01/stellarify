import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/app/providers.dart';
import 'package:resonance/core/playback/demo_track.dart';
import 'package:resonance/domain/entities/playback_state.dart';
import 'package:resonance/features/lyrics/lyrics_service.dart';
import 'package:resonance/features/player/visual_stage_screen.dart';

void main() {
  testWidgets('shows cinematic lyrics and disables clip without video', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = ResonancePlaybackState(
      queue: [demoTrack],
      currentIndex: 0,
      playing: true,
      position: const Duration(seconds: 8),
      duration: const Duration(minutes: 2),
    );
    final lyrics = LyricsDocument(
      id: 1,
      synced: true,
      instrumental: false,
      lines: const [
        LyricLine(text: 'Первая строка', start: Duration.zero),
        LyricLine(text: 'Активная строка', start: Duration(seconds: 5)),
        LyricLine(text: 'Следующая строка', start: Duration(seconds: 12)),
      ],
      sourceUrl: Uri.parse('https://lrclib.net'),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          playbackStateProvider.overrideWith((ref) => Stream.value(state)),
          playbackVideoAvailableProvider.overrideWith(
            (ref) => Stream.value(false),
          ),
          playbackVideoControllerProvider.overrideWithValue(null),
          lyricsProvider.overrideWith((ref, track) async => lyrics),
        ],
        child: const MaterialApp(home: VisualStageScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Нет клипа'), findsOneWidget);
    expect(find.text('Lyrics'), findsOneWidget);
    expect(find.text('Активная строка'), findsOneWidget);
    final selector = tester.widget<SegmentedButton<VisualStageMode>>(
      find.byType(SegmentedButton<VisualStageMode>),
    );
    expect(selector.segments.first.enabled, isFalse);
  });

  for (final viewport in const [Size(390, 844), Size(844, 390)]) {
    testWidgets('visual stage fits ${viewport.width}x${viewport.height}', (
      tester,
    ) async {
      tester.view.physicalSize = viewport;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final state = ResonancePlaybackState(
        queue: [demoTrack],
        currentIndex: 0,
        playing: true,
        position: const Duration(seconds: 8),
        duration: const Duration(minutes: 2),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            playbackStateProvider.overrideWith((ref) => Stream.value(state)),
            playbackVideoAvailableProvider.overrideWith(
              (ref) => Stream.value(false),
            ),
            playbackVideoControllerProvider.overrideWithValue(null),
            lyricsProvider.overrideWith(
              (ref, track) async => LyricsDocument(
                id: 2,
                synced: true,
                instrumental: false,
                lines: const [
                  LyricLine(text: 'Первая строка', start: Duration.zero),
                  LyricLine(
                    text: 'Активная строка на небольшом экране',
                    start: Duration(seconds: 5),
                  ),
                ],
                sourceUrl: Uri.parse('https://lrclib.net'),
              ),
            ),
          ],
          child: const MaterialApp(home: VisualStageScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Активная строка на небольшом экране'), findsOneWidget);
    });
  }
}
