import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// トーストの種別。
enum ToastType { success, error, info }

/// 画面上部のフィードバック表示ユーティリティ（旧 Toast / SnackBar 相当）。
///
/// 画面下部の追加入力バーやキーボードを覆わないよう、[Overlay] を用いて
/// 画面上部にフローティング表示する。
class AppFeedback {
  AppFeedback._();

  static OverlayEntry? _currentEntry;
  static Timer? _dismissTimer;

  static void _removeCurrent() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    _currentEntry?.remove();
    _currentEntry = null;
  }

  static void _showOverlay(
    BuildContext context, {
    required Widget child,
    Duration? duration,
  }) {
    _removeCurrent();
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    final topInset = MediaQuery.paddingOf(context).top;
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => Positioned(
        top: topInset + AppSpacing.sm,
        left: AppSpacing.md,
        right: AppSpacing.md,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppLayout.maxContentWidth,
            ),
            child: Material(color: Colors.transparent, child: child),
          ),
        ),
      ),
    );

    _currentEntry = entry;
    overlay.insert(entry);

    if (duration != null) {
      _dismissTimer = Timer(duration, () {
        if (_currentEntry == entry) {
          _removeCurrent();
        }
      });
    }
  }

  /// 完了通知（3 秒で自動クローズ、タップでも閉じられる）。
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
    final textColor = switch (type) {
      ToastType.success => AppColors.success,
      ToastType.error => AppColors.error,
      ToastType.info => AppColors.info,
    };

    _showOverlay(
      context,
      duration: const Duration(seconds: 3),
      child: GestureDetector(
        onTap: _removeCurrent,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm + 4,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(color: accent, width: 3),
            boxShadow: const [
              BoxShadow(
                color: Color(0x26000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            message,
            style: TextStyle(
              color: textColor,
              fontSize: AppFontSizes.md,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  /// 進行中バナー（[duration] 指定時はその時間後に自動クローズ、未指定時は [hide] まで表示）。
  static void showLoading(
    BuildContext context,
    String message, {
    Duration? duration,
  }) {
    _showOverlay(
      context,
      duration: duration,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + 4,
        ),
        decoration: BoxDecoration(
          color: const Color(0xEB1E1E1E),
          borderRadius: BorderRadius.circular(AppRadii.lg),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
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
    _removeCurrent();
  }
}
