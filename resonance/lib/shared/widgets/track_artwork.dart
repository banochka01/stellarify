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
        imageUrl: artworkUrl.toString(),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorWidget: (context, url, error) => fallback,
      ),
    );
  }
}
