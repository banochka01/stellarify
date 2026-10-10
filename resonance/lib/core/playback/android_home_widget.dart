import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/app/providers.dart';
import 'package:resonance/core/desktop/quick_actions.dart';
import 'package:resonance/domain/entities/playback_state.dart';

/// Bridge to the native home-screen widget (android/.../ResonanceWidgetProvider.kt).
///
/// Dart pushes the now-playing snapshot; the widget's "Моя волна" button
/// opens the app with an action that arrives back through this channel.
/// Play/pause/next on the widget go straight to the audio_service media
/// session, so they work without the Flutter UI.
const homeWidgetChannel = MethodChannel('resonance/home_widget');

final androidHomeWidgetProvider = Provider<AndroidHomeWidget?>((ref) {
  if (!Platform.isAndroid) return null;
  final widget = AndroidHomeWidget(ref);
  unawaited(widget.start());
  ref.onDispose(() => unawaited(widget.dispose()));
  return widget;
});

final class AndroidHomeWidget {
  AndroidHomeWidget(this._ref);

  final Ref _ref;
  StreamSubscription<ResonancePlaybackState>? _subscription;
  Map<String, Object?>? _last;
  bool _disposed = false;

  Future<void> start() async {
    homeWidgetChannel.setMethodCallHandler((call) async {
      if (call.method == 'action') await _run(call.arguments as String?);
    });
    try {
      final launch = await homeWidgetChannel.invokeMethod<String>(
        'consumeLaunchAction',
      );
      await _run(launch);
    } on Object catch (error) {
      log(
        'Home widget bridge unavailable',
        name: 'resonance.home_widget',
        error: error,
      );
    }
    final service = await _ref.read(playbackServiceProvider.future);
    if (_disposed) return;
    _subscription = service.states.listen(_publish);
    _publish(service.state);
  }

  Future<void> _run(String? raw) async {
    final action = QuickAction.parse(raw);
    if (action == null) return;
    try {
      await _ref.read(quickActionsProvider).run(action);
    } on Object catch (error) {
      log('Widget action failed', name: 'resonance.home_widget', error: error);
    }
  }

  void _publish(ResonancePlaybackState state) {
    final payload = homeWidgetPayload(state);
    if (_last != null && _mapEquals(_last!, payload)) return;
    _last = payload;
    unawaited(
      homeWidgetChannel
          .invokeMethod<void>('update', payload)
          .catchError((Object _) {}),
    );
  }

  Future<void> dispose() async {
    _disposed = true;
    homeWidgetChannel.setMethodCallHandler(null);
    await _subscription?.cancel();
  }
}

Map<String, Object?> homeWidgetPayload(ResonancePlaybackState state) {
  final track = state.currentTrack;
  return {
    'title': track?.title ?? 'Resonance',
    'artist': track?.artist ?? 'Нажмите «Моя волна»',
    'artworkUrl': track?.artworkUrl?.toString(),
    'playing': state.playing,
  };
}

bool _mapEquals(Map<String, Object?> a, Map<String, Object?> b) =>
    a.length == b.length && a.keys.every((key) => a[key] == b[key]);
