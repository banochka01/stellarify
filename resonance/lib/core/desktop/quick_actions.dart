import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/app/providers.dart';
import 'package:resonance/features/library/library_controller.dart';
import 'package:resonance/features/player/track_action.dart';
import 'package:resonance/features/wave/wave_controller.dart';

/// Actions shared by the Windows tray, global hotkeys, taskbar jump list and
/// the Android home-screen widget.
enum QuickAction {
  wave,
  lastPlaylist,
  playPause,
  pause,
  next,
  previous,
  like,
  toggleCompact;

  /// Parses `wave`, `--action=wave` and `resonance://action/wave`.
  static QuickAction? parse(String? raw) {
    if (raw == null) return null;
    var value = raw.trim();
    if (value.startsWith('--action=')) value = value.substring(9);
    final uri = Uri.tryParse(value);
    if (uri != null && uri.scheme == 'resonance') {
      value = uri.pathSegments.isEmpty ? uri.host : uri.pathSegments.last;
    }
    for (final action in values) {
      if (action.name.toLowerCase() == value.toLowerCase()) return action;
    }
    return null;
  }
}

const lastPlaylistStorageKey = 'resonance.quick_actions.last_playlist';

final compactModeProvider = StateProvider<bool>((ref) => false);

final quickActionsProvider = Provider<QuickActions>(QuickActions.new);

final class QuickActions {
  QuickActions(this._ref);

  final Ref _ref;

  Future<void> run(QuickAction action) async {
    switch (action) {
      case QuickAction.wave:
        await _ref.read(waveControllerProvider.notifier).start();
      case QuickAction.lastPlaylist:
        await _playLastPlaylist();
      case QuickAction.playPause:
        final service = await _ref.read(playbackServiceProvider.future);
        if (service.state.playing) {
          await service.pause();
        } else {
          await service.play();
        }
      case QuickAction.pause:
        final service = await _ref.read(playbackServiceProvider.future);
        await service.pause();
      case QuickAction.next:
        final service = await _ref.read(playbackServiceProvider.future);
        await service.next();
      case QuickAction.previous:
        final service = await _ref.read(playbackServiceProvider.future);
        await service.previous();
      case QuickAction.like:
        final service = await _ref.read(playbackServiceProvider.future);
        final track = service.state.currentTrack;
        if (track != null) {
          await _ref
              .read(libraryControllerProvider.notifier)
              .toggleFavorite(track);
        }
      case QuickAction.toggleCompact:
        final compact = _ref.read(compactModeProvider.notifier);
        compact.state = !compact.state;
    }
  }

  Future<void> _playLastPlaylist() async {
    final database = _ref.read(appDatabaseProvider);
    var id = await _ref
        .read(secureKeyValueStoreProvider)
        .read(lastPlaylistStorageKey);
    if (id == null) {
      final summaries = await database.loadLocalPlaylistSummaries();
      id = summaries.firstOrNull?.id;
    }
    if (id == null) return;
    final tracks = playableQueueTracks(
      await database.loadLocalPlaylistTracks(id),
    );
    if (tracks.isEmpty) return;
    final service = await _ref.read(playbackServiceProvider.future);
    await service.setQueue(tracks, autoplay: true);
  }
}
