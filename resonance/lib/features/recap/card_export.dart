import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Сохраняет картинку из `RepaintBoundary` с ключом [key] в PNG через
/// системный диалог. Общий путь для карточки итогов и карточки цитаты.
///
/// Возвращает `true`, если файл сохранён, `false` — если человек отменил
/// диалог. Ошибки отрисовки пробрасываются вызывающему.
Future<bool> saveCardImage(
  GlobalKey key, {
  required String fileName,
  required String dialogTitle,
  double pixelRatio = 3,
}) async {
  final boundary = key.currentContext?.findRenderObject();
  if (boundary is! RenderRepaintBoundary) throw StateError('card');
  final image = await boundary.toImage(pixelRatio: pixelRatio);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  if (data == null) throw StateError('png');
  final saved = await FilePicker.saveFile(
    dialogTitle: dialogTitle,
    fileName: fileName,
    bytes: data.buffer.asUint8List(),
    mimeType: 'image/png',
    type: FileType.custom,
    allowedExtensions: const ['png'],
  );
  return saved != null;
}

String cardDateStamp([DateTime? value]) {
  final stamp = value ?? DateTime.now();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${stamp.year}-${two(stamp.month)}-${two(stamp.day)}';
}
