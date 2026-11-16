import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/entities/tag.dart';

const _tagColors = [
  Color(0xFF646CFF), // indigo
  Color(0xFF2E9E6B), // green
  Color(0xFFF4A259), // apricot
  Color(0xFF9C6ADE), // purple
  Color(0xFF1D9BF0), // blue
  Color(0xFFE05252), // red
  Color(0xFF78909C), // slate
];

/// タグ ID から決定論的にカラーを返す（チップとセクションヘッダーで共通利用）。
Color tagColor(String? tagId) {
  if (tagId == null || tagId.isEmpty) return const Color(0xFF78909C);
  final hash = tagId.codeUnits.fold<int>(
    0,
    (h, c) => (h * 31 + c) & 0x7fffffff,
  );
  return _tagColors[hash % _tagColors.length];
}

/// タグフィルタバー。横スクロールのタグチップ一覧（複数選択で OR 検索）。
class FilterBar extends StatelessWidget {
  const FilterBar({
    super.key,
    required this.tags,
    required this.selectedTagIds,
    required this.onToggle,
    required this.onClear,
  });

  final List<Tag> tags;
  final List<String> selectedTagIds;
  final void Function(String tagId) onToggle;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final isAll = selectedTagIds.isEmpty;
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        children: [
          _chip('common.all'.tr(), isAll, onClear),
          for (final tag in tags)
            _chip(
              tag.name,
              selectedTagIds.contains(tag.id),
              () => onToggle(tag.id),
              dotColor: tagColor(tag.id),
            ),
        ],
      ),
    );
  }

  Widget _chip(
    String label,
    bool selected,
    VoidCallback onTap, {
    Color? dotColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.xs),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.white,
            borderRadius: BorderRadius.circular(AppRadii.full),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.inputBorder,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (dotColor != null) ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                    border: selected
                        ? Border.all(color: AppColors.white, width: 1.5)
                        : null,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: AppFontSizes.sm,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? AppColors.white : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
