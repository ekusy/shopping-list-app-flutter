import 'dart:math';

/// 8 文字のランダム英数字招待コードを生成する。
///
/// 元実装（`Math.random().toString(36).slice(2, 10).toUpperCase()`）と同様に
/// `0-9A-Z`（base36 を大文字化）の文字集合から 8 文字を生成する。
///
/// @param random テスト用に乱数生成器を差し替え可能（省略時は既定の [Random]）
/// @returns 8 文字の招待コード
String generateInviteCode([Random? random]) {
  const chars = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  final rng = random ?? Random();
  return List.generate(8, (_) => chars[rng.nextInt(chars.length)]).join();
}
