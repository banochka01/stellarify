import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart' as widgets;
import 'package:resonance_alpha/design/tokens.dart';

/// True while the keyboard belongs to a text field.
bool isTyping() {
  final context = FocusManager.instance.primaryFocus?.context;
  if (context == null) return false;
  if (context.widget is widgets.EditableText) return true;
  return context.findAncestorWidgetOfExactType<widgets.EditableText>() != null;
}

/// Wraps a shortcut so it does nothing while the user types.
VoidCallback unlessTyping(VoidCallback action) => () {
  if (!isTyping()) action();
};

const hotkeys = <(String, String)>[
  ('Пробел', 'Играть / пауза'),
  ('← / →', 'Перемотка на 10 секунд'),
  ('Ctrl + ← / →', 'Предыдущий / следующий трек'),
  ('L', 'Нравится / не нравится'),
  ('Ctrl + F', 'Поиск'),
  ('Ctrl + 1 / 2 / 3', 'Поток, Поиск, Коллекция'),
  ('Ctrl + ,', 'Настройки'),
  ('Esc', 'Закрыть плеер или сцену'),
  ('F', 'Во весь экран на сцене текста'),
  ('? или F1', 'Эта шпаргалка'),
];

Future<void> showHotkeys(BuildContext context) => showDialog<void>(
  context: context,
  useRootNavigator: true,
  builder: (dialog) => Dialog(
    backgroundColor: Pal.raised,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 26, 28, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('КЛАВИШИ', style: Txt.mono(12)),
            const SizedBox(height: 6),
            Text('Управление без мыши', style: Txt.title(24)),
            const SizedBox(height: 18),
            for (final (keys, action) in hotkeys)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  children: [
                    SizedBox(
                      width: 170,
                      child: Text(keys, style: Txt.mono(13, color: Pal.paper)),
                    ),
                    Expanded(
                      child: Text(
                        action,
                        style: Txt.body(15, color: Pal.muted),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(dialog).pop(),
                child: const Text('Понятно'),
              ),
            ),
          ],
        ),
      ),
    ),
  ),
);
