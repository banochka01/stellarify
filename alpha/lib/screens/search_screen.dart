import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/domain/entities/music_enums.dart';
import 'package:resonance_alpha/design/accent.dart';
import 'package:resonance_alpha/design/tokens.dart';
import 'package:resonance_alpha/design/widgets.dart';
import 'package:resonance_alpha/screens/track_row.dart';
import 'package:resonance_alpha/state.dart';

final _queryProvider = StateProvider<String>((ref) => '');
final _recentProvider = StateProvider<List<String>>((ref) => const []);

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final _controller = TextEditingController(
    text: ref.read(_queryProvider),
  );
  final _focus = FocusNode();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _changed(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 420), () => _commit(value));
  }

  void _commit(String value) {
    final query = value.trim();
    ref.read(_queryProvider.notifier).state = query;
    if (query.length < 2) return;
    final recent = ref.read(_recentProvider);
    ref.read(_recentProvider.notifier).state = [
      query,
      ...recent.where((item) => item.toLowerCase() != query.toLowerCase()),
    ].take(8).toList();
  }

  void _use(String query) {
    _controller.text = query;
    _controller.selection = TextSelection.collapsed(offset: query.length);
    _commit(query);
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final pad = wide ? 48.0 : 20.0;
    final query = ref.watch(_queryProvider);
    final accent = ref.watch(currentAccentProvider);
    final fieldSize = wide ? 72.0 : 40.0;

    final field = TextField(
      controller: _controller,
      focusNode: _focus,
      onChanged: _changed,
      onSubmitted: _commit,
      textInputAction: TextInputAction.search,
      cursorColor: accent,
      cursorWidth: 4,
      style: Txt.display(fieldSize),
      decoration: InputDecoration(
        isCollapsed: true,
        border: InputBorder.none,
        hintText: 'Что включить?',
        hintStyle: Txt.display(fieldSize, color: Pal.faint),
      ),
    );

    Widget body;
    if (query.length < 2) {
      final recent = ref.watch(_recentProvider);
      body = SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: pad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              Text(
                recent.isEmpty ? 'ПОПРОБУЙ' : 'НЕДАВНО ИСКАЛ',
                style: Txt.mono(12),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final item
                      in recent.isEmpty
                          ? const [
                              'Земфира',
                              'Кино',
                              'Radiohead',
                              'Molchat Doma',
                              'Скриптонит',
                            ]
                          : recent)
                    Pill(label: item, onTap: () => _use(item)),
                ],
              ),
            ],
          ),
        ),
      );
    } else {
      final result = ref.watch(searchProvider(query));
      body = result.when(
        loading: () => const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(48),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        ),
        error: (error, _) => SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: pad),
            child: Hollow(title: 'Поиск сломался', body: '$error'),
          ),
        ),
        data: (outcome) {
          if (outcome.tracks.isEmpty) {
            return SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: pad),
                child: Hollow(
                  title: 'Ничего не нашлось',
                  body: outcome.failed.isEmpty
                      ? 'Попробуй написать иначе.'
                      : 'Не ответили: ${outcome.failed.map(_name).join(', ')}.',
                ),
              ),
            );
          }
          return SliverPadding(
            padding: EdgeInsets.fromLTRB(pad - 12, 24, pad - 12, 160),
            sliver: SliverList.builder(
              itemCount: outcome.tracks.length,
              itemBuilder: (context, index) => TrackRow(
                track: outcome.tracks[index],
                index: index,
                onTap: () => run(
                  context,
                  () => playList(ref, outcome.tracks, index: index),
                ),
              ),
            ),
          );
        },
      );
    }

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.translucent,
      child: CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(pad, wide ? 48 : 20, pad, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('02 / ПОИСК', style: Txt.mono(12)),
                  SizedBox(height: wide ? 40 : 24),
                  field,
                  const SizedBox(height: 18),
                  AnimatedContainer(
                    duration: Motion.base,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _focus.hasFocus || query.isNotEmpty
                          ? accent
                          : Pal.line,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
          ),
          body,
        ],
      ),
    );
  }

  static String _name(MusicProvider provider) => switch (provider) {
    MusicProvider.yandex => 'Яндекс',
    MusicProvider.soundcloud => 'SoundCloud',
    MusicProvider.spotify => 'Spotify',
    MusicProvider.vk => 'VK',
    _ => provider.name,
  };
}
