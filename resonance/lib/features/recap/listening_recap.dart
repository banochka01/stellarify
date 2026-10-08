import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/app/providers.dart';
import 'package:resonance/core/database/app_database.dart';
import 'package:resonance/domain/entities/music_enums.dart';
import 'package:resonance/domain/entities/unified_track.dart';
import 'package:resonance/features/artist/artist_screen.dart';

enum RecapPeriod {
  week(7, 'Неделя', 'за неделю'),
  month(30, 'Месяц', 'за месяц');

  const RecapPeriod(this.days, this.label, this.phrase);
  final int days;
  final String label;
  final String phrase;
}

final class RecapTrack {
  const RecapTrack(this.track, this.plays, this.listened);
  final UnifiedTrack track;
  final int plays;
  final Duration listened;
}

final class RecapArtist {
  const RecapArtist(this.name, this.plays, this.listened, this.cover);
  final String name;
  final int plays;
  final Duration listened;
  final UnifiedTrack? cover;
}

/// Итоги периода, посчитанные из локальной истории прослушиваний.
final class ListeningRecap {
  const ListeningRecap({
    required this.period,
    required this.plays,
    required this.listened,
    required this.uniqueTracks,
    required this.uniqueArtists,
    required this.topTracks,
    required this.topArtists,
    required this.activeDays,
    required this.longestStreak,
    required this.topProvider,
    required this.peakHour,
    required this.daily,
  });

  final RecapPeriod period;
  final int plays;
  final Duration listened;
  final int uniqueTracks;
  final int uniqueArtists;
  final List<RecapTrack> topTracks;
  final List<RecapArtist> topArtists;
  final int activeDays;
  final int longestStreak;
  final MusicProvider? topProvider;

  /// Час суток (0–23), когда слушали больше всего, или null без данных.
  final int? peakHour;

  /// Минуты прослушивания по дням периода, от старых к новым.
  final List<int> daily;

  bool get empty => plays == 0;
  int get minutes => listened.inMinutes;

  /// Короткое «звание» периода по характеру прослушиваний.
  String get persona {
    if (empty) return 'Тишина перед первым треком';
    final hour = peakHour ?? 12;
    if (hour >= 0 && hour < 5) return 'Ночной слушатель';
    if (topArtists.isNotEmpty &&
        topArtists.first.plays >= (plays * .4).ceil() &&
        plays >= 5) {
      return 'Верный фанат · ${topArtists.first.name}';
    }
    if (uniqueArtists >= 25) return 'Исследователь звука';
    if (longestStreak >= 5) return 'Музыка каждый день';
    if (hour < 11) return 'Утренний ритм';
    if (hour >= 18) return 'Вечерняя волна';
    return 'Дневной поток';
  }
}

