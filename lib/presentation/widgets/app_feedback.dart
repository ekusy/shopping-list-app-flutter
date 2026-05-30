import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// トーストの種別。
enum ToastType { success, error, info }

/// 画面下部のフィードバック表示ユーティリティ（旧 Toast / SnackBar 相当）。
///
/// Flutter の [ScaffoldMessenger] を用いてイディオマティックに実装する。
class AppFeedback {
  AppFeedback._();

  /// 完了通知（3 秒で自動クローズ）。
  static void showToast(
    BuildContext context,
    String message, {
    ToastType type = ToastType.info,
  }) {
    final accent = switch (type) {
      ToastType.success => AppColors.successAccent,
      ToastType.error => AppColors.errorAccent,
      ToastType.info => AppColors.infoAccent,
    };
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.surface,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          side: BorderSide(color: accent, width: 4),
        ),
        content: Text(
          message,
          style: TextStyle(
            color: switch (type) {
              ToastType.success => AppColors.success,
              ToastType.error => AppColors.error,
              ToastType.info => AppColors.info,
            },
            fontSize: AppFontSizes.md,
          ),
        ),
      ),
    );
  }

  /// 進行中バナー（呼び出し元が [hide] するまで表示し続ける）。
  static void showLoading(BuildContext context, String message) {
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xEB1E1E1E),
        duration: const Duration(days: 1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
        content: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.white,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: AppColors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 現在表示中のバナー / トーストを閉じる。
  static void hide(BuildContext context) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
  }
}
