/// 日付・時刻フォーマットユーティリティ。

/// `YYYY/MM/DD HH:MM` 形式にフォーマットする（例: `2026/04/07 20:00`）。
String formatDateTime(String iso) {
  try {
    final dt = DateTime.parse(iso);
    return '${dt.year}/${_p(dt.month)}/${_p(dt.day)} '
        '${_p(dt.hour)}:${_p(dt.minute)}';
  } catch (_) {
    return iso;
  }
}

/// `YYYY/MM/DD` 形式にフォーマットする。`null` の場合は `'未設定'` を返す。
String formatDate(String? iso) {
  if (iso == null) return '未設定';
  try {
    final dt = DateTime.parse(iso);
    return '${dt.year}/${_p(dt.month)}/${_p(dt.day)}';
  } catch (_) {
    return iso;
  }
}

/// `YYYY年M月D日  HH:MM` 形式にフォーマットする（例: `2026年4月7日  20:00`）。
String formatDateLong(String iso) {
  try {
    final dt = DateTime.parse(iso);
    return '${dt.year}年${dt.month}月${dt.day}日'
        '  ${_p(dt.hour)}:${_p(dt.minute)}';
  } catch (_) {
    return iso;
  }
}

String _p(int n) => n.toString().padLeft(2, '0');
