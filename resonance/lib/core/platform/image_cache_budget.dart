import 'package:flutter/painting.dart';

/// Лимит декодированных изображений в памяти.
///
/// Обложки декодируются в «корзины» (160–1400 px), поэтому даже крупный
/// экран редко держит больше нескольких десятков мегабайт. На телефонах
/// бюджет ниже стандартных 100 МБ Flutter, чтобы фоновая система не
/// выгружала процесс плеера; на десктопе оставляем запас под сетки обложек.
({int bytes, int entries}) imageCacheBudget({required bool mobile}) => mobile
    ? (bytes: 64 << 20, entries: 400)
    : (bytes: 128 << 20, entries: 1000);

void applyImageCacheBudget(ImageCache cache, {required bool mobile}) {
  final budget = imageCacheBudget(mobile: mobile);
  cache
    ..maximumSizeBytes = budget.bytes
    ..maximumSize = budget.entries;
}
