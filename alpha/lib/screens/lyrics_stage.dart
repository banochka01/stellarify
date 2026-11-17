import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/app/providers.dart';
import 'package:resonance_alpha/audio/level.dart';
import 'package:resonance_alpha/design/accent.dart';
import 'package:resonance_alpha/design/blob.dart';
import 'package:resonance_alpha/design/tokens.dart';
import 'package:resonance_alpha/design/widgets.dart';
import 'package:resonance_alpha/screens/lyrics_view.dart';
import 'package:resonance_alpha/state.dart';
import 'package:window_manager/window_manager.dart';

/// The lyrics alone on a dark stage. The blob behind them breathes with the
/// music; on Windows the window goes full screen while the stage is open.
class LyricsStage extends ConsumerStatefulWidget {
  const LyricsStage({super.key});

  static Route<void> route() => PageRouteBuilder<void>(
    opaque: true,
    transitionDuration: Motion.slow,
    reverseTransitionDuration: Motion.base,
    pageBuilder: (_, _, _) => const LyricsStage(),
    transitionsBuilder: (_, animation, _, child) => FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Motion.curve),
      child: child,
    ),
  );

  @override
  ConsumerState<LyricsStage> createState() => _LyricsStageState();
}

class _LyricsStageState extends ConsumerState<LyricsStage> {
  bool _fullScreen = false;

  @override
  void initState() {
    super.initState();
    if (Platform.isWindows) _setFullScreen(true);
  }

  @override
  void dispose() {
    if (_fullScreen) windowManager.setFullScreen(false);
    super.dispose();
  }

  Future<void> _setFullScreen(bool value) async {
    try {
      await windowManager.setFullScreen(value);
      if (mounted) setState(() => _fullScreen = value);
    } on Object {
      // Not fatal: the stage still works inside the window.
    }
  }

  @override
  Widget build(BuildContext context) {
    final track = ref.watch(currentTrackProvider);
    final accent = ref.watch(currentAccentProvider);
    final playing = ref.watch(
      playbackStateProvider.select((s) => s.valueOrNull?.playing ?? false),
    );
    final size = MediaQuery.sizeOf(context);
    final wide = size.width >= 900;

    return Scaffold(
      backgroundColor: Pal.stage,
      body: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () =>
              Navigator.of(context).maybePop(),
          const SingleActivator(LogicalKeyboardKey.space): () =>
              run(context, () => togglePlay(ref)),
          if (Platform.isWindows)
            const SingleActivator(LogicalKeyboardKey.keyF): () =>
                _setFullScreen(!_fullScreen),
        },
        child: Focus(
          autofocus: true,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // The blob, enormous and dim: light, not an object.
              Positioned.fill(
                child: Opacity(
                  opacity: .32,
                  child: Transform.scale(
                    scale: 1.5,
                    child: LivingBlob(
                      color: Color.lerp(accent, Pal.stage, .25)!,
                      energy: playing ? 1 : .12,
                      sampler: ref.watch(levelSamplerProvider),
                    ),
                  ),
                ),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    radius: 1.1,
                    colors: [Color(0x66050505), Color(0xF2050505)],
                  ),
                ),
              ),
              if (track != null)
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: wide ? size.width * .12 : 24,
                    vertical: 96,
                  ),
                  child: LyricsView(
                    track: track,
                    accent: Color.lerp(accent, Pal.paper, .35)!,
                    size: wide ? 64 : 34,
                    centered: true,
                  ),
                )
              else
                Center(child: Text('Тишина', style: Txt.display(48))),
              SafeArea(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    wide ? 40 : 16,
                    12,
                    wide ? 40 : 16,
                    0,
                  ),
                  child: Row(
                    children: [
                      Knob(
                        icon: Icons.close_rounded,
                        size: 44,
                        tooltip: 'Закрыть · Esc',
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(width: 16),
                      if (track != null)
                        Expanded(
                          child: Text(
                            '${track.artist} — ${track.title}'.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Txt.mono(12, color: Pal.paper),
                          ),
                        )
                      else
                        const Spacer(),
                      Knob(
                        icon: playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        size: 44,
                        tooltip: 'Пауза · пробел',
                        onTap: () => run(context, () => togglePlay(ref)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
