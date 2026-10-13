import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/core/preferences/appearance_preferences.dart';
import 'package:resonance/domain/entities/music_enums.dart';
import 'package:resonance/domain/entities/unified_track.dart';
import 'package:resonance/shared/theme/resonance_theme.dart';
import 'package:resonance/shared/widgets/ambient.dart';
import 'package:resonance/shared/widgets/resonance_states.dart';

void main() {
  group('contrast', () {
    for (final preset in ResonanceThemePreset.values) {
      test('${preset.name}: text tokens meet WCAG AA', () {
        final theme = ResonanceTheme.forPreset(preset);
        final tokens = theme.extension<ResonanceTokens>()!;
        for (final surface in [
          tokens.background,
          tokens.surface,
          tokens.surfaceRaised,
        ]) {
          expect(
            ResonanceContrast.ratio(tokens.text, surface),
            greaterThanOrEqualTo(ResonanceContrast.aa),
          );
          expect(
            ResonanceContrast.ratio(tokens.textMuted, surface),
            greaterThanOrEqualTo(ResonanceContrast.aa),
            reason: 'muted on $surface',
          );
          expect(
            ResonanceContrast.ratio(tokens.textSubtle, surface),
            greaterThanOrEqualTo(ResonanceContrast.aaLarge),
          );
          expect(
            ResonanceContrast.ratio(tokens.accent, surface),
            greaterThanOrEqualTo(ResonanceContrast.aaLarge),
          );
        }
        // Filled buttons draw near-black on the accent.
        expect(
          ResonanceContrast.ratio(const Color(0xFF090706), tokens.accent),
          greaterThanOrEqualTo(ResonanceContrast.aa),
        );
      });
    }

    test('ensure() lifts dark accents to a legible colour', () {
      const bg = Color(0xFF060606);
      final fixed = ResonanceContrast.ensure(const Color(0xFF1C1340), bg);
      expect(
        ResonanceContrast.ratio(fixed, bg),
        greaterThanOrEqualTo(ResonanceContrast.aaLarge),
      );
    });

    test('fallback artwork accent is legible on the background', () {
      for (var i = 0; i < 12; i++) {
        final track = UnifiedTrack(
          id: 't$i',
          title: 'Track $i',
          normalizedTitle: 'track $i',
          artist: 'Artist ${i * 7}',
          normalizedArtist: 'artist',
          sources: const [],
          preferredProvider: MusicProvider.soundcloud,
        );
        final accent = ResonanceContrast.ensure(
          TrackPalette.fallback(track).accent,
          ResonanceTokens.fallback.background,
        );
        expect(
          ResonanceContrast.ratio(accent, ResonanceTokens.fallback.background),
          greaterThanOrEqualTo(ResonanceContrast.aaLarge),
        );
      }
    });
  });

  group('states', () {
    Widget host(Widget child, {bool reduceMotion = false}) => MaterialApp(
      theme: ResonanceTheme.forPreset(ResonanceThemePreset.graphite),
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(360, 640),
          disableAnimations: reduceMotion,
        ),
        child: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );

    testWidgets('empty state renders title, message and action', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          ResonanceEmptyState(
            icon: Icons.queue_music_rounded,
            title: 'Очередь пуста',
            message: 'Запустите трек.',
            action: TextButton(onPressed: () {}, child: const Text('Волна')),
          ),
        ),
      );
      expect(find.text('Очередь пуста'), findsOneWidget);
      expect(find.text('Запустите трек.'), findsOneWidget);
      expect(find.text('Волна'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('compact empty state fits 360px', (tester) async {
      await tester.pumpWidget(
        host(
          const ResonanceEmptyState(
            icon: Icons.favorite_border_rounded,
            title: 'Очень длинный заголовок пустого состояния для проверки',
            message: 'И столь же длинное пояснение, которое переносится.',
            compact: true,
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('skeleton shimmer settles and is static with reduce motion', (
      tester,
    ) async {
      await tester.pumpWidget(host(const ResonanceTrackListSkeleton()));
      expect(find.byType(ResonanceTrackRowSkeleton), findsNWidgets(5));
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpAndSettle();
    });

    testWidgets('skeleton is static with reduce motion', (tester) async {
      await tester.pumpWidget(
        host(const ResonanceTrackListSkeleton(), reduceMotion: true),
      );
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
    });
  });
}
