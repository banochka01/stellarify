import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/app/providers.dart';
import 'package:resonance/core/playback/demo_track.dart';
import 'package:resonance/domain/entities/playback_state.dart';
import 'package:resonance/features/lyrics/lyrics_service.dart';
import 'package:resonance/features/player/clip_service.dart';
import 'package:resonance/features/player/stage_clip_video.dart';
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
          stageClipsProvider.overrideWith((ref, track) async => []),
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
    expect(find.text('Текст'), findsOneWidget);
    expect(find.text('Активная строка'), findsOneWidget);
    final selector = tester.widget<SegmentedButton<VisualStageMode>>(
      find.byType(SegmentedButton<VisualStageMode>),
    );
    expect(selector.segments.first.enabled, isFalse);
  });

  testWidgets(
    'server clips fall back, can be disabled, and keep focus controls usable',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final clips = [
        for (final id in ['first', 'second'])
          StageClip(
            id: id,
            url: Uri.parse('https://example.com/$id.mp4'),
            title: id,
            source: 'Test source',
            sourceUrl: Uri.parse('https://example.com'),
            kind: StageClipKind.ambient,
            playable: true,
          ),
      ];
      VoidCallback? failVideo;
      String? currentVideo;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            playbackStateProvider.overrideWith(
              (ref) => Stream.value(
                ResonancePlaybackState(
                  queue: [demoTrack],
                  currentIndex: 0,
                  duration: const Duration(minutes: 2),
                ),
              ),
            ),
            playbackVideoAvailableProvider.overrideWith(
              (ref) => Stream.value(false),
            ),
            playbackVideoControllerProvider.overrideWithValue(null),
            stageClipsProvider.overrideWith((ref, track) async => clips),
            stageVideoBuilderProvider.overrideWithValue((clip, state, onError) {
              failVideo = onError;
              currentVideo = clip.id;
              return const ColoredBox(
                key: ValueKey('test-video'),
                color: Color(0xFF25253B),
              );
            }),
            lyricsProvider.overrideWith((ref, track) async => null),
          ],
          child: const MaterialApp(
            home: VisualStageScreen(initialMode: VisualStageMode.video),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(currentVideo, 'first');
      expect(find.text('Текст пока не найден'), findsNothing);
      failVideo!();
      await tester.pumpAndSettle();
      expect(currentVideo, 'second');
      await tester.tap(find.byTooltip('Скрыть управление'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Следующий трек'), findsNothing);
      expect(find.textContaining('Test source'), findsOneWidget);
      await tester.tap(find.byTooltip('Показать управление'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Видеоисточники'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Только обложка'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('test-video')), findsNothing);
      expect(find.text('Видео выключено'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failed source discovery retries without replacing the audio player',
    (tester) async {
      var requests = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            playbackStateProvider.overrideWith(
              (ref) => Stream.value(const ResonancePlaybackState()),
            ),
            playbackVideoAvailableProvider.overrideWith(
              (ref) => Stream.value(false),
            ),
            playbackVideoControllerProvider.overrideWithValue(null),
            stageClipsProvider.overrideWith((ref, track) async {
              if (++requests == 1) throw StateError('offline');
              return [];
            }),
            lyricsProvider.overrideWith((ref, track) async => null),
          ],
          child: const MaterialApp(home: VisualStageScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Источники недоступны · Повторить'));
      await tester.pumpAndSettle();
      expect(requests, 2);
      expect(
        find.textContaining('Для этого трека пока нет видео'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

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
            stageClipsProvider.overrideWith((ref, track) async => []),
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
