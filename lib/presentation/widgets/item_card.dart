import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/item_icons.dart';
import '../../domain/entities/item.dart';
import '../utils/image_helper.dart';
import 'confirm_dialog.dart';

/// 買い物アイテムのカード表示。
///
/// チェックボックス・アイテム名・同期待ちアイコンをヘッダ行に、
/// 担当者バッジとアクションボタン（買うよ / 購入済 / 編集 / 削除）をフッタ行に並べる。
class ItemCard extends StatelessWidget {
  const ItemCard({
    super.key,
    required this.item,
    required this.onSetVolunteer,
    required this.onSetPurchased,
    required this.onDelete,
    this.onEdit,
    this.currentUid,
    this.memberNames = const {},
    this.selectionMode = false,
    this.isSelected = false,
    this.onSelect,
  });

  final Item item;

  /// 「買います」宣言者を設定する（null で取り消し）。
  final void Function(String? uid) onSetVolunteer;

  /// 購入済み / 未購入を切り替える。
  final void Function(bool purchased) onSetPurchased;
  final VoidCallback onDelete;
  final VoidCallback? onEdit;
  final String? currentUid;
  final Map<String, String> memberNames;
  final bool selectionMode;
  final bool isSelected;
  final VoidCallback? onSelect;

  @override
  Widget build(BuildContext context) {
    final icons = getItemIcons(context.locale.languageCode);
    final isBought = item.isPurchased;
    // 旧 `buyerId === 'me'` データは現ユーザーの宣言として読み出す。
    final declaredBy =
        item.buyingBy ??
        (item.buyerId == 'me' ? (currentUid ?? 'me') : item.buyerId);
    final isMine = declaredBy != null && declaredBy == currentUid;
    final isOthers = declaredBy != null && !isMine;
    final declarerName = declaredBy == null
        ? ''
        : (memberNames[declaredBy] ??
              (declaredBy.length <= 6
                  ? declaredBy
                  : declaredBy.substring(0, 6)));
    final truncatedName = declarerName.length > 8
        ? '${declarerName.substring(0, 8)}…'
        : declarerName;

    final Color bg = selectionMode && isSelected
        ? AppColors.primaryLight
        : isBought
        ? AppColors.boughtBg
        : (declaredBy != null ? AppColors.primaryLight : AppColors.surface);
    final Color border =
        (selectionMode && isSelected) || (declaredBy != null && !isBought)
        ? AppColors.primary
        : AppColors.surfaceBorder;

    final preview = imageProviderFromUrl(item.imageUrl);

    return Opacity(
      opacity: isBought ? 0.6 : 1,
      child: Container(
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
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
                Expanded(
                  child: Text(
                    item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: AppFontSizes.lg,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      decoration: isBought ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
                if (item.pendingWrite)
                  Padding(
                    padding: const EdgeInsets.only(left: AppSpacing.xs),
                    child: Text(
                      icons.pendingSync,
                      style: const TextStyle(fontSize: AppFontSizes.sm),
                    ),
                  ),
              ],
            ),
            if (preview != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                  child: Image(
                    image: preview,
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return SizedBox(
                        height: 150,
                        child: Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                : null,
                            color: AppColors.primary,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            if (item.note.isNotEmpty)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: AppSpacing.xs),
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: const Color(0x08000000),
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                ),
                child: Text(
                  item.note,
                  style: const TextStyle(
                    fontSize: AppFontSizes.sm,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            if (!selectionMode)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Row(
                  children: [
                    Expanded(
                      child: isMine
                          ? _badge(
                              '${icons.volunteerBadge} ${'item.volunteer_badge'.tr()}',
                              AppColors.buyerBadgeBg,
                              AppColors.buyerBadgeText,
                            )
                          : isOthers
                          ? _badge(
                              '${icons.othersBadge} $truncatedName',
                              AppColors.categoryBadgeBg,
                              AppColors.primary,
                            )
                          : const SizedBox.shrink(),
                    ),
                    if (!isBought)
                      _iconButton(
                        isMine
                            ? icons.cancelVolunteer
                            : isOthers
                            ? icons.takeOver
                            : icons.volunteer,
                        active: isMine,
                        semanticLabel: isMine
                            ? 'item.cancel_volunteer'.tr()
                            : isOthers
                            ? 'item.someone_volunteering'.tr()
                            : 'item.volunteer'.tr(),
                        onTap: () => _handleVolunteer(
                          context,
                          isMine: isMine,
                          isOthers: isOthers,
                          declarerName: declarerName,
                        ),
                      ),
                    _iconButton(
                      isBought ? icons.returnToBuy : icons.bought,
                      semanticLabel: isBought
                          ? 'item.return'.tr()
                          : 'item.bought'.tr(),
                      onTap: () => onSetPurchased(!isBought),
                    ),
                    if (onEdit != null)
                      _iconButton(
                        '✏️',
                        materialIcon: Icons.edit,
                        background: AppColors.categoryBadgeBg,
                        foreground: AppColors.primary,
                        semanticLabel: 'item.edit_button'.tr(),
                        onTap: onEdit!,
                      ),
                    _iconButton(
                      icons.delete,
                      materialIcon: Icons.delete,
                      background: AppColors.deleteBg,
                      foreground: AppColors.deleteText,
                      semanticLabel: 'common.delete'.tr(),
                      onTap: onDelete,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _handleVolunteer(
    BuildContext context, {
    required bool isMine,
    required bool isOthers,
    required String declarerName,
  }) {
    if (currentUid == null) return;
    if (isMine) {
      onSetVolunteer(null);
      return;
    }
    if (isOthers) {
      showConfirmDialog(
        context,
        title: 'item.volunteer_conflict_title'.tr(),
        message: 'item.volunteer_conflict_message'.tr(
          namedArgs: {'name': declarerName},
        ),
      ).then((confirmed) {
        if (confirmed) onSetVolunteer(currentUid);
      });
      return;
    }
    onSetVolunteer(currentUid);
  }

  Widget _badge(String text, Color bg, Color fg) => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadii.full),
      ),
      child: Text(
        text,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: AppFontSizes.xs,
          color: fg,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );

  /// アクションボタン（買うよ / 購入済 / 編集 / 削除）。
  ///
  /// [materialIcon] を渡すと絵文字 [label] の代わりに Material アイコンを描画する。
  /// 視認性が要求される編集・削除では [materialIcon] と [background] / [foreground] で
  /// 高コントラストの配色（編集=プライマリ、削除=削除色）を与える。
  Widget _iconButton(
    String label, {
    required VoidCallback onTap,
    required String semanticLabel,
    bool active = false,
    IconData? materialIcon,
    Color? background,
    Color? foreground,
  }) {
    final Color fg = active
        ? AppColors.white
        : (foreground ?? AppColors.textPrimary);
    final Color bg = active
        ? AppColors.infoAccent
        : (background ?? AppColors.overlay);
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.xs),
      child: Semantics(
        button: true,
        label: semanticLabel,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.md),
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            child: materialIcon != null
                ? Icon(materialIcon, size: AppFontSizes.xxl, color: fg)
                : Text(
                    label,
                    style: TextStyle(fontSize: AppFontSizes.lg, color: fg),
                  ),
          ),
        ),
      ),
    );
  }
}
