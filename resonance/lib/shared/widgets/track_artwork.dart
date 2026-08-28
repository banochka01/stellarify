import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:resonance/domain/entities/unified_track.dart';
import 'package:resonance/shared/theme/resonance_theme.dart';

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
    final fallback = SizedBox.square(
      dimension: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: fallbackAsset == null
            ? Container(
                decoration: BoxDecoration(
                  color: ResonanceColors.surfaceHigh,
                  border: Border.all(color: ResonanceColors.border),
                ),
                child: Icon(
                  Icons.graphic_eq_rounded,
                  size: size * 0.42,
                  color: ResonanceColors.text,
                ),
              )
            : Image.asset(fallbackAsset!, fit: BoxFit.cover),
      ),
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
        errorWidget: (context, url, error) => fallback,
      ),
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
