import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/database/app_database.dart';
import 'package:resonance/domain/entities/unified_track.dart';
import 'package:resonance/features/library/library_controller.dart';
import 'package:resonance/features/music_graph/music_graph.dart';
import 'package:resonance/features/platform/feature_api.dart';
import 'package:resonance/features/platform/feature_flags.dart';
import 'package:resonance/features/platform/feature_views.dart';
import 'package:resonance/shared/theme/resonance_theme.dart';

enum CleanupKind { duplicate, replacement }

/// `LibraryItem` from docs/API-5.0.md §6.
final class CleanupItem {
  const CleanupItem({
    required this.trackId,
    required this.title,
    required this.artist,
    this.providers = const [],
    this.locations = 0,
  });

  factory CleanupItem.fromJson(Map<String, dynamic> json) => CleanupItem(
    trackId: jsonString(json['trackId']),
    title: jsonString(json['title']),
    artist: jsonString(json['artist']),
    providers: (json['providers'] as List? ?? const [])
        .map((item) => item.toString())
        .toList(),
    locations: (json['locations'] as List? ?? const []).length,
  );

  final String trackId;
  final String title;
  final String artist;
  final List<String> providers;
  final int locations;

  String get label => '$title — $artist';
}

/// One suggestion: duplicates collapsing into [keep], or [remove] replaced
/// by [replacement].
final class CleanupSuggestion {
  const CleanupSuggestion({
    required this.id,
    required this.kind,
    required this.keep,
    required this.remove,
    this.replacement,
    this.reason,
    this.reasonCode,
    this.local = false,
  });

  factory CleanupSuggestion.duplicateFromJson(Map<String, dynamic> json) {
    final keep = CleanupItem.fromJson(jsonMap(json['keep']));
    return CleanupSuggestion(
      id: 'dup:${keep.trackId}',
      kind: CleanupKind.duplicate,
      keep: keep,
      remove: jsonList(json['duplicates']).map(CleanupItem.fromJson).toList(),
      reason: jsonBool(json['crossProvider']) ? 'из разных сервисов' : null,
    );
  }

  factory CleanupSuggestion.replacementFromJson(Map<String, dynamic> json) {
    final item = CleanupItem.fromJson(jsonMap(json['item']));
    return CleanupSuggestion(
      id: 'rep:${item.trackId}',
      kind: CleanupKind.replacement,
      keep: item,
      remove: [item],
      replacement: jsonTrack(json['suggestion']),
      reasonCode: jsonOptString(json['reason']),
      reason: switch (json['reason']) {
        'no_sources' => 'нет источников',
        'provider_disabled' => 'сервис отключён',
        'reported_unavailable' => 'не воспроизводится',
        _ => null,
      },
    );
  }

  final String id;
  final CleanupKind kind;
  final CleanupItem keep;
  final List<CleanupItem> remove;
  final UnifiedTrack? replacement;
  final String? reason;

  /// Raw server reason (`no_sources`, `provider_disabled`, ...).
  final String? reasonCode;

  /// The user turned the provider off on purpose: never bulk-select it.
  bool get bulkSelectable => applicable && reasonCode != 'provider_disabled';

  /// Computed on-device by Music Graph rather than by the server.
  final bool local;

  bool get applicable =>
      kind == CleanupKind.duplicate ? remove.isNotEmpty : replacement != null;
}

final class CleanupPlan {
  const CleanupPlan({
    required this.suggestions,
    required this.fromServer,
    this.truncated = false,
  });

  final List<CleanupSuggestion> suggestions;
  final bool fromServer;
  final bool truncated;
}

/// Wire contract for `POST /api/v1/library/cleanup`. The server never
/// modifies the library: the client applies the chosen items locally and
/// syncs them through the regular library operations.
final class LibraryCleanupApi {
  const LibraryCleanupApi(this._transport);

  static const path = '/api/v1/library/cleanup';

  final FeatureTransport _transport;

