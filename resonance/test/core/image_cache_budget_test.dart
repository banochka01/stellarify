import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/core/platform/image_cache_budget.dart';

void main() {
  test('phones get a tighter decoded-image budget than desktop', () {
    final mobile = imageCacheBudget(mobile: true);
    final desktop = imageCacheBudget(mobile: false);
    expect(mobile.bytes, 64 << 20);
    expect(mobile.bytes, lessThan(desktop.bytes));
    expect(mobile.entries, lessThan(desktop.entries));
  });

  test('applies the budget to an image cache', () {
    final cache = ImageCache();
    applyImageCacheBudget(cache, mobile: true);
    expect(cache.maximumSizeBytes, 64 << 20);
    expect(cache.maximumSize, 400);
  });
}
