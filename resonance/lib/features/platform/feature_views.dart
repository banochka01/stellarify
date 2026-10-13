import 'package:flutter/material.dart';
import 'package:resonance/features/platform/feature_api.dart';
import 'package:resonance/shared/theme/resonance_theme.dart';
import 'package:resonance/shared/widgets/track_artwork.dart';

/// Shared page chrome for the Resonance 5 sections.
class FeaturePage extends StatelessWidget {
  const FeaturePage({
    required this.eyebrow,
    required this.title,
    required this.children,
    this.subtitle,
    this.actions = const [],
    super.key,
  });

  final String eyebrow;
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 650;
    return ListView(
      padding: EdgeInsets.fromLTRB(
        compact ? 18 : 34,
        compact ? 24 : 32,
        compact ? 18 : 34,
        130,
      ),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                eyebrow,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.8,
                  color: ResonanceColors.primary,
                ),
              ),
            ),
            ...actions,
          ],
        ),
        const SizedBox(height: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: compact ? 32 : 42,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.5,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 10),
          Text(
            subtitle!,
            style: const TextStyle(color: ResonanceColors.muted, height: 1.45),
          ),
        ],
        const SizedBox(height: 24),
        ...children,
      ],
    );
  }
}

class FeatureSectionTitle extends StatelessWidget {
  const FeatureSectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 10),
    child: Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.5,
        color: ResonanceColors.muted,
      ),
    ),
  );
}

class FeatureCard extends StatelessWidget {
  const FeatureCard({required this.child, this.highlight = false, super.key});

  final Widget child;
  final bool highlight;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    // Material (not a decorated box) so nested ListTiles keep ink effects.
    child: Material(
      color: ResonanceColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: highlight
              ? ResonanceColors.primary.withValues(alpha: .4)
              : ResonanceColors.border,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: SizedBox(width: double.infinity, child: child),
      ),
    ),
  );
}

/// Calm placeholder shown when a server section is unavailable.
class FeatureUnavailableView extends StatelessWidget {
  const FeatureUnavailableView({this.error, this.onRetry, super.key});

  final Object? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final failure = error;
    final known = failure is FeatureUnavailableException ? failure : null;
    final auth = known?.authRequired ?? false;
    final title = auth
        ? 'Войдите в аккаунт Resonance'
        : known == null || known.missing
        ? 'Раздел временно недоступен'
        : known.userMessage;
    return FeatureCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            auth
                ? Icons.lock_outline_rounded
                : known?.rateLimited ?? false
                ? Icons.hourglass_top_rounded
                : Icons.cloud_off_rounded,
            color: ResonanceColors.muted,
          ),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text(
            'Остальные функции продолжают работать.',
            style: TextStyle(color: ResonanceColors.muted),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 10),
            TextButton(onPressed: onRetry, child: const Text('Повторить')),
          ],
        ],
      ),
    );
  }
}

class FeatureEmpty extends StatelessWidget {
  const FeatureEmpty({required this.text, this.icon, super.key});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => FeatureCard(
    child: Row(
      children: [
        Icon(icon ?? Icons.inbox_outlined, color: ResonanceColors.muted),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: ResonanceColors.muted),
          ),
        ),
      ],
    ),
  );
}

/// Small square cover for DTOs that are not full tracks.
class FeatureCover extends StatelessWidget {
  const FeatureCover({required this.url, this.size = 52, super.key});

  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: size,
      height: size,
      color: ResonanceColors.surfaceHigh,
      child: const Icon(Icons.album_rounded, color: ResonanceColors.muted),
    );
    final source = url;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: source == null || !source.startsWith('https://')
          ? placeholder
          : Image.network(
              source,
              width: size,
              height: size,
              cacheWidth: artworkCacheBucket(
                size * MediaQuery.devicePixelRatioOf(context),
              ),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => placeholder,
            ),
    );
  }
}

void showFeatureSnack(BuildContext context, String text) {
  ScaffoldMessenger.maybeOf(
    context,
  )?.showSnackBar(SnackBar(content: Text(text)));
}

/// User-facing text for any error thrown by a feature API.
String featureErrorText(Object error) => error is FeatureUnavailableException
    ? error.userMessage
    : 'Что-то пошло не так';
