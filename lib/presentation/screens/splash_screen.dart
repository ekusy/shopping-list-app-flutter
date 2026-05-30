import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// 認証・グループ状態のロード中に表示するスプラッシュ（ローディング）画面。
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );
  }
}
