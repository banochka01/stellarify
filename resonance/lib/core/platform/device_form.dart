import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Device form factor detected once at startup (Android TV vs. the rest).
abstract final class DeviceForm {
  static const _channel = MethodChannel('app.resonance/device');

  static bool _isTelevision = false;

  /// True on Android TV / Google TV (UI_MODE_TYPE_TELEVISION or leanback).
  static bool get isTelevision => _isTelevision;

  static bool get isDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  static Future<void> initialize() async {
    if (!Platform.isAndroid) return;
    try {
      _isTelevision =
          await _channel.invokeMethod<bool>('isTelevision') ?? false;
    } on Object {
      _isTelevision = false;
    }
  }

  @visibleForTesting
  static set debugIsTelevision(bool value) => _isTelevision = value;
}
