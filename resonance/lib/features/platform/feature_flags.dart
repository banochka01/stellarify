import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/features/platform/feature_api.dart';

/// Resonance 5 sections. Server-backed ones are shown only when their key is
/// returned by `GET /api/v1/features` (see docs/API-5.0.md §7); when the
/// endpoint is missing they stay hidden.
enum FeatureFlag {
  social('social.profiles'),
  socialFeed('social.feed'),
  socialCompatibility('social.compatibility'),
  socialBlend('social.blend'),
  socialRooms('social.rooms'),
  graphExplore('graph.explore'),
  graphPathRadio('graph.pathRadio'),
  artistPage('artists.page2'),
  artistFollow('artists.followReleases'),
  artistConcerts('artists.concerts'),
  artistSetlists('artists.setlists'),
  collaborativePlaylists('playlists.collab'),
  libraryCleanup('library.cleanup'),

  /// Client-only: the local map canvas works without the server.
  graphMap('client.graphMap'),

  /// Client-only: manual crossfade deck for room hosts/DJs.
  djRooms('client.djRooms'),

  /// Public endpoint; the screen hides its content on errors.
  changelog('client.changelog');

  const FeatureFlag(this.key);

  final String key;
}

final class FeatureFlags {
  const FeatureFlags(this._enabled);

  factory FeatureFlags.fromJson(Map<String, dynamic> json) {
    final raw = json['flags'];
    final enabled = <String>{};
    if (raw is List) {
      enabled.addAll(raw.map((item) => item.toString()));
    } else if (raw is Map) {
      for (final entry in raw.entries) {
        if (entry.value == true) enabled.add(entry.key.toString());
      }
    }
    return FeatureFlags(enabled);
  }

  static const none = FeatureFlags({});

  static const _clientDefaults = {
    FeatureFlag.graphMap,
    FeatureFlag.djRooms,
    FeatureFlag.changelog,
  };

  final Set<String> _enabled;

  bool isEnabled(FeatureFlag flag) =>
      _clientDefaults.contains(flag) || _enabled.contains(flag.key);
}

final class FeatureFlagsApi {
  const FeatureFlagsApi(this._transport);

  static const path = '/api/v1/features';

  final FeatureTransport _transport;

  Future<FeatureFlags> fetch({String? channel}) async => FeatureFlags.fromJson(
    await _transport.request(
      'GET',
      path,
      query: channel == null ? null : {'channel': channel},
    ),
  );
}

final featureFlagsApiProvider = Provider<FeatureFlagsApi>(
  (ref) => FeatureFlagsApi(ref.watch(featureTransportProvider)),
);

/// Optional channel hint for anonymous requests (set by the changelog layer).
final featureChannelHintProvider = StateProvider<String?>((ref) => null);

final featureFlagsProvider = FutureProvider<FeatureFlags>((ref) async {
  final channel = ref.watch(featureChannelHintProvider);
  try {
    return await ref.watch(featureFlagsApiProvider).fetch(channel: channel);
  } on Object {
    return FeatureFlags.none;
  }
});

final featureEnabledProvider = Provider.family<bool, FeatureFlag>((ref, flag) {
  final flags = ref.watch(featureFlagsProvider).valueOrNull;
  return (flags ?? FeatureFlags.none).isEnabled(flag);
});

/// Renders [child] only when [flag] is enabled.
class FeatureGate extends ConsumerWidget {
  const FeatureGate({
    required this.flag,
    required this.child,
    this.fallback = const SizedBox.shrink(),
    super.key,
  });

  final FeatureFlag flag;
  final Widget child;
  final Widget fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(featureEnabledProvider(flag)) ? child : fallback;
}
