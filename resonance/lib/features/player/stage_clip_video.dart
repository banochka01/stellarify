import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:resonance/domain/entities/playback_state.dart';
import 'package:resonance/features/player/clip_service.dart';

typedef StageVideoBuilder =
    Widget Function(
      StageClip clip,
      ResonancePlaybackState state,
      VoidCallback onError,
    );

final stageVideoBuilderProvider = Provider<StageVideoBuilder>(
  (ref) =>
      (clip, state, onError) => StageClipVideo(
        key: ValueKey('${state.currentTrack?.id}:${clip.url}'),
        clip: clip,
        state: state,
        onError: onError,
      ),
);

/// An independent, always-muted video player. Audio stays in PlaybackService.
class StageClipVideo extends StatefulWidget {
  const StageClipVideo({
    required this.clip,
    required this.state,
    required this.onError,
    super.key,
  });
  final StageClip clip;
  final ResonancePlaybackState state;
  final VoidCallback onError;

  @override
  State<StageClipVideo> createState() => _StageClipVideoState();
}

class _StageClipVideoState extends State<StageClipVideo> {
  late final Player _player;
  late final VideoController _controller;
  StreamSubscription<String>? _errors;
  bool _ready = false;
  bool _failed = false;
  bool _syncing = false;
  bool _syncAgain = false;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _player = Player(
      configuration: const PlayerConfiguration(title: 'Resonance Visual Stage'),
    );
    _controller = VideoController(_player);
    _errors = _player.stream.error.listen((_) => _fail());
    unawaited(_open());
  }

  void _fail() {
    if (!mounted || _failed) return;
    _failed = true;
    scheduleMicrotask(() {
      if (mounted) widget.onError();
    });
  }

  Future<void> _open() async {
    try {
      await _player.setVolume(0);
      if (!mounted) return;
      await _player.setPlaylistMode(
        widget.clip.ambient || widget.clip.preview
            ? PlaylistMode.single
            : PlaylistMode.none,
      );
      if (!mounted) return;
      await _player
          .open(Media(widget.clip.url!.toString()), play: false)
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;
      _ready = true;
      await _sync(force: true);
      await _controller.waitUntilFirstFrameRendered.timeout(
        const Duration(seconds: 15),
      );
      if (mounted && !_failed) setState(() => _visible = true);
    } catch (_) {
      _fail();
    }
  }

  @override
  void didUpdateWidget(covariant StageClipVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    unawaited(_sync());
  }

  Future<void> _sync({bool force = false}) async {
    if (!_ready || !mounted || _failed) return;
    if (_syncing) {
      _syncAgain = true;
      return;
    }
    _syncing = true;
    try {
      if (!widget.clip.ambient && !widget.clip.preview) {
        final wanted = widget.state.position + widget.clip.offset;
        final end = _player.state.duration;
        final position = Duration(
          milliseconds: wanted.inMilliseconds.clamp(
            0,
            end > Duration.zero ? end.inMilliseconds : 1 << 40,
          ),
        );
        if (force ||
            (_player.state.position - position).inMilliseconds.abs() > 1500) {
          await _player.seek(position);
        }
      }
      if (!mounted) return;
      final ended =
          !widget.clip.ambient &&
          !widget.clip.preview &&
          _player.state.duration > Duration.zero &&
          widget.state.position + widget.clip.offset >= _player.state.duration;
      final shouldPlay =
          widget.state.playing && !widget.state.buffering && !ended;
      if (shouldPlay != _player.state.playing) {
        if (shouldPlay) {
          await _player.play();
        } else {
          await _player.pause();
        }
      }
    } catch (_) {
      _fail();
    } finally {
      _syncing = false;
      if (_syncAgain) {
        _syncAgain = false;
        unawaited(_sync());
      }
    }
  }

  @override
  void dispose() {
    unawaited(_errors?.cancel());
    unawaited(_player.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      AnimatedOpacity(
        opacity: _visible ? 1 : 0,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 300),
        child: Video(
          controller: _controller,
          controls: NoVideoControls,
          fit: BoxFit.cover,
          fill: Colors.transparent,
        ),
      ),
      if (!_visible)
        const Center(
          child: SizedBox.square(
            dimension: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              semanticsLabel: 'Загрузка видео',
            ),
          ),
        ),
    ],
  );
}
