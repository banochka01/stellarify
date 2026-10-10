import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:resonance/app/providers.dart';
import 'package:resonance/core/desktop/quick_actions.dart';
import 'package:resonance/domain/entities/playback_state.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

/// Native runner channel: jump-list tasks and second-instance launches arrive
/// here as `action` calls (see windows/runner/flutter_window.cpp).
const desktopActionsChannel = MethodChannel('resonance/desktop_actions');

/// Global shortcuts, active while the window is minimized or hidden.
final windowsHotkeys = <QuickAction, HotKey>{
  QuickAction.playPause: HotKey(
    identifier: 'resonance.playPause',
    key: PhysicalKeyboardKey.space,
    modifiers: [HotKeyModifier.control, HotKeyModifier.alt],
  ),
  QuickAction.next: HotKey(
    identifier: 'resonance.next',
    key: PhysicalKeyboardKey.arrowRight,
    modifiers: [HotKeyModifier.control, HotKeyModifier.alt],
  ),
  QuickAction.previous: HotKey(
    identifier: 'resonance.previous',
    key: PhysicalKeyboardKey.arrowLeft,
    modifiers: [HotKeyModifier.control, HotKeyModifier.alt],
  ),
  QuickAction.like: HotKey(
    identifier: 'resonance.like',
    key: PhysicalKeyboardKey.keyL,
    modifiers: [HotKeyModifier.control, HotKeyModifier.alt],
  ),
};

const compactWindowSize = Size(400, 112);

/// Launch actions passed on the command line (`--action=wave`) before the
/// shell is ready; consumed once the shell starts.
final pendingLaunchActions = <QuickAction>[];

final windowsShellProvider = Provider<WindowsShell?>((ref) {
  if (!Platform.isWindows || Platform.environment.containsKey('FLUTTER_TEST')) {
    return null;
  }
  final shell = WindowsShell(ref);
  unawaited(shell.start());
  ref.onDispose(() => unawaited(shell.dispose()));
  return shell;
});

final class WindowsShell with TrayListener {
  WindowsShell(this._ref);

  final Ref _ref;
  final _subscriptions = <StreamSubscription<Object?>>[];
  ProviderSubscription<bool>? _compactSubscription;
  String? _menuTrackId;
  bool? _menuPlaying;
  Rect? _restoreBounds;
  Size? _restoreMinimum;

  QuickActions get _actions => _ref.read(quickActionsProvider);

  Future<void> start() async {
    desktopActionsChannel.setMethodCallHandler((call) async {
      if (call.method != 'action') return;
      final action = QuickAction.parse(call.arguments as String?);
      if (action != null) await _run(action);
    });
    _compactSubscription = _ref.listen<bool>(
      compactModeProvider,
      (_, compact) => unawaited(_applyCompact(compact)),
    );
    await _guard('tray', _startTray);
    await _guard('hotkeys', _registerHotkeys);
    final service = await _ref.read(playbackServiceProvider.future);
    _subscriptions.add(service.states.listen(_updateTray));
    _updateTray(service.state);
    for (final action in List.of(pendingLaunchActions)) {
      await _run(action);
    }
    pendingLaunchActions.clear();
  }

