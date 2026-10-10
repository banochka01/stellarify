import 'package:resonance/domain/entities/unified_track.dart';

final _liveOrClassical = RegExp(
  r'(\blive\b|\bunplugged\b|\bin concert\b|концерт|живьём|живое выступление|'
  r'symphon|симфони|sonata|соната|concerto|\bnocturne|ноктюрн|\bsuite\b|сюита|'
  r'\bop\.\s?\d|\bopus\b|\bbwv\b|\bk\.\s?\d{2,3}|\bhob\.|\bmovement\b|'
  r'\b(i|ii|iii|iv|v|vi)\.\s|allegro|adagio|andante|largo|presto)',
  caseSensitive: false,
);

/// Похоже на концертную запись или академическую музыку — у таких треков
/// концовка (аплодисменты, затихающая кода) важна и затуханием не режется.
bool looksLiveOrClassical(UnifiedTrack track) =>
    _liveOrClassical.hasMatch(track.title) ||
    _liveOrClassical.hasMatch(track.album ?? '');

/// Соседние треки одного альбома: между ними играем без затухания, чтобы
/// альбомы со сквозными переходами звучали цельно.
bool isAlbumContinuation(UnifiedTrack current, UnifiedTrack next) {
  final album = current.album?.trim().toLowerCase();
  if (album == null || album.isEmpty) return false;
  return album == next.album?.trim().toLowerCase() &&
      current.normalizedArtist == next.normalizedArtist;
}

/// «Умный» режим: `true`, если между [current] и [next] не нужен кроссфейд.
bool smartTransitionSkipsFade(UnifiedTrack? current, UnifiedTrack next) {
  if (current == null) return false;
  return isAlbumContinuation(current, next) ||
      looksLiveOrClassical(current) ||
      looksLiveOrClassical(next);
}
