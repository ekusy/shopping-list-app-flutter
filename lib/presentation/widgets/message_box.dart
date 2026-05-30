import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// 成功 / エラーメッセージを表示するボックス（旧 successMessage / errorMessage）。
class MessageBox extends StatelessWidget {
  const MessageBox(this.message, {super.key, this.success = false});

  final String message;
  final bool success;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: success ? const Color(0xFFE8F5E9) : AppColors.errorBg,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(
          color: success ? const Color(0xFFC8E6C9) : AppColors.errorBorder,
        ),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: success ? AppColors.success : AppColors.error,
          fontSize: AppFontSizes.sm,
        ),
      ),
    );
  }
}
