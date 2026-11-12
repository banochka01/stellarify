import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:resonance/core/diagnostics/client_error_reporter.dart';
import 'package:resonance/core/networking/backend_endpoint.dart';
import 'package:resonance/core/platform/device_form.dart';
import 'package:resonance/core/platform/image_cache_budget.dart';
import 'package:resonance/core/playback/playback_engine.dart';
import 'package:resonance/core/playback/windows_media_controls.dart';
import 'package:resonance/features/auth/account_controller.dart';
import 'package:resonance/features/recap/listening_recorder.dart';
import 'package:resonance_alpha/design/tokens.dart';
import 'package:resonance_alpha/shell/shell.dart';
import 'package:resonance_alpha/state.dart';
import 'package:window_manager/window_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ClientErrorReporter.channel = 'alpha';
  ClientErrorReporter.instance.installGlobalHandlers();
  // iOS: live level for the blob comes from libmpv's astats filter.
  // Windows reads the system session meter instead (see runner).
  MediaKitPlaybackEngine.levelMeter = Platform.isIOS;
  MediaKit.ensureInitialized();
  await Future.wait<Object?>([
    BackendEndpoint.initialize(),
    DeviceForm.initialize(),
    if (Platform.isWindows) WindowsMediaControls.initialize(),
  ]);
  applyImageCacheBudget(
    PaintingBinding.instance.imageCache,
    mobile: Platform.isIOS || Platform.isAndroid,
  );
  if (Platform.isWindows) {
    await windowManager.ensureInitialized();
    await windowManager.waitUntilReadyToShow(
      const WindowOptions(
        size: Size(1360, 860),
        minimumSize: Size(420, 640),
        center: true,
        backgroundColor: Pal.stage,
        titleBarStyle: TitleBarStyle.hidden,
        title: 'Resonance α',
      ),
      () async {
        await windowManager.show();
        await windowManager.focus();
      },
    );
  }
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  runApp(const ProviderScope(child: AlphaApp()));
}

class AlphaApp extends ConsumerWidget {
  const AlphaApp({super.key});

  static void _keep(Object? _, Object? _) {}

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Account session (and library sync) and the listening history that
    // daily mixes are built from stay alive for the whole app.
    ref
      ..listen<Object?>(accountControllerProvider, _keep)
      ..listen<Object?>(listeningRecorderProvider, _keep)
      ..listen<Object?>(qualitySyncProvider, _keep);
    return MaterialApp(
      title: 'Resonance α',
      debugShowCheckedModeBanner: false,
      theme: alphaTheme(),
      home: const AlphaShell(),
    );
  }
}