  Future<CleanupPlan> scan({
    List<String>? enabledProviders,
    List<String> unavailableTrackIds = const [],
  }) async {
    final json = await _transport.request(
      'POST',
      path,
      body: {
        'enabledProviders': ?enabledProviders,
        if (unavailableTrackIds.isNotEmpty)
          'unavailableTrackIds': unavailableTrackIds.take(500).toList(),
      },
      providerTokens: true,
    );
    final suggestions = <CleanupSuggestion>[];
    void parse(
      Object? raw,
      CleanupSuggestion Function(Map<String, dynamic>) factory,
    ) {
      for (final item in jsonList(raw)) {
        try {
          suggestions.add(factory(item));
        } on Object {
          // Malformed suggestions are skipped.
        }
      }
    }

    parse(json['duplicates'], CleanupSuggestion.duplicateFromJson);
    parse(json['replacements'], CleanupSuggestion.replacementFromJson);
    return CleanupPlan(
      suggestions: suggestions,
      fromServer: true,
      truncated: jsonBool(json['truncated']),
    );
  }
}

final libraryCleanupApiProvider = Provider<LibraryCleanupApi>(
  (ref) => LibraryCleanupApi(ref.watch(featureTransportProvider)),
);

List<CleanupSuggestion> localDuplicateSuggestions(
  Iterable<UnifiedTrack> tracks,
) {
  final graph = const MusicGraphBuilder().build(tracks);
  final byId = {for (final track in tracks) track.id: track};
  CleanupItem item(UnifiedTrack track) => CleanupItem(
    trackId: track.id,
    title: track.title,
    artist: track.artist,
    providers: track.sources.map((source) => source.provider.name).toList(),
  );
  return [
    for (final node in graph.nodes)
      if (node.memberIds.length > 1)
        CleanupSuggestion(
          id: node.track.id,
          kind: CleanupKind.duplicate,
          keep: item(node.track),
          remove: [
            for (final id in node.memberIds)
              if (id != node.track.id && byId[id] != null) item(byId[id]!),
          ],
          reason: 'найдено на устройстве',
          local: true,
        ),
  ];
}

final cleanupPlanProvider = FutureProvider.autoDispose<CleanupPlan>((
  ref,
) async {
  final library = await ref.watch(libraryControllerProvider.future);
  if (ref.watch(featureEnabledProvider(FeatureFlag.libraryCleanup))) {
    try {
      return await ref
          .watch(libraryCleanupApiProvider)
          .scan(
            enabledProviders: await ref.watch(
              enabledProviderNamesProvider.future,
            ),
            unavailableTrackIds: unavailableTrackIds({
              ...library.favorites,
              ...library.graphTracks,
            }),
          );
    } on Object {
      // Fall back to on-device duplicates.
    }
  }
  return CleanupPlan(
    suggestions: localDuplicateSuggestions(library.graphTracks),
    fromServer: false,
  );
});

class LibraryCleanupScreen extends ConsumerStatefulWidget {
  const LibraryCleanupScreen({super.key});

  @override
  ConsumerState<LibraryCleanupScreen> createState() =>
      _LibraryCleanupScreenState();
}

class _LibraryCleanupScreenState extends ConsumerState<LibraryCleanupScreen> {
  Set<String>? _selected;
  bool _applying = false;

