import 'package:flutter/material.dart';

/// アプリ全体で使用するカラー定数。
abstract final class AppColors {
  // ── ベースカラー ──────────────────────────────────────────────────────────
  static const Color navy = Color(0xFF0B0F2E);
  static const Color navyMid = Color(0xFF111850);
  static const Color navyDeep = Color(0xFF171D5C);
  static const Color navyLight = Color(0xFF1a2060);

  // ── アクセントカラー ──────────────────────────────────────────────────────
  static const Color gold = Color(0xFFB38246);
  static const Color goldLight = Color(0xFFD4A870);
  static const Color blue = Color(0xFF5B7DE8);
  static const Color blueLight = Color(0xFF93ABE8);

  // ── セマンティックカラー ──────────────────────────────────────────────────
  static const Color red = Color(0xFFFF6B6B);
  static const Color green = Color(0xFF4CAF50);

  // ── テキストカラー ────────────────────────────────────────────────────────
  static const Color muted = Color(0xFF8C90A1);
  static const Color mutedDark = Color(0xFF5A5F72);

  // ── カード・サーフェス ────────────────────────────────────────────────────
  static const Color cardBg = Color(0x1AFFFFFF);
  static const Color cardBorder = Color(0x33FFFFFF);
}
