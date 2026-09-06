import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:resonance/domain/entities/unified_track.dart';

class TrackArtwork extends StatelessWidget {
  const TrackArtwork({
    required this.track,
    this.size = 52,
    this.borderRadius = 14,
    this.fallbackAsset,
    super.key,
  });

  final UnifiedTrack track;
  final double size;
  final double borderRadius;
  final String? fallbackAsset;

  @override
  Widget build(BuildContext context) {
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final cacheSize = (size * pixelRatio).round().clamp(96, 1600);
    final fallback = ArtworkFallback(
      track: track,
      dimension: size,
      borderRadius: borderRadius,
      fallbackAsset: fallbackAsset,
    );

    final artworkUrl = track.artworkUrl;
    if (artworkUrl == null) {
      return fallback;
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: CachedNetworkImage(
        imageUrl: highQualityArtworkUrl(artworkUrl, targetSize: cacheSize),
        width: size,
        height: size,
        fit: BoxFit.cover,
        memCacheWidth: cacheSize,
        maxWidthDiskCache: cacheSize,
        fadeInDuration: const Duration(milliseconds: 180),
        errorWidget: (_, _, _) => Image.network(
          artworkUrl.toString(),
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => fallback,
        ),
      ),
    );
  }
}

/// Graceful cover fallback: a deterministic gradient with track initials
/// instead of a dull grey placeholder.
class ArtworkFallback extends StatelessWidget {
  const ArtworkFallback({
    required this.track,
    required this.dimension,
    this.borderRadius = 14,
    this.fallbackAsset,
    this.textStyle,
    super.key,
  });

  final UnifiedTrack track;
  final double dimension;
  final double borderRadius;
  final String? fallbackAsset;
  final TextStyle? textStyle;

  static const _gradients = <List<Color>>[
    [Color(0xFFF05A49), Color(0xFF57190F)],
    [Color(0xFF7C66F2), Color(0xFF1C1340)],
    [Color(0xFF27B567), Color(0xFF0A2E1A)],
    [Color(0xFFEF5570), Color(0xFF3D0F1C)],
    [Color(0xFFF2A03D), Color(0xFF4A220C)],
    [Color(0xFF4C8EF9), Color(0xFF12234D)],
    [Color(0xFF5A5F6B), Color(0xFF15161C)],
    [Color(0xFFE0B64A), Color(0xFF3A2A08)],
  ];

  static List<Color> gradientFor(UnifiedTrack track) {
    final key = track.title.hashCode.abs() + track.artist.hashCode.abs();
    return _gradients[key % _gradients.length];
  }

  static String initialsFor(UnifiedTrack track) {
    final source = track.artist.trim().isNotEmpty
        ? track.artist.trim()
        : track.title.trim();
    final words = source
        .split(RegExp(r'[\s,;&]+'))
        .where((word) => word.isNotEmpty)
        .toList();
    if (words.isEmpty) return '♪';
    final first = words.first.codeUnitAt(0);
    final second = words.length > 1 ? words[1].codeUnitAt(0) : null;
    final buffer = StringBuffer(String.fromCharCode(first));
    if (second != null && initialsGlyphs(second)) {
      buffer.write(String.fromCharCode(second));
    }
    return buffer.toString().toUpperCase();
  }

  static bool initialsGlyphs(int unit) =>
      (unit >= 0x41 && unit <= 0x5A) ||
      (unit >= 0x61 && unit <= 0x7A) ||
      (unit >= 0x410 && unit <= 0x45F) ||
      (unit >= 0x400 && unit <= 0x40F);

  @override
  Widget build(BuildContext context) {
    final body = fallbackAsset != null
        ? Image.asset(fallbackAsset!, fit: BoxFit.cover, width: dimension, height: dimension)
        : DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradientFor(track),
              ),
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Text(
                  initialsFor(track),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style:
                      (textStyle ??
                          TextStyle(
                            fontSize: dimension * 0.32,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            color: Colors.white.withValues(alpha: 0.92),
                            height: 1,
                          ))
                          .copyWith(height: 1),
                ),
              ),
            ),
          );
    return SizedBox.square(
      dimension: dimension,
      child: ClipRRect(borderRadius: BorderRadius.circular(borderRadius), child: body),
    );
  }
}

String highQualityArtworkUrl(Uri artworkUrl, {int targetSize = 1000}) {
  var value = artworkUrl.toString();
  if (artworkUrl.host.endsWith('sndcdn.com')) {
    value = value.replaceFirstMapped(
      RegExp(r'-(?:large|t\d+x\d+)\.(jpg|jpeg|png)(?=\?|$)'),
      (match) => '-t500x500.${match.group(1)}',
    );
  } else if (artworkUrl.host.endsWith('yandex.net')) {
    final size = targetSize.clamp(400, 1000);
    value = value
        .replaceAll('%%', '${size}x$size')
        .replaceFirst(RegExp(r'/\d+x\d+(?=/|$)'), '/${size}x$size');
  }
  return value;
}
