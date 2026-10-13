import 'dart:async';

import 'package:audio_service/audio_service.dart' as audio_service;
import 'package:flutter/services.dart';
import 'package:resonance/core/playback/media_browse_catalog.dart';

/// Serves [MediaBrowseCatalog] to the native CarPlay templates
/// (`ios/Runner/CarPlaySceneDelegate.swift`). Harmless when CarPlay is
/// disabled: the native side then never calls the channel.
abstract final class CarPlayBridge {
  static const channel = MethodChannel('app.resonance/carplay');
  static Completer<MediaBrowseCatalog> _catalog = Completer();

  /// Registers the channel handler at app start. [warmUp] initializes
  /// playback (which calls [attach]) when CarPlay connects before any UI.
  static void install(Future<Object?> Function() warmUp) {
    channel.setMethodCallHandler((call) async {
      if (!_catalog.isCompleted) unawaited(warmUp());
      final catalog = await _catalog.future.timeout(
        const Duration(seconds: 20),
      );
      return handle(catalog, call);
    });
  }

  /// Provides the catalog once playback is ready.
  static void attach(MediaBrowseCatalog catalog) {
    if (_catalog.isCompleted) _catalog = Completer();
    _catalog.complete(catalog);
  }

  static Future<Object?> handle(
    MediaBrowseCatalog catalog,
    MethodCall call,
  ) async {
    final args = (call.arguments as Map?)?.cast<String, Object?>() ?? {};
    switch (call.method) {
      case 'children':
        final parent = args['parentId'] as String? ?? 'root';
        final items = await catalog.children(
          parent == 'root' ? audio_service.AudioService.browsableRootId : parent,
        );
        return [
          for (final item in items)
            {
              'id': item.id,
              'title': item.title,
              'subtitle': item.artist ?? item.album,
              'playable': item.playable ?? false,
            },
        ];
      case 'play':
        final mediaId = args['mediaId'] as String?;
        if (mediaId != null) await catalog.playFromMediaId(mediaId);
        return null;
    }
    throw MissingPluginException(call.method);
  }
}
