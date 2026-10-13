import 'package:flutter/material.dart';

/// Text prompt whose controller lives in the dialog's own State.
Future<String?> showTextPrompt(
  BuildContext context, {
  required String title,
  required String action,
  String? label,
  String initial = '',
}) => showDialog<String>(
  context: context,
  builder: (_) => _TextPromptDialog(
    title: title,
    action: action,
    label: label,
    initial: initial,
  ),
);

class _TextPromptDialog extends StatefulWidget {
  const _TextPromptDialog({
    required this.title,
    required this.action,
    required this.initial,
    this.label,
  });

  final String title;
  final String action;
  final String? label;
  final String initial;

  @override
  State<_TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<_TextPromptDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.pop(context, _controller.text.trim());

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      controller: _controller,
      autofocus: true,
      onSubmitted: (_) => _submit(),
      decoration: InputDecoration(labelText: widget.label),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Отмена'),
      ),
      FilledButton(onPressed: _submit, child: Text(widget.action)),
    ],
  );
}

Future<bool> showConfirm(
  BuildContext context, {
  required String title,
  required String action,
  String? message,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: message == null ? null : Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(action),
          ),
        ],
      ),
    ) ??
    false;