  Future<void> _run(QuickAction action) async {
    try {
      await _actions.run(action);
    } on Object catch (error, stackTrace) {
      log(
        'Quick action ${action.name} failed',
        name: 'resonance.windows_shell',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _guard(String part, Future<void> Function() body) async {
    try {
      await body();
    } on Object catch (error, stackTrace) {
      log(
        'Windows $part integration is unavailable',
        name: 'resonance.windows_shell',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _startTray() async {
    trayManager.addListener(this);
    await trayManager.setIcon('assets/images/tray_icon.ico');
    await trayManager.setToolTip('Resonance');
  }

  Future<void> _registerHotkeys() async {
    await hotKeyManager.unregisterAll();
    for (final entry in windowsHotkeys.entries) {
      await hotKeyManager.register(
        entry.value,
        keyDownHandler: (_) => unawaited(_run(entry.key)),
      );
    }
  }

  void _updateTray(ResonancePlaybackState state) {
    final track = state.currentTrack;
    if (track?.id == _menuTrackId && state.playing == _menuPlaying) return;
    _menuTrackId = track?.id;
    _menuPlaying = state.playing;
    final nowPlaying = track == null
        ? 'Ничего не играет'
        : '${track.artist} — ${track.title}';
    final menu = Menu(
      items: [
        MenuItem(label: _ellipsize(nowPlaying, 60), disabled: true),
        MenuItem.separator(),
        MenuItem(
          label: state.playing ? 'Пауза' : 'Играть',
          disabled: track == null,
          onClick: (_) => unawaited(_run(QuickAction.playPause)),
        ),
        MenuItem(
          label: 'Следующий трек',
          disabled: track == null,
          onClick: (_) => unawaited(_run(QuickAction.next)),
        ),
        MenuItem(
          label: 'Предыдущий трек',
          disabled: track == null,
          onClick: (_) => unawaited(_run(QuickAction.previous)),
        ),
        MenuItem(
          label: 'Нравится',
          disabled: track == null,
          onClick: (_) => unawaited(_run(QuickAction.like)),
        ),
        MenuItem.separator(),
        MenuItem(
          label: 'Моя волна',
          onClick: (_) => unawaited(_run(QuickAction.wave)),
        ),
        MenuItem(
          label: 'Последний плейлист',
          onClick: (_) => unawaited(_run(QuickAction.lastPlaylist)),
        ),
        MenuItem.checkbox(
          label: 'Компактный режим поверх окон',
          checked: _ref.read(compactModeProvider),
          onClick: (_) => unawaited(_run(QuickAction.toggleCompact)),
        ),
        MenuItem.separator(),
        MenuItem(
          label: 'Открыть Resonance',
          onClick: (_) => unawaited(_showWindow()),
        ),
        MenuItem(
          label: 'Выход',
          onClick: (_) => unawaited(windowManager.destroy()),
        ),
      ],
    );
    unawaited(
      _guard('tray menu', () async {
        await trayManager.setContextMenu(menu);
        await trayManager.setToolTip(
          _ellipsize('Resonance · $nowPlaying', 120),
        );
      }),
    );
  }

  Future<void> _showWindow() async {
    if (await windowManager.isMinimized()) await windowManager.restore();
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> _applyCompact(bool compact) async {
    await _guard('compact mode', () async {
      if (compact) {
        if (await windowManager.isFullScreen()) {
          await windowManager.setFullScreen(false);
        }
        if (await windowManager.isMaximized()) await windowManager.unmaximize();
        _restoreBounds = await windowManager.getBounds();
        _restoreMinimum = const Size(980, 640);
        await windowManager.setMinimumSize(compactWindowSize);
        await windowManager.setSize(compactWindowSize);
        await windowManager.setAlwaysOnTop(true);
      } else {
        await windowManager.setAlwaysOnTop(false);
        await windowManager.setMinimumSize(
          _restoreMinimum ?? const Size(980, 640),
        );
        final bounds = _restoreBounds;
        if (bounds != null) await windowManager.setBounds(bounds);
      }
      await _showWindow();
    });
    // Rebuild the checkbox state.
    _menuTrackId = '\u0000';
    final service = await _ref.read(playbackServiceProvider.future);
    _updateTray(service.state);
  }

  @override
  void onTrayIconMouseDown() => unawaited(_showWindow());

  @override
  void onTrayIconRightMouseDown() => unawaited(trayManager.popUpContextMenu());

  Future<void> dispose() async {
    desktopActionsChannel.setMethodCallHandler(null);
    _compactSubscription?.close();
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    trayManager.removeListener(this);
    await _guard('dispose', () async {
      await hotKeyManager.unregisterAll();
      await trayManager.destroy();
    });
  }
}

String _ellipsize(String value, int max) =>
    value.length <= max ? value : '${value.substring(0, max - 1)}…';
