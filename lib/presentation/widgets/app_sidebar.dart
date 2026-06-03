import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../providers/auth_providers.dart';
import '../providers/group_providers.dart';

/// 言語切替・プロフィール遷移・ログアウトを収容するサイドバー（エンドドロワー）。
class AppSidebar extends ConsumerWidget {
  const AppSidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final group = ref.watch(activeGroupProvider);
    final lang = context.locale.languageCode;

    return Drawer(
      backgroundColor: AppColors.white,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'sidebar.language'.tr().toUpperCase(),
                style: const TextStyle(
                  fontSize: AppFontSizes.xs,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  _langButton(context, 'ja', 'JA', lang == 'ja'),
                  const SizedBox(width: AppSpacing.sm),
                  _langButton(context, 'en', 'EN', lang == 'en'),
                ],
              ),
              const Divider(height: AppSpacing.lg),
              if (group != null)
                ListTile(
                  title: Text('group.settings.title'.tr()),
                  onTap: () {
                    Navigator.of(context).pop();
                    context.push('/group/settings');
                  },
                ),
              ListTile(
                title: Text('sidebar.profile'.tr()),
                onTap: () {
                  Navigator.of(context).pop();
                  context.push('/profile');
                },
              ),
              ListTile(
                title: Text(
                  'sidebar.logout'.tr(),
                  style: const TextStyle(color: AppColors.error),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  ref.read(authControllerProvider).logout();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _langButton(
    BuildContext context,
    String code,
    String label,
    bool active,
  ) {
    return OutlinedButton(
      onPressed: active
          ? null
          : () {
              Navigator.of(context).pop();
              context.setLocale(Locale(code));
            },
      style: OutlinedButton.styleFrom(
        backgroundColor: active ? AppColors.primary : Colors.transparent,
        foregroundColor: active ? AppColors.white : AppColors.primary,
        side: const BorderSide(color: AppColors.primary),
      ),
      child: Text(label),
    );
  }
}
