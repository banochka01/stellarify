import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:resonance/domain/entities/playback_state.dart';
import 'package:resonance/features/player/clip_service.dart';

/// Official YouTube player hosted on our page, always muted. Audio stays in
/// PlaybackService; the embed only follows its position and play state.
class StageClipEmbed extends StatefulWidget {
  const StageClipEmbed({
    required this.page,
    required this.clip,
    required this.state,
    required this.onError,
    super.key,
  });
  final Uri page;
  final StageClip clip;
  final ResonancePlaybackState state;
  final VoidCallback onError;

  @override
  State<StageClipEmbed> createState() => _StageClipEmbedState();
}

class _StageClipEmbedState extends State<StageClipEmbed> {
  InAppWebViewController? _controller;
  Timer? _readyTimeout;
  bool _ready = false;
  bool _visible = false;
  bool _failed = false;
  DateTime _lastSync = DateTime.fromMillisecondsSinceEpoch(0);
  bool? _lastPlaying;
  Duration _lastOffset = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _lastOffset = widget.clip.offset;
    _readyTimeout = Timer(const Duration(seconds: 20), () {
      if (!_ready) _fail();
    });
  }

  void _fail() {
    if (!mounted || _failed) return;
    _failed = true;
    scheduleMicrotask(() {
      if (mounted) widget.onError();
    });
  }

  @override
  void didUpdateWidget(covariant StageClipEmbed oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync({bool force = false}) {
    final controller = _controller;
    if (!_ready || controller == null || _failed) return;
    final playing = widget.state.playing && !widget.state.buffering;
    final now = DateTime.now();
    final changed =
        playing != _lastPlaying || widget.clip.offset != _lastOffset;
    if (!force && !changed && now.difference(_lastSync).inMilliseconds < 750) {
      return;
    }
    _lastSync = now;
    _lastPlaying = playing;
    _lastOffset = widget.clip.offset;
    final target = widget.state.position + widget.clip.offset;
    final ended = _duration > Duration.zero && target >= _duration;
    final seconds = target.inMilliseconds.clamp(0, 1 << 40) / 1000;
    unawaited(
      controller
          .evaluateJavascript(
            source:
                'window.stage && window.stage.sync($seconds, ${playing && !ended});',
          )
          .catchError((_) => null),
    );
  }

  void _onMessage(List<dynamic> args) {
    if (args.isEmpty || args.first is! Map) return;
    final message = args.first as Map;
    switch (message['type']) {
      case 'ready':
        _ready = true;
        _readyTimeout?.cancel();
        final duration = message['duration'];
        if (duration is num) {
          _duration = Duration(milliseconds: (duration * 1000).round());
        }
        _sync(force: true);
      case 'state':
      case 'time':
        // 1 = playing: show the frame only once real video is on screen.
        if (message['state'] == 1 && !_visible && mounted) {
          setState(() => _visible = true);
        }
      case 'error':
        _fail();
    }
  }

  @override
  void dispose() {
    _readyTimeout?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      IgnorePointer(
        child: AnimatedOpacity(
          opacity: _visible ? 1 : 0,
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 450),
          child: InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri.uri(widget.page)),
            initialSettings: InAppWebViewSettings(
              mediaPlaybackRequiresUserGesture: false,
              allowsInlineMediaPlayback: true,
              allowsPictureInPictureMediaPlayback: false,
              transparentBackground: true,
              disableContextMenu: true,
              supportZoom: false,
              disableHorizontalScroll: true,
              disableVerticalScroll: true,
              useShouldOverrideUrlLoading: true,
            ),
            onWebViewCreated: (controller) {
              _controller = controller;
              controller.addJavaScriptHandler(
                handlerName: 'stage',
                callback: (args) {
                  _onMessage(args);
                  return null;
                },
              );
            },
            // Никаких переходов внутри сцены: только страница плеера.
            shouldOverrideUrlLoading: (controller, action) async {
              final url = action.request.url;
              if (!action.isForMainFrame) return NavigationActionPolicy.ALLOW;
              return url != null && url.host == widget.page.host
                  ? NavigationActionPolicy.ALLOW
                  : NavigationActionPolicy.CANCEL;
            },
            onReceivedError: (controller, request, error) {
              if (request.isForMainFrame ?? true) _fail();
            },
            onReceivedHttpError: (controller, request, response) {
              if (request.isForMainFrame ?? true) _fail();
            },
          ),
        ),
      ),
      if (!_visible)
        const Center(
          child: SizedBox.square(
            dimension: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              semanticsLabel: 'Загрузка клипа',
            ),
          ),
        ),
    ],
  );
}
