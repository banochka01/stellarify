import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/app/providers.dart';
import 'package:resonance/core/security/flutter_secure_token_repository.dart';
import 'package:resonance/features/platform/feature_api.dart';
import 'package:resonance/features/platform/feature_flags.dart';
import 'package:resonance/features/platform/feature_views.dart';
import 'package:resonance/shared/theme/resonance_theme.dart';

enum UpdateChannel {
  stable('Стабильный', 'Проверенные релизы'),
  beta('Бета', 'Новые функции раньше, возможны шероховатости');

  const UpdateChannel(this.label, this.description);

  final String label;
  final String description;
}

final class UpdateChannelPreferences {
  const UpdateChannelPreferences(this._store);

  static const _key = 'resonance.update.channel';

  final SecureKeyValueStore _store;

  Future<UpdateChannel> read() async {
    final value = await _store.read(_key);
    return value == UpdateChannel.beta.name
        ? UpdateChannel.beta
        : UpdateChannel.stable;
  }

  Future<void> write(UpdateChannel channel) => _store.write(_key, channel.name);
}

final updateChannelPreferencesProvider = Provider<UpdateChannelPreferences>(
  (ref) => UpdateChannelPreferences(ref.watch(secureKeyValueStoreProvider)),
);

final updateChannelProvider =
    AsyncNotifierProvider<UpdateChannelController, UpdateChannel>(
      UpdateChannelController.new,
    );

UpdateChannel _parseChannel(Object? value) =>
    value == 'beta' ? UpdateChannel.beta : UpdateChannel.stable;

/// Local preference, synced with the account (`GET/PUT /api/v1/channel`)
/// when signed in. The channel also drives `/api/v1/features`.
final class UpdateChannelController extends AsyncNotifier<UpdateChannel> {
  static const path = '/api/v1/channel';

  @override
  Future<UpdateChannel> build() async {
    var channel = await ref.read(updateChannelPreferencesProvider).read();
    try {
      final json = await ref
          .read(featureTransportProvider)
          .request('GET', path);
      if (json['channel'] != null) channel = _parseChannel(json['channel']);
    } on Object {
      // Anonymous or offline: keep the local choice.
    }
    _publishHint(channel);
    return channel;
  }

  Future<void> select(UpdateChannel channel) async {
    state = AsyncData(channel);
    await ref.read(updateChannelPreferencesProvider).write(channel);
    try {
      await ref
          .read(featureTransportProvider)
          .request('PUT', path, body: {'channel': channel.name});
    } on Object {
      // The local choice still applies to anonymous flag requests.
    }
    _publishHint(channel);
    ref.invalidate(featureFlagsProvider);
  }

  void _publishHint(UpdateChannel channel) {
    Future.microtask(
      () => ref.read(featureChannelHintProvider.notifier).state = channel.name,
    );
  }
}

// ---- /api/v1/changelog ----

final class ChangelogEntry {
  const ChangelogEntry({
    required this.version,
    required this.title,
    this.date,
    this.channel = UpdateChannel.stable,
    this.items = const [],
  });

  factory ChangelogEntry.fromJson(Map<String, dynamic> json) => ChangelogEntry(
    version: jsonString(json['version']),
    title: jsonString(json['title']),
    date: jsonDate(json['date']),
    channel: _parseChannel(json['channel']),
    items: (json['highlights'] as List? ?? json['items'] as List? ?? const [])
        .map((item) => item.toString())
        .toList(),
  );

  final String version;
  final String title;
  final DateTime? date;
  final UpdateChannel channel;
  final List<String> items;
}

final class ChangelogApi {
  const ChangelogApi(this._transport);

  static const path = '/api/v1/changelog';

  final FeatureTransport _transport;

  Future<List<ChangelogEntry>> fetch(UpdateChannel channel) async => jsonList(
    (await _transport.request(
      'GET',
      path,
      query: {'channel': channel.name, 'limit': '20'},
    ))['entries'],
  ).map(ChangelogEntry.fromJson).toList();
}

final changelogApiProvider = Provider<ChangelogApi>(
  (ref) => ChangelogApi(ref.watch(featureTransportProvider)),
);

final changelogProvider = FutureProvider.autoDispose<List<ChangelogEntry>>((
  ref,
) async {
  final channel = await ref.watch(updateChannelProvider.future);
  return ref.watch(changelogApiProvider).fetch(channel);
});

class ChangelogScreen extends ConsumerWidget {
  const ChangelogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(featureEnabledProvider(FeatureFlag.changelog))) {
      return const FeaturePage(
        eyebrow: 'ЧТО НОВОГО',
        title: 'Обновления Resonance',
        children: [FeatureUnavailableView()],
      );
    }
    final entries = ref.watch(changelogProvider);
    return FeaturePage(
      eyebrow: 'ЧТО НОВОГО',
      title: 'Обновления Resonance',
      children: [
        const UpdateChannelSelector(),
        const SizedBox(height: 8),
        ...entries.when(
          loading: () => const [LinearProgressIndicator(minHeight: 2)],
          error: (error, _) => [
            FeatureUnavailableView(
              error: error,
              onRetry: () => ref.invalidate(changelogProvider),
            ),
          ],
          data: (items) => items.isEmpty
              ? const [FeatureEmpty(text: 'Список изменений пока пуст')]
              : [for (final entry in items) _EntryCard(entry: entry)],
        ),
      ],
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry});

  final ChangelogEntry entry;

  @override
  Widget build(BuildContext context) => FeatureCard(
    highlight: entry.channel == UpdateChannel.beta,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              entry.version,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: ResonanceColors.primary,
              ),
            ),
            const SizedBox(width: 10),
            if (entry.channel == UpdateChannel.beta)
              const Chip(label: Text('бета')),
            const Spacer(),
            Text(
              formatShortDate(entry.date),
              style: const TextStyle(color: ResonanceColors.muted),
            ),
          ],
        ),
        if (entry.title.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            entry.title,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
        const SizedBox(height: 8),
        for (final item in entry.items)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text('•  $item', style: const TextStyle(height: 1.4)),
          ),
      ],
    ),
  );
}

/// Stable/beta channel picker, also embedded into Settings.
class UpdateChannelSelector extends ConsumerWidget {
  const UpdateChannelSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final channel = ref.watch(updateChannelProvider).valueOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Канал обновлений'),
        const SizedBox(height: 8),
        SegmentedButton<UpdateChannel>(
          key: const ValueKey('update-channel'),
          segments: [
            for (final item in UpdateChannel.values)
              ButtonSegment(value: item, label: Text(item.label)),
          ],
          selected: {channel ?? UpdateChannel.stable},
          onSelectionChanged: channel == null
              ? null
              : (selection) => unawaited(
                  ref
                      .read(updateChannelProvider.notifier)
                      .select(selection.first),
                ),
        ),
        const SizedBox(height: 6),
        Text(
          (channel ?? UpdateChannel.stable).description,
          style: const TextStyle(color: ResonanceColors.muted, fontSize: 12),
        ),
      ],
    );
  }
}