ListeningRecap buildListeningRecap(
  List<ListeningRecord> records,
  RecapPeriod period, {
  DateTime? now,
}) {
  final today = _day(now ?? DateTime.now());
  // Календарная арифметика: через переход на летнее время сутки бывают
  // по 23 и 25 часов, поэтому вычитание Duration сдвигало бы границы.
  final start = DateTime(
    today.year,
    today.month,
    today.day - (period.days - 1),
  );
  final inPeriod = records
      .where((record) => !_day(record.playedAt).isBefore(start))
      .toList(growable: false);

  final tracks = <String, ({UnifiedTrack track, int plays, Duration time})>{};
  final artists =
      <
        String,
        ({String name, int plays, Duration time, UnifiedTrack? cover})
      >{};
  final providers = <MusicProvider, int>{};
  final hours = List<int>.filled(24, 0);
  final daily = List<int>.filled(period.days, 0);
  final days = <DateTime>{};
  var listened = Duration.zero;

  for (final record in inPeriod) {
    final track = record.track;
    listened += record.listened;
    final day = _day(record.playedAt);
    days.add(day);
    final dayIndex = _dayNumber(day) - _dayNumber(start);
    if (dayIndex >= 0 && dayIndex < daily.length) {
      daily[dayIndex] += record.listened.inSeconds;
    }
    hours[record.playedAt.hour] += 1;
    final key = '${track.normalizedArtist}|${track.normalizedTitle}';
    final known = tracks[key];
    tracks[key] = (
      track: known?.track ?? track,
      plays: (known?.plays ?? 0) + 1,
      time: (known?.time ?? Duration.zero) + record.listened,
    );
    for (final name in splitArtists(track.artist).take(3)) {
      final artistKey = name.toLowerCase().replaceAll('ё', 'е');
      final current = artists[artistKey];
      artists[artistKey] = (
        name: current?.name ?? name,
        plays: (current?.plays ?? 0) + 1,
        time: (current?.time ?? Duration.zero) + record.listened,
        cover: current?.cover ?? (track.artworkUrl == null ? null : track),
      );
    }
    final provider = track.preferredProvider;
    if (provider != null) providers[provider] = (providers[provider] ?? 0) + 1;
  }

  final topTracks =
      tracks.values
          .map((item) => RecapTrack(item.track, item.plays, item.time))
          .toList()
        ..sort((a, b) {
          final byPlays = b.plays.compareTo(a.plays);
          return byPlays != 0 ? byPlays : b.listened.compareTo(a.listened);
        });
  final topArtists =
      artists.values
          .map(
            (item) => RecapArtist(item.name, item.plays, item.time, item.cover),
          )
          .toList()
        ..sort((a, b) {
          final byTime = b.listened.compareTo(a.listened);
          return byTime != 0 ? byTime : b.plays.compareTo(a.plays);
        });

  var peak = -1;
  var peakCount = 0;
  for (var hour = 0; hour < 24; hour++) {
    if (hours[hour] > peakCount) {
      peak = hour;
      peakCount = hours[hour];
    }
  }

  MusicProvider? topProvider;
  var providerCount = 0;
  providers.forEach((provider, count) {
    if (count > providerCount) {
      topProvider = provider;
      providerCount = count;
    }
  });

  return ListeningRecap(
    period: period,
    plays: inPeriod.length,
    listened: listened,
    uniqueTracks: tracks.length,
    uniqueArtists: artists.length,
    topTracks: topTracks.take(5).toList(growable: false),
    topArtists: topArtists.take(5).toList(growable: false),
    activeDays: days.length,
    longestStreak: _longestStreak(days),
    topProvider: topProvider,
    peakHour: peak < 0 ? null : peak,
    daily: [for (final seconds in daily) (seconds / 60).round()],
  );
}

DateTime _day(DateTime value) => DateTime(value.year, value.month, value.day);

/// Порядковый номер календарного дня, не зависящий от часового пояса.
int _dayNumber(DateTime day) =>
    DateTime.utc(day.year, day.month, day.day).millisecondsSinceEpoch ~/
    Duration.millisecondsPerDay;

int _longestStreak(Set<DateTime> days) {
  if (days.isEmpty) return 0;
  final sorted = days.toList()..sort();
  var best = 1;
  var current = 1;
  for (var index = 1; index < sorted.length; index++) {
    // Через DST сутки бывают 23/25 часов: сравниваем календарные дни.
    final expected = DateTime(
      sorted[index - 1].year,
      sorted[index - 1].month,
      sorted[index - 1].day + 1,
    );
    if (sorted[index] == expected) {
      current++;
      if (current > best) best = current;
    } else {
      current = 1;
    }
  }
  return best;
}

final listeningRecapProvider = FutureProvider.autoDispose
    .family<ListeningRecap, RecapPeriod>((ref, period) async {
      final database = ref.watch(appDatabaseProvider);
      final since = DateTime.now().subtract(Duration(days: period.days + 1));
      final records = await database.loadListeningHistory(since: since);
      return buildListeningRecap(records, period);
    });
