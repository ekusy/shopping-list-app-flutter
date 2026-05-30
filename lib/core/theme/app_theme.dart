import 'package:flutter/material.dart';

/// アプリ全体のデザイントークン（色）。
///
/// 元の `src/theme.ts` の `colors` を Flutter の [Color] に移植したもの。
/// 値をハードコードせず、ここを参照すること。
class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF646CFF);
  static const Color primaryHover = Color(0xFF7C83FD);
  static const Color primaryLight = Color(0xFFEEEEFF);
  static const Color textPrimary = Color(0xFF2C3E50);
  static const Color textSecondary = Color(0xFF546E7A);
  static const Color background = Color(0xFFF0F4F8);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceBorder = Color(0xFFE2E4EF);
  static const Color inputBg = Color(0xFFFFFFFF);
  static const Color inputBorder = Color(0xFFD1D5E0);
  static const Color overlay = Color(0x0D000000); // rgba(0,0,0,0.05)
  static const Color error = Color(0xFFC62828);
  static const Color errorBg = Color(0xFFFFEBEE);
  static const Color errorBorder = Color(0xFFFFCDD2);
  static const Color success = Color(0xFF2E7D32);
  static const Color info = Color(0xFF1565C0);
  static const Color successAccent = Color(0xFF4CAF50);
  static const Color errorAccent = Color(0xFFF44336);
  static const Color infoAccent = Color(0xFF2196F3);
  static const Color buyerBadgeBg = Color(0xFFE3F2FD);
  static const Color buyerBadgeText = Color(0xFF1976D2);
  static const Color deleteBg = Color(0x1AF44336); // rgba(244,67,54,0.1)
  static const Color deleteText = Color(0xFFC62828);
  static const Color boughtBg = Color(0x80E6E6E6); // rgba(230,230,230,0.5)
  static const Color categoryBadgeBg = Color(0x1A646CFF); // rgba(100,108,255,0.1)
  static const Color white = Color(0xFFFFFFFF);
  static const Color disabled = Color(0xFFCCCCCC);
}

/// 余白トークン（px）。元 `spacing`。
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

/// フォントサイズトークン。元 `fontSizes`。
class AppFontSizes {
  AppFontSizes._();

  static const double xs = 12;
  static const double sm = 13;
  static const double md = 14;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double title = 28;
}

/// 角丸トークン。元 `radii`。
class AppRadii {
  AppRadii._();

  static const double sm = 4;
  static const double md = 8;
  static const double lg = 16;
  static const double xl = 20;
  static const double full = 9999;
}

/// レイアウト共通定数。
class AppLayout {
  AppLayout._();

  /// メインコンテンツの最大幅（Web のワイド表示で中央寄せ）。元 Dashboard の `maxWidth: 800`。
  static const double maxContentWidth = 800;
}

/// アプリ共通の [ThemeData] を構築する。
ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorSchemeSeed: AppColors.primary,
    scaffoldBackgroundColor: AppColors.background,
    fontFamily: null,
  );
  return base.copyWith(
    colorScheme: base.colorScheme.copyWith(
      primary: AppColors.primary,
      surface: AppColors.surface,
      error: AppColors.error,
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: AppColors.inputBg,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppRadii.md)),
        borderSide: BorderSide(color: AppColors.inputBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppRadii.md)),
        borderSide: BorderSide(color: AppColors.inputBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppRadii.md)),
        borderSide: BorderSide(color: AppColors.primary, width: 2),
      ),
    ),
  );
}
