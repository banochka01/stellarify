import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:resonance/domain/entities/music_enums.dart';
import 'package:resonance/shared/theme/resonance_theme.dart';

/// Настоящий логотип сервиса в полном цвете.
class ProviderLogo extends StatelessWidget {
  const ProviderLogo({required this.provider, this.size = 20, super.key});

  final MusicProvider provider;
  final double size;

  static String assetFor(MusicProvider provider) => switch (provider) {
    MusicProvider.youtube => 'assets/logos/youtube.svg',
    MusicProvider.yandex => 'assets/logos/yandex_music.svg',
    MusicProvider.soundcloud => 'assets/logos/soundcloud.svg',
    MusicProvider.spotify => 'assets/logos/spotify.svg',
    MusicProvider.vk => 'assets/logos/vk.svg',
  };

  static String labelFor(MusicProvider provider) => switch (provider) {
    MusicProvider.youtube => 'YouTube',
    MusicProvider.yandex => 'Яндекс Музыка',
    MusicProvider.soundcloud => 'SoundCloud',
    MusicProvider.spotify => 'Spotify',
    MusicProvider.vk => 'VK Музыка',
  };

  @override
  Widget build(BuildContext context) => Semantics(
    label: labelFor(provider),
    child: SvgPicture.asset(
      assetFor(provider),
      width: size,
      height: size,
      fit: BoxFit.contain,
    ),
  );
}

/// Логотип сервиса на спокойной нейтральной подложке.
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
    final dimension = compact ? 23.0 : 30.0;
    return Tooltip(
      message: ProviderLogo.labelFor(provider),
      child: Container(
        width: dimension,
        height: dimension,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: ResonanceColors.surfaceRaised.withValues(alpha: .9),
          shape: BoxShape.circle,
        ),
        child: ProviderLogo(provider: provider, size: compact ? 15 : 19),
      ),
    );
  }
}
