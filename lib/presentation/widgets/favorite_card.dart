import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/entities/favorite_item.dart';
import '../providers/group_providers.dart';
import '../utils/image_helper.dart';

/// よく買う物テンプレートの一覧カード。
///
/// 選択モード時はチェックボックスを表示する。画像がある場合は左端にサムネイルを表示する。
class FavoriteCard extends ConsumerWidget {
  const FavoriteCard({
    super.key,
    required this.favorite,
    required this.onEdit,
    required this.onDelete,
    this.selectionMode = false,
    this.isSelected = false,
    this.onSelect,
  });

  final FavoriteItem favorite;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool selectionMode;
  final bool isSelected;
  final VoidCallback? onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tags = ref.watch(tagsProvider).value ?? const [];
    final tag = tags.where((t) => t.id == favorite.tagId).firstOrNull;

    final preview = imageProviderFromUrl(favorite.imageUrl);

    final Color bg = selectionMode && isSelected
        ? AppColors.primaryLight
        : AppColors.surface;
    final Color border = selectionMode && isSelected
        ? AppColors.primary
        : AppColors.surfaceBorder;

    return Container(
      key: ValueKey(favorite.id),
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(
          color: border,
          width: selectionMode && isSelected ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 選択チェックボックス
          IconButton(
            key: Key('favorite_select_${favorite.id}'),
            visualDensity: VisualDensity.compact,
            onPressed: onSelect,
            icon: Text(
              selectionMode && isSelected ? '☑' : '☐',
              style: TextStyle(
                fontSize: AppFontSizes.xl,
                color: selectionMode && isSelected
                    ? AppColors.primary
                    : AppColors.textSecondary,
              ),
            ),
          ),
          // 画像サムネイル（あれば）
          if (preview != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.sm),
              child: Image(
                image: preview,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          // 本文
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  favorite.name,
                  style: const TextStyle(
                    fontSize: AppFontSizes.md,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (tag != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.categoryBadgeBg,
                      borderRadius: BorderRadius.circular(AppRadii.sm),
                    ),
                    child: Text(
                      tag.name,
                      style: const TextStyle(
                        fontSize: AppFontSizes.xs,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
                if (favorite.note.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    favorite.note,
                    style: const TextStyle(
                      fontSize: AppFontSizes.sm,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          // 編集・削除ボタン
          if (!selectionMode) ...[
            IconButton(
              key: Key('favorite_edit_${favorite.id}'),
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.edit, size: 20, color: AppColors.primary),
              tooltip: 'item.edit_button'.tr(),
              onPressed: onEdit,
            ),
            IconButton(
              key: Key('favorite_delete_${favorite.id}'),
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.delete, size: 20, color: AppColors.error),
              tooltip: 'common.delete'.tr(),
              onPressed: onDelete,
            ),
          ],
        ],
      ),
    );
  }
}
