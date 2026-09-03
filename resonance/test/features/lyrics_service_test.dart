import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/features/lyrics/lyrics_service.dart';

void main() {
  test('decodes synchronized and plain lyric lines', () {
    final document = LyricsDocument.fromJson({
      'id': 7,
      'synced': true,
      'instrumental': false,
      'lines': [
        {'startMs': 1200, 'text': 'First'},
        {'startMs': null, 'text': 'Second'},
        {'startMs': 3000, 'text': ''},
      ],
      'source': {'name': 'LRCLIB', 'url': 'https://lrclib.net/api/get/7'},
    });

    expect(document.id, 7);
    expect(document.synced, true);
    expect(document.lines, hasLength(2));
    expect(document.lines.first.start, const Duration(milliseconds: 1200));
    expect(document.lines.last.start, isNull);
    expect(document.sourceName, 'LRCLIB');
  });
}
