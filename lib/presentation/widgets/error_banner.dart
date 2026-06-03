import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// フォーム上部に表示するインラインエラーバナー（旧 `styles.error`）。
class ErrorBanner extends StatelessWidget {
  const ErrorBanner(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.errorBg,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.errorBorder),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: AppColors.error,
          fontSize: AppFontSizes.sm,
        ),
      ),
    );
  }
}
