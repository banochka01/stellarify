import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/app/providers.dart';
import 'package:resonance/core/security/flutter_secure_token_repository.dart';
import 'package:resonance/domain/entities/unified_track.dart';
import 'package:resonance/shared/widgets/track_artwork.dart';
import 'package:resonance_alpha/design/tokens.dart';

/// The loudest usable colour of an artwork, tuned to sit on a black stage.
final artworkAccentProvider = FutureProvider.family<Color, String>((
  ref,
  url,
) async {
  final image = await _decode(url);
  if (image == null) return Pal.acid;
  try {
    final data = await image.toByteData();
    if (data == null) return Pal.acid;
    return pickAccent(data.buffer.asUint8List());
  } finally {
    image.dispose();
  }
});

/// Accent of whatever is playing now; lime when nothing is.
final currentAccentProvider = Provider<Color>((ref) {
  final track = ref.watch(currentTrackProvider);
  return accentFor(ref, track);
});

/// Accent of any track's cover.
final trackAccentProvider = Provider.family<Color, UnifiedTrack>(
  (ref, track) => accentFor(ref, track),
);

/// Only the current track: widgets that need it do not rebuild on progress.
final currentTrackProvider = Provider<UnifiedTrack?>((ref) {
  return ref.watch(
    playbackStateProvider.select((value) => value.valueOrNull?.currentTrack),
  );
});

Color accentFor(Ref ref, UnifiedTrack? track) {
  final prefs = ref.watch(accentPrefsProvider);
  if (!prefs.fromCover) return prefs.fixed;
  final url = track?.artworkUrl;
  if (url == null) return prefs.fixed;
  final key = highQualityArtworkUrl(url, targetSize: artworkThumbnailBucket);
  return ref.watch(artworkAccentProvider(key)).valueOrNull ?? prefs.fixed;
}

/// Calm tones for the fixed accent. Nothing here shouts.
const accentSwatches = <(String, Color)>[
  ('Шалфей', Color(0xFFB4C9A4)),
  ('Песок', Color(0xFFD8C29E)),
  ('Пудра', Color(0xFFD9ADA4)),
  ('Лаванда', Color(0xFFB6B0DA)),
  ('Небо', Color(0xFF9FBCD8)),
  ('Кость', Color(0xFFE4DDCD)),
];

final class AccentPrefs {
  const AccentPrefs({this.fromCover = true, this.fixed = Pal.acid});

  /// Take the accent from the playing cover; otherwise always [fixed].
  final bool fromCover;
  final Color fixed;
}

final accentPrefsProvider =
    StateNotifierProvider<AccentPrefsController, AccentPrefs>((ref) {
      return AccentPrefsController(ref.watch(secureKeyValueStoreProvider));
    });

class AccentPrefsController extends StateNotifier<AccentPrefs> {
  AccentPrefsController(this._store) : super(const AccentPrefs()) {
    unawaited(_load());
  }

  static const _coverKey = 'alpha.accent.from_cover';
  static const _fixedKey = 'alpha.accent.fixed';
  final SecureKeyValueStore _store;

  Future<void> _load() async {
    try {
      final cover = await _store.read(_coverKey);
      final fixed = int.tryParse(await _store.read(_fixedKey) ?? '');
      if (!mounted) return;
      state = AccentPrefs(
        fromCover: cover != 'false',
        fixed: fixed == null ? Pal.acid : Color(fixed),
      );
    } on Object {
      // Defaults are fine when storage is unavailable.
    }
  }

  Future<void> setFromCover(bool value) async {
    state = AccentPrefs(fromCover: value, fixed: state.fixed);
    await _store.write(_coverKey, '$value');
  }

  Future<void> setFixed(Color value) async {
    state = AccentPrefs(fromCover: state.fromCover, fixed: value);
    await _store.write(_fixedKey, '${value.toARGB32()}');
  }
}

Future<ui.Image?> _decode(String url) {
  final completer = Completer<ui.Image?>();
  final provider = ResizeImage(
    CachedNetworkImageProvider(url),
    width: 40,
    height: 40,
    policy: ResizeImagePolicy.exact,
  );
  final stream = provider.resolve(ImageConfiguration.empty);
  late final ImageStreamListener listener;
  listener = ImageStreamListener(
    (info, _) {
      if (!completer.isCompleted) completer.complete(info.image.clone());
      info.dispose();
      stream.removeListener(listener);
    },
    onError: (_, _) {
      if (!completer.isCompleted) completer.complete(null);
      stream.removeListener(listener);
    },
  );
  stream.addListener(listener);
  return completer.future.timeout(
    const Duration(seconds: 12),
    onTimeout: () {
      stream.removeListener(listener);
      return null;
    },
  );
}

/// Picks the hue bucket with the most saturated, bright weight and lifts it
/// to a lightness that stays loud on black. Grey covers get lime.
Color pickAccent(List<int> rgba) {
  const buckets = 24;
  final weight = List<double>.filled(buckets, 0);
  final hueX = List<double>.filled(buckets, 0);
  final hueY = List<double>.filled(buckets, 0);
  final sat = List<double>.filled(buckets, 0);
  for (var i = 0; i + 3 < rgba.length; i += 4) {
    if (rgba[i + 3] < 128) continue;
    final hsv = HSVColor.fromColor(
      Color.fromARGB(255, rgba[i], rgba[i + 1], rgba[i + 2]),
    );
    if (hsv.saturation < .22 || hsv.value < .18) continue;
    final w = hsv.saturation * hsv.saturation * (.4 + hsv.value);
    final index = (hsv.hue / 360 * buckets).floor() % buckets;
    weight[index] += w;
    final radians = hsv.hue * math.pi / 180;
    hueX[index] += math.cos(radians) * w;
    hueY[index] += math.sin(radians) * w;
    sat[index] += hsv.saturation * w;
  }
  var best = -1;
  var bestScore = 0.0;
  for (var i = 0; i < buckets; i++) {
    // Neighbouring buckets vote too, so a gradient is not split in two.
    final score =
        weight[i] +
        .5 * weight[(i + 1) % buckets] +
        .5 * weight[(i - 1 + buckets) % buckets];
    if (score > bestScore) {
      bestScore = score;
      best = i;
    }
  }
  final pixels = rgba.length / 4;
  if (best < 0 || bestScore < pixels * .02) return _grey;
  var hue = math.atan2(hueY[best], hueX[best]) * 180 / math.pi;
  if (hue < 0) hue += 360;
  // Softened on purpose: a cover's hue, never its full neon.
  final saturation = (sat[best] / weight[best] * .6).clamp(.28, .52);
  return HSLColor.fromAHSL(1, hue, saturation, .7).toColor();
}

/// Neutral warm accent for black-and-white covers.
const _grey = Color(0xFFD9D3C7);

/// Deep shade of [accent] for text placed on it.
Color inkOn(Color accent) {
  final hsl = HSLColor.fromColor(accent);
  return hsl.withLightness(.14).withSaturation(hsl.saturation * .6).toColor();
}

/// Text colour that reads on top of [accent]: a deep shade of it.
Color onAccent(Color accent) => inkOn(accent);
