import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/entities/tag.dart';

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
            ),
        ],
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
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
          child: Text(
            label,
            style: TextStyle(
              fontSize: AppFontSizes.sm,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? AppColors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
