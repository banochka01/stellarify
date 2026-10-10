/// Русское склонение по числу: `ruPlural(21, 'трек', 'трека', 'треков')`.
String ruPlural(int count, String one, String few, String many) {
  final mod100 = count.abs() % 100;
  final mod10 = mod100 % 10;
  if (mod100 >= 11 && mod100 <= 14) return many;
  if (mod10 == 1) return one;
  if (mod10 >= 2 && mod10 <= 4) return few;
  return many;
}

/// «1 трек», «3 трека», «12 треков».
String tracksLabel(int count) =>
    '$count ${ruPlural(count, 'трек', 'трека', 'треков')}';
