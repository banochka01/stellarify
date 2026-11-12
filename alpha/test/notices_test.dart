import 'package:flutter_test/flutter_test.dart';
import 'package:resonance_alpha/shell/notices.dart';
import 'package:resonance_alpha/update.dart';

void main() {
  test('playback failures get a plain reason', () {
    expect(
      PlaybackIssue.from(
        'Не удалось воспроизвести трек. soundcloud: '
        'AudioResolutionException: Сервер каталога SoundCloud недоступен.',
      ).title,
      'Каталог сейчас не отвечает',
    );
    expect(
      PlaybackIssue.from('У трека нет доступных источников.').title,
      'У трека нет рабочего источника',
    );
    expect(
      PlaybackIssue.from('SocketException: Failed host lookup').title,
      'Нет связи',
    );
    expect(PlaybackIssue.from('что-то странное').title, 'Трек не включился');
  });

  test('update manifest is parsed and compared by build', () {
    final base = Uri.parse('https://music.webcordes.ru');
    final release = AlphaRelease.parse({
      'version': '9.9.9',
      'build': alphaBuild + 1,
      'notes': 'n',
      'windows': '/downloads/alpha/windows',
      'ios': '/downloads/alpha/ios',
    }, base)!;
    expect(release.isNewer, isTrue);
    expect(release.download.host, 'music.webcordes.ru');
    expect(AlphaRelease.parse({'version': 1}, base), isNull);
    expect(
      AlphaRelease.parse({
        'version': alphaVersion,
        'build': alphaBuild,
        'windows': '/w',
        'ios': '/i',
      }, base)!.isNewer,
      isFalse,
    );
  });
}
