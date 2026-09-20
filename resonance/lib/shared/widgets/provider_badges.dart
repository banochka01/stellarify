import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:resonance/domain/entities/music_enums.dart';
import 'package:resonance/shared/theme/resonance_theme.dart';

class ProviderBadge extends StatelessWidget {
  const ProviderBadge({
    required this.provider,
    this.compact = false,
    super.key,
  });

  final MusicProvider provider;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = switch (provider) {
      MusicProvider.youtube => ResonanceColors.youtube,
      MusicProvider.yandex => ResonanceColors.yandex,
      MusicProvider.soundcloud => ResonanceColors.soundcloud,
      MusicProvider.spotify => ResonanceColors.spotify,
      MusicProvider.vk => ResonanceColors.vk,
    };
    return Container(
      width: compact ? 23 : 30,
      height: compact ? 23 : 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: SvgPicture.asset(
        switch (provider) {
          MusicProvider.youtube => 'assets/icons/provider_youtube.svg',
          MusicProvider.yandex => 'assets/icons/provider_yandex.svg',
          MusicProvider.soundcloud => 'assets/icons/provider_soundcloud.svg',
          MusicProvider.spotify => 'assets/icons/provider_spotify.svg',
          MusicProvider.vk => 'assets/icons/provider_vk.svg',
        },
        width: compact ? 13 : 17,
        height: compact ? 13 : 17,
      ),
    );
  }
}
