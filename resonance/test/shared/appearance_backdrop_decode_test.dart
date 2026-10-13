import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/shared/widgets/appearance_backdrop.dart';

void main() {
  test('custom background decodes to the window size, not the photo', () {
    // 1280×800 при 1.0 → длинная сторона 1280 → корзина 1536.
    expect(AppearanceBackdrop.decodeWidthFor(const Size(1280, 800), 1), 1536);
    // Телефон 390×844 при 3.0 → 2532 → 2560.
    expect(AppearanceBackdrop.decodeWidthFor(const Size(390, 844), 3), 2560);
    // Ресайз окна внутри корзины не меняет ключ кэша.
    expect(
      AppearanceBackdrop.decodeWidthFor(const Size(1300, 800), 1),
      AppearanceBackdrop.decodeWidthFor(const Size(1500, 800), 1),
    );
    // Огромные экраны ограничены 4096 px.
    expect(AppearanceBackdrop.decodeWidthFor(const Size(3840, 2160), 2), 4096);
  });
}
