import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:resonance/features/artist/artist_catalog.dart';
import 'package:resonance/shared/theme/resonance_theme.dart';
import 'package:resonance/shared/widgets/ambient_backdrop.dart';
import 'package:resonance/shared/widgets/resonance_motion.dart';

/// Opens the artist page for the main credit of [artist].
void openArtist(BuildContext context, String artist) {
  final name = primaryArtist(artist);
  if (name.isEmpty) return;
  context.push('/artist/${Uri.encodeComponent(name)}');
}

/// Artist credits where every individual artist is a link to their page.
class ArtistLinks extends StatelessWidget {
  const ArtistLinks({
    required this.artist,
    this.style,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
    this.textAlign = TextAlign.start,
    super.key,
  });

  final String artist;
  final TextStyle? style;
  final int maxLines;
  final TextOverflow overflow;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final base = DefaultTextStyle.of(context).style.merge(style);
    final credits = artistCredits(artist);
    if (credits.length <= 1) {
      return _HoverLink(
        onTap: () => openArtist(context, artist),
        builder: (hovered) => Text(
          artist,
          maxLines: maxLines,
          overflow: overflow,
          textAlign: textAlign,
          style: base.copyWith(
            decoration: hovered ? TextDecoration.underline : null,
            decorationColor: base.color,
          ),
        ),
      );
    }
    return Text.rich(
      TextSpan(
        children: [
          for (var i = 0; i < credits.length; i++) ...[
            if (i > 0) const TextSpan(text: ', '),
            TextSpan(
              text: credits[i],
              mouseCursor: SystemMouseCursors.click,
              recognizer: TapGestureRecognizer()
                ..onTap = () => openArtist(context, credits[i]),
            ),
          ],
        ],
      ),
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
      style: base,
    );
  }
}

class _HoverLink extends StatefulWidget {
  const _HoverLink({required this.onTap, required this.builder});

  final VoidCallback onTap;
  final Widget Function(bool hovered) builder;

  @override
  State<_HoverLink> createState() => _HoverLinkState();
}

class _HoverLinkState extends State<_HoverLink> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    onEnter: (_) => setState(() => _hovered = true),
    onExit: (_) => setState(() => _hovered = false),
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: widget.builder(_hovered),
    ),
  );
}

/// Section title used by the shelves on Home and artist pages.
class ShelfHeader extends StatelessWidget {
  const ShelfHeader({required this.title, this.action, super.key});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: ResonanceColors.text,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -.8,
            ),
          ),
        ),
        ?action,
      ],
    ),
  );
}

/// Horizontal row of equally sized cards.
class MediaShelf extends StatelessWidget {
  const MediaShelf({
    required this.itemCount,
    required this.itemBuilder,
    required this.height,
    this.itemWidth = 168,
    this.spacing = 16,
    this.padding = EdgeInsets.zero,
    super.key,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final double height;
  final double itemWidth;
  final double spacing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: padding,
      clipBehavior: Clip.none,
      itemCount: itemCount,
      separatorBuilder: (_, _) => SizedBox(width: spacing),
      itemBuilder: (context, index) => SizedBox(
        width: itemWidth,
        child: ResonanceEntrance(
          delay: Duration(milliseconds: 30 * index.clamp(0, 10)),
          offset: const Offset(.06, 0),
          child: itemBuilder(context, index),
        ),
      ),
    ),
  );
}

