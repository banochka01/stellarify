import 'package:resonance/core/errors/app_exception.dart';
import 'package:resonance/domain/entities/music_enums.dart';

final class ExternalUrlValidator {
  const ExternalUrlValidator();

  static const _allowedHosts = <MusicProvider, Set<String>>{
    MusicProvider.youtube: {
      'youtube.com',
      'www.youtube.com',
      'music.youtube.com',
      'youtu.be',
      'googlevideo.com',
    },
    MusicProvider.yandex: {
      'music.yandex.ru',
      'music.yandex.com',
      'music.yandex.kz',
    },
    MusicProvider.soundcloud: {
      'soundcloud.com',
      'www.soundcloud.com',
      'api.soundcloud.com',
      'cf-media.sndcdn.com',
      'media.sndcdn.com',
    },
  };

  bool isAllowed(Uri uri, MusicProvider provider) {
    if (!uri.hasScheme ||
        (uri.scheme != 'https' && uri.scheme != 'http') ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      return false;
    }
    final host = uri.host.toLowerCase();
    return _allowedHosts[provider]!.any(
      (allowed) => host == allowed || host.endsWith('.$allowed'),
    );
  }

  void validate(Uri uri, MusicProvider provider) {
    if (!isAllowed(uri, provider)) {
      throw InvalidExternalUrlException(
        'Домен ${uri.host.isEmpty ? 'не указан' : uri.host} '
        'не разрешён для ${provider.name}.',
      );
    }
  }
}
