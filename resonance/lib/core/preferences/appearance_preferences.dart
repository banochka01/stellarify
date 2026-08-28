import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:resonance/core/security/flutter_secure_token_repository.dart';

enum ResonanceThemePreset { graphite, midnight, ember }

final class AppearanceSettings {
  const AppearanceSettings({
    this.theme = ResonanceThemePreset.graphite,
    this.backgroundPath,
    this.blur = 10,
    this.dim = 0.58,
  });

  final ResonanceThemePreset theme;
  final String? backgroundPath;
  final double blur;
  final double dim;

  AppearanceSettings copyWith({
    ResonanceThemePreset? theme,
    String? backgroundPath,
    bool clearBackground = false,
    double? blur,
    double? dim,
  }) => AppearanceSettings(
    theme: theme ?? this.theme,
    backgroundPath: clearBackground
        ? null
        : (backgroundPath ?? this.backgroundPath),
    blur: blur ?? this.blur,
    dim: dim ?? this.dim,
  );
}

final class AppearancePreferences {
  AppearancePreferences(this._store);

  static const _themeKey = 'resonance.appearance.theme';
  static const _backgroundKey = 'resonance.appearance.background';
  static const _blurKey = 'resonance.appearance.blur';
  static const _dimKey = 'resonance.appearance.dim';
  final SecureKeyValueStore _store;

  Future<AppearanceSettings> read() async {
    final values = await Future.wait([
      _store.read(_themeKey),
      _store.read(_backgroundKey),
      _store.read(_blurKey),
      _store.read(_dimKey),
    ]);
    final storedPath = values[1];
    return AppearanceSettings(
      theme: ResonanceThemePreset.values.firstWhere(
        (preset) => preset.name == values[0],
        orElse: () => ResonanceThemePreset.graphite,
      ),
      backgroundPath: storedPath != null && File(storedPath).existsSync()
          ? storedPath
          : null,
      blur: (double.tryParse(values[2] ?? '') ?? 10).clamp(0, 30),
      dim: (double.tryParse(values[3] ?? '') ?? .58).clamp(0, .9),
    );
  }

  Future<void> write(AppearanceSettings value) async {
    await Future.wait([
      _store.write(_themeKey, value.theme.name),
      _store.write(_blurKey, value.blur.toString()),
      _store.write(_dimKey, value.dim.toString()),
      if (value.backgroundPath == null)
        _store.delete(_backgroundKey)
      else
        _store.write(_backgroundKey, value.backgroundPath!),
    ]);
  }

  Future<String?> pickAndStoreBackground() async {
    final result = await FilePicker.pickFile(type: FileType.image);
    final sourcePath = result?.path;
    if (sourcePath == null) return null;
    final source = File(sourcePath);
    if (!await source.exists()) return null;
    final directory = await getApplicationSupportDirectory();
    final extension = path.extension(source.path).toLowerCase();
    final destination = File(
      path.join(
        directory.path,
        'custom-background${extension.isEmpty ? '.jpg' : extension}',
      ),
    );
    if (path.equals(source.absolute.path, destination.absolute.path)) {
      return destination.path;
    }
    await source.copy(destination.path);
    return destination.path;
  }
}

final class AppearanceController extends StateNotifier<AppearanceSettings> {
  AppearanceController(this._preferences) : super(const AppearanceSettings()) {
    _load();
  }

  final AppearancePreferences _preferences;

  Future<void> _load() async {
    try {
      state = await _preferences.read();
    } on Object {
      // Defaults keep the UI usable when platform storage is unavailable.
    }
  }

  Future<void> setTheme(ResonanceThemePreset theme) =>
      _save(state.copyWith(theme: theme));

  void previewBlur(double blur) => state = state.copyWith(blur: blur);

  void previewDim(double dim) => state = state.copyWith(dim: dim);

  Future<void> persist() => _preferences.write(state);

  Future<bool> chooseBackground() async {
    final selected = await _preferences.pickAndStoreBackground();
    if (selected == null) return false;
    await _save(state.copyWith(backgroundPath: selected));
    return true;
  }

  Future<void> clearBackground() =>
      _save(state.copyWith(clearBackground: true));

  Future<void> _save(AppearanceSettings next) async {
    state = next;
    await _preferences.write(next);
  }
}
