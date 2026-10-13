import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:resonance/app/providers.dart';
import 'package:resonance/app/resonance_app.dart';
import 'package:resonance/core/desktop/quick_actions.dart';
import 'package:resonance/core/desktop/windows_shell.dart';
import 'package:resonance/core/diagnostics/client_error_reporter.dart';
import 'package:resonance/core/networking/backend_endpoint.dart';
import 'package:resonance/core/platform/device_form.dart';
import 'package:resonance/core/platform/image_cache_budget.dart';
import 'package:resonance/core/playback/carplay_bridge.dart';
import 'package:resonance/core/playback/windows_media_controls.dart';
import 'package:window_manager/window_manager.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  ClientErrorReporter.instance.installGlobalHandlers();
  MediaKit.ensureInitialized();
  // Независимые платформенные вызовы до первого кадра идут параллельно:
  // защищённое хранилище, определение ТВ и SMTC не ждут друг друга.
  await Future.wait<Object?>([
    BackendEndpoint.initialize(),
    DeviceForm.initialize(),
    // Native media controls are optional. Their initialization must not keep
    // the window hidden when Windows or a native dependency rejects them.
    if (Platform.isWindows) WindowsMediaControls.initialize(),
  ]);
  applyImageCacheBudget(
    PaintingBinding.instance.imageCache,
    mobile: Platform.isAndroid || Platform.isIOS,
  );
  if (DeviceForm.isTelevision) {
    // D-pad navigation: always show focus highlights on Android TV. Arrow and
    // select/center keys are handled by WidgetsApp.defaultShortcuts.
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
  }
  if (Platform.isWindows) {
    pendingLaunchActions.addAll(args.map(QuickAction.parse).nonNulls);
  }
  if (DeviceForm.isDesktop) {
    await windowManager.ensureInitialized();
    final options = WindowOptions(
      size: Size(1280, 800),
      minimumSize: Size(980, 640),
      center: true,
      backgroundColor: Color(0xFF08060B),
      // Custom window chrome is drawn only on Windows (DesktopWindowBar).
      titleBarStyle: Platform.isWindows
          ? TitleBarStyle.hidden
          : TitleBarStyle.normal,
      windowButtonVisibility: !Platform.isWindows,
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }
  final container = ProviderContainer();
  if (Platform.isIOS) {
    // Registered before the first frame so a CarPlay cold start (no phone UI)
    // is answered; the first call initializes playback on demand.
    CarPlayBridge.install(() => container.read(playbackServiceProvider.future));
  }
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const ResonanceApp(),
    ),
  );
}