/// Square artwork card with title/subtitle, a hover play button and an
/// equalizer when the item is the one currently playing.
class MediaCard extends StatefulWidget {
  const MediaCard({
    required this.title,
    required this.onTap,
    this.subtitle,
    this.subtitleWidget,
    this.artworkUrl,
    this.artwork,
    this.size = 168,
    this.circular = false,
    this.active = false,
    this.playing = false,
    this.loading = false,
    this.accent,
    this.badge,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? subtitleWidget;
  final Uri? artworkUrl;
  final Widget? artwork;
  final double size;
  final bool circular;
  final bool active;
  final bool playing;
  final bool loading;
  final Color? accent;
  final Widget? badge;
  final VoidCallback onTap;

  @override
  State<MediaCard> createState() => _MediaCardState();
}

class _MediaCardState extends State<MediaCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final radius = widget.circular
        ? BorderRadius.circular(widget.size)
        : BorderRadius.circular(14);
    final accent = widget.accent ?? Theme.of(context).colorScheme.primary;
    final duration = ResonanceMotion.durationOf(context, ResonanceMotion.quick);
    final showButton = _hovered || widget.active || widget.loading;
    return Semantics(
      button: true,
      label: widget.subtitle == null
          ? widget.title
          : '${widget.title}, ${widget.subtitle}',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: Column(
            crossAxisAlignment: widget.circular
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              AnimatedScale(
                duration: duration,
                curve: ResonanceMotion.curve,
                scale: _hovered ? 1.03 : 1,
                child: AnimatedContainer(
                  duration: duration,
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    borderRadius: radius,
                    boxShadow: [
                      BoxShadow(
                        color: (widget.active ? accent : Colors.black)
                            .withValues(
                              alpha: _hovered || widget.active ? .42 : .28,
                            ),
                        blurRadius: _hovered ? 28 : 18,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: radius,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        widget.artwork ??
                            ArtworkImage(
                              url: widget.artworkUrl,
                              seed: widget.title,
                              size: widget.size,
                            ),
                        AnimatedOpacity(
                          duration: duration,
                          opacity: _hovered ? 1 : 0,
                          child: const DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Color(0x00000000), Color(0x8C000000)],
                              ),
                            ),
                          ),
                        ),
                        if (widget.badge != null)
                          Positioned(top: 8, left: 8, child: widget.badge!),
                        Positioned(
                          right: widget.circular ? null : 10,
                          bottom: widget.circular ? null : 10,
                          child: Align(
                            child: AnimatedSlide(
                              duration: duration,
                              curve: ResonanceMotion.curve,
                              offset: showButton
                                  ? Offset.zero
                                  : const Offset(0, .35),
                              child: AnimatedOpacity(
                                duration: duration,
                                opacity: showButton ? 1 : 0,
                                child: _CardPlayButton(
                                  accent: accent,
                                  playing: widget.active && widget.playing,
                                  loading: widget.loading,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: widget.circular
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start,
                children: [
                  if (widget.active) ...[
                    EqualizerBars(
                      playing: widget.playing,
                      color: accent,
                      size: 12,
                    ),
                    const SizedBox(width: 7),
                  ],
                  Flexible(
                    child: Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: widget.circular
                          ? TextAlign.center
                          : TextAlign.start,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: widget.active ? accent : ResonanceColors.text,
                      ),
                    ),
                  ),
                ],
              ),
              if (widget.subtitleWidget != null || widget.subtitle != null) ...[
                const SizedBox(height: 3),
                DefaultTextStyle.merge(
                  style: const TextStyle(
                    color: ResonanceColors.muted,
                    fontSize: 12,
                  ),
                  child:
                      widget.subtitleWidget ??
                      Text(
                        widget.subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: widget.circular
                            ? TextAlign.center
                            : TextAlign.start,
                      ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CardPlayButton extends StatelessWidget {
  const _CardPlayButton({
    required this.accent,
    required this.playing,
    required this.loading,
  });

  final Color accent;
  final bool playing;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final foreground = accent.computeLuminance() > .45
        ? const Color(0xFF0B0B0B)
        : Colors.white;
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: accent,
        shape: BoxShape.circle,
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: loading
          ? Padding(
              padding: const EdgeInsets.all(12),
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: foreground,
              ),
            )
          : Icon(
              playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: foreground,
              size: 24,
            ),
    );
  }
}

/// Network artwork with a deterministic gradient fallback.
class ArtworkImage extends StatelessWidget {
  const ArtworkImage({
    required this.url,
    required this.seed,
    this.size = 168,
    this.icon = Icons.music_note_rounded,
    super.key,
  });

  final Uri? url;
  final String seed;
  final double size;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final fallback = GradientArtwork(seed: seed, icon: icon);
    final value = url;
    if (value == null) return fallback;
    final cache = (size * MediaQuery.devicePixelRatioOf(context)).round().clamp(
      96,
      900,
    );
    return CachedNetworkImage(
      imageUrl: value.toString(),
      fit: BoxFit.cover,
      memCacheWidth: cache,
      maxWidthDiskCache: cache,
      fadeInDuration: const Duration(milliseconds: 220),
      placeholder: (_, _) => fallback,
      errorWidget: (_, _, _) => fallback,
    );
  }
}

/// Generated cover: two hues derived from [seed], a soft highlight and an
/// optional icon, used for mixes and items without artwork.
class GradientArtwork extends StatelessWidget {
  const GradientArtwork({
    required this.seed,
    this.icon,
    this.colors,
    this.label,
    super.key,
  });

  final String seed;
  final IconData? icon;
  final List<Color>? colors;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final hash = seed.codeUnits.fold<int>(7, (h, c) => (h * 31 + c) & 0xFFFFFF);
    final hue = (hash % 360).toDouble();
    final palette =
        colors ??
        [
          HSLColor.fromAHSL(1, hue, .62, .46).toColor(),
          HSLColor.fromAHSL(1, (hue + 48) % 360, .58, .2).toColor(),
        ];
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: palette,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(-.6, -.7),
                radius: 1.1,
                colors: [Color(0x40FFFFFF), Color(0x00FFFFFF)],
              ),
            ),
          ),
          if (label != null)
            Padding(
              padding: const EdgeInsets.all(14),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  label!,
                  maxLines: 2,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.8,
                  ),
                ),
              ),
            ),
          if (icon != null)
            Align(
              alignment: label == null ? Alignment.center : Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Icon(
                  icon,
                  size: label == null ? 40 : 26,
                  color: Colors.white.withValues(alpha: .86),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Russian compact count: 151 700 → «151,7 тыс.».
String compactCount(int value) {
  if (value >= 1000000) {
    return '${_oneDecimal(value / 1000000)} млн';
  }
  if (value >= 1000) return '${_oneDecimal(value / 1000)} тыс.';
  return '$value';
}

String _oneDecimal(double value) {
  final rounded = (value * 10).round() / 10;
  return rounded == rounded.truncateToDouble()
      ? rounded.toStringAsFixed(0)
      : rounded.toStringAsFixed(1).replaceAll('.', ',');
}