  Future<void> _apply(CleanupPlan plan, Set<String> selected) async {
    final chosen = plan.suggestions
        .where((item) => item.applicable && selected.contains(item.id))
        .toList();
    if (chosen.isEmpty) return;
    final controller = ref.read(libraryControllerProvider.notifier);
    final affected = {
      for (final item in chosen)
        if (item.kind == CleanupKind.replacement)
          item.keep.trackId
        else
          ...item.remove.map((duplicate) => duplicate.trackId),
    };
    final counts = await controller.countOccurrences(affected);
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Применить чистку?'),
        content: Text(
          'Будет заменено ${counts.tracks} треков в ${counts.places} местах (избранное и плейлисты). Сразу после применения действие можно отменить.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            key: const ValueKey('cleanup-confirm'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Применить'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _applying = true);
    try {
      final before = await controller.snapshot();
      final local = chosen.where((item) => item.local).map((item) => item.id);
      if (local.isNotEmpty) {
        await controller.reconcileMusicGraph(onlyCanonicalIds: local.toSet());
      }
      final library = await ref.read(libraryControllerProvider.future);
      final known = {
        for (final track in [
          ...library.graphTracks,
          ...library.favorites,
          ...library.tracks,
        ])
          track.id: track,
      };
      final replacements = <String, UnifiedTrack>{};
      final duplicateIds = <String>{};
      for (final item in chosen.where((item) => !item.local)) {
        if (item.kind == CleanupKind.replacement) {
          replacements[item.keep.trackId] = item.replacement!;
        } else if (known[item.keep.trackId] case final keep?) {
          for (final duplicate in item.remove) {
            replacements[duplicate.trackId] = keep;
            duplicateIds.add(duplicate.trackId);
          }
        }
      }
      await controller.replaceTracks(replacements, duplicateIds: duplicateIds);
      if (!mounted) return;
      setState(() => _selected = null);
      ref.invalidate(cleanupPlanProvider);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 10),
          content: Text('Применено: ${chosen.length}'),
          action: SnackBarAction(
            label: 'Отменить',
            onPressed: () => unawaited(_undo(before)),
          ),
        ),
      );
    } on Object catch (error) {
      if (mounted) {
        showFeatureSnack(
          context,
          'Не удалось применить: ${featureErrorText(error)}',
        );
      }
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  Future<void> _undo(LocalLibrarySnapshot before) async {
    try {
      await ref.read(libraryControllerProvider.notifier).restoreLibrary(before);
      ref.invalidate(cleanupPlanProvider);
      if (mounted) showFeatureSnack(context, 'Медиатека восстановлена');
    } on Object {
      if (mounted) showFeatureSnack(context, 'Не удалось отменить чистку');
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = ref.watch(cleanupPlanProvider);
    return FeaturePage(
      eyebrow: 'УМНАЯ ЧИСТКА',
      title: 'Порядок в медиатеке',
      subtitle:
          'Дубли одной записи из разных сервисов и замены недоступных треков. Отметьте, что применить — остальное останется как есть.',
      children: plan.when(
        loading: () => const [LinearProgressIndicator(minHeight: 2)],
        error: (error, _) => [FeatureUnavailableView(error: error)],
        data: (value) {
          final applicable = value.suggestions
              .where((item) => item.applicable)
              .map((item) => item.id)
              .toSet();
          final bulk = value.suggestions
              .where((item) => item.bulkSelectable)
              .map((item) => item.id)
              .toSet();
          // Nothing is preselected: the user chooses explicitly.
          final selected = _selected ??= <String>{};
          if (value.suggestions.isEmpty) {
            return const [
              FeatureEmpty(
                icon: Icons.check_circle_outline_rounded,
                text: 'Дублей и замен не найдено — медиатека в порядке.',
              ),
            ];
          }
          final duplicates = value.suggestions
              .where((item) => item.kind == CleanupKind.duplicate)
              .toList();
          final replacements = value.suggestions
              .where((item) => item.kind == CleanupKind.replacement)
              .toList();
          final all = bulk.isNotEmpty && selected.containsAll(bulk);
          return [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${value.fromServer ? '' : 'Найдено на устройстве · '}выбрано ${selected.length} из ${applicable.length}',
                    style: const TextStyle(color: ResonanceColors.muted),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(
                    () => _selected = all ? <String>{} : {...selected, ...bulk},
                  ),
                  child: Text(all ? 'Снять все' : 'Выбрать все'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  key: const ValueKey('cleanup-apply'),
                  onPressed: _applying || selected.isEmpty
                      ? null
                      : () => unawaited(_apply(value, selected)),
                  child: const Text('Применить'),
                ),
              ],
            ),
            if (value.truncated)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'Показана часть замен — после применения запустите чистку ещё раз.',
                  style: TextStyle(color: ResonanceColors.muted, fontSize: 12),
                ),
              ),
            if (duplicates.isNotEmpty) ...[
              FeatureSectionTitle('Дубли · ${duplicates.length}'),
              for (final item in duplicates) _tile(item, selected),
            ],
            if (replacements.isNotEmpty) ...[
              FeatureSectionTitle('Замены · ${replacements.length}'),
              for (final item in replacements) _tile(item, selected),
            ],
          ];
        },
      ),
    );
  }

  Widget _tile(CleanupSuggestion item, Set<String> selected) {
    final checked = selected.contains(item.id);
    final details = item.kind == CleanupKind.duplicate
        ? 'Убрать копий: ${item.remove.length}'
        : item.replacement == null
        ? 'Замена не найдена'
        : 'Заменить на: ${item.replacement!.title} — ${item.replacement!.artist}';
    return FeatureCard(
      highlight: checked,
      child: CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        value: checked,
        onChanged: item.applicable
            ? (value) => setState(
                () => value == true
                    ? selected.add(item.id)
                    : selected.remove(item.id),
              )
            : null,
        title: Text(
          item.keep.label,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          [details, ?item.reason].join(' · '),
          style: const TextStyle(color: ResonanceColors.muted),
        ),
      ),
    );
  }
}
