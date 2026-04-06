import 'package:flutter/material.dart';

/// 削除確認ダイアログを表示する。削除を確定した場合 `true`、キャンセルの場合 `false` を返す。
Future<bool> showConfirmDeleteDialog(
  BuildContext context,
  String message,
) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('削除確認'),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: const Text('削除'),
        ),
      ],
    ),
  );
  return result ?? false;
}
