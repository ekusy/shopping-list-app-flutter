import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../providers/group_providers.dart';
import '../../providers/item_providers.dart';
import '../../providers/suggestion_providers.dart';
import '../group_switcher.dart';

/// ダッシュボードのヘッダー。
///
/// グループ名（タップでグループ切替）・未購入件数・AI 提案ボタン（未読バッジ）・
/// メニューボタンを表示する。タグ管理 / よく買う物への導線はサイドバー
/// （`AppSidebar`）へ集約したため、ここではグループ名の表示幅を最大化している。
///
/// 必要な provider だけを `select` で自己購読する `ConsumerWidget` とし、
/// グループ名・未購入件数・未読バッジの変化でヘッダーのみが再ビルドされるようにする
/// （ダッシュボード全体の再ビルドを避ける）。
class DashboardHeader extends ConsumerWidget {
  const DashboardHeader({super.key, required this.onOpenMenu});

  /// メニュー（end drawer）を開くコールバック。
  final VoidCallback onOpenMenu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupName = ref.watch(activeGroupProvider.select((g) => g?.name));
    final pendingCount = ref.watch(pendingItemCountProvider);
    final hasUnread = ref.watch(hasUnreadSuggestionProvider).value ?? false;
    final title = groupName ?? 'app.title'.tr();

    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppLayout.maxContentWidth,
          ),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => showGroupSwitcher(context),
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: AppFontSizes.xl,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const Text(
                        ' ▼',
                        style: TextStyle(color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
              ),
              if (pendingCount > 0)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.xs),
                  child: Text(
                    'status.pending_count'.tr(
                      namedArgs: {'count': '$pendingCount'},
                    ),
                    style: const TextStyle(
                      fontSize: AppFontSizes.xs,
                      color: AppColors.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              // AI 提案ボタン（未読バッジ付き）
              Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    icon: const Icon(Icons.auto_awesome),
                    tooltip: 'suggestions.title'.tr(),
                    onPressed: () => context.push('/suggestions'),
                  ),
                  if (hasUnread)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        key: const Key('dashboard_unread_badge'),
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.menu),
                tooltip: 'sidebar.open'.tr(),
                onPressed: onOpenMenu,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
