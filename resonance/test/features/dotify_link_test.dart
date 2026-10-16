import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/features/library/playlist_import_service.dart';

void main() {
  test('decodes the provider URL wrapped in a Dotify share page', () {
    const target =
        'https://music.yandex.ru/playlists/lk.5e6c5a06-205e-4504-ad23-accef83c8a50?utm_medium=copy_link';
    final html =
        '<a href="dotify://playlist/library/${base64.encode(utf8.encode(target))}">';
    expect(decodeDotifyDeepLink(html).toString(), target);
    expect(isDotifyHost('share.dotify.fun'), isTrue);
    expect(decodeDotifyDeepLink('<html></html>'), isNull);
  });
}
