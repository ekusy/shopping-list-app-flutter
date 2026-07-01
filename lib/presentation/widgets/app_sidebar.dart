import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../providers/auth_providers.dart';
import '../providers/group_providers.dart';
import 'tag_manager.dart';

/// サイドバー（エンドドロワー）のナビゲーションエントリ。
///
/// 宣言的に列挙して `map` で描画することで、今後の遷移先追加（履歴 等）を
/// 1 エントリの追記で済ませられるようにする。
class _NavEntry {
  const _NavEntry({
    required this.labelKey,
    required this.icon,
    required this.onTap,
  });

  final String labelKey;
  final IconData icon;
  final void Function(BuildContext context) onTap;
}

/// ドロワーからモーダル（`showModalBottomSheet` 系）を開くための安全な導線。
///
/// ドロワーを `pop` した後の `context` は Overlay / Navigator 祖先が無効化しうるため、
/// 先に **root navigator の context**（`main.dart` の `ProviderScope` / `Localizations` /
/// `Overlay` をすべて祖先に持つ）を確保してから、ドロワーを閉じてモーダルを開く。
/// route 遷移（`context.push`）はこのヘルパー不要（閉じた後の遷移で問題ない）。
void _openFromDrawer(
  BuildContext context,
  void Function(BuildContext root) open,
) {
  final root = Navigator.of(context, rootNavigator: true).context;
  Navigator.of(context).pop();
  open(root);
}

/// 言語切替・グループ/タグ操作・各画面遷移・ログアウトを収容するサイドバー。
class AppSidebar extends ConsumerWidget {
  const AppSidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final group = ref.watch(activeGroupProvider);
    final lang = context.locale.languageCode;

    // ナビゲーション項目（グループ未所属時はグループ依存の項目を出さない）。
    final navEntries = <_NavEntry>[
      if (group != null)
        _NavEntry(
          labelKey: 'group.settings.title',
          icon: Icons.settings_outlined,
          onTap: (ctx) {
            Navigator.of(ctx).pop();
            ctx.push('/group/settings');
          },
        ),
      if (group != null)
        _NavEntry(
          labelKey: 'tag.manage',
          icon: Icons.sell_outlined,
          onTap: (ctx) => _openFromDrawer(ctx, showTagManager),
        ),
      if (group != null)
        _NavEntry(
          labelKey: 'favorites.title',
          icon: Icons.bookmark_outline,
          onTap: (ctx) {
            Navigator.of(ctx).pop();
            ctx.push('/favorites');
          },
        ),
      if (group != null)
        _NavEntry(
          labelKey: 'history.title',
          icon: Icons.history,
          onTap: (ctx) {
            Navigator.of(ctx).pop();
            ctx.push('/history');
          },
        ),
      _NavEntry(
        labelKey: 'sidebar.profile',
        icon: Icons.person_outline,
        onTap: (ctx) {
          Navigator.of(ctx).pop();
          ctx.push('/profile');
        },
      ),
    ];

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
              for (final entry in navEntries)
                ListTile(
                  key: Key('sidebar_nav_${entry.labelKey}'),
                  leading: Icon(entry.icon),
                  title: Text(entry.labelKey.tr()),
                  onTap: () => entry.onTap(context),
                ),
              const Divider(height: AppSpacing.lg),
              ListTile(
                leading: const Icon(Icons.logout, color: AppColors.error),
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
