import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/entities/tag.dart';

/// 複数選択モードのアクションバー（選択数・タグ変更・キャンセル）。
class BulkActionBar extends StatefulWidget {
  const BulkActionBar({
    super.key,
    required this.count,
    required this.tags,
    required this.onChangeTag,
    required this.onCancel,
  });

  final int count;
  final List<Tag> tags;

  /// タグ変更確定時のコールバック（null でタグ解除）。
  final Future<void> Function(String? tagId) onChangeTag;
  final VoidCallback onCancel;

  @override
  State<BulkActionBar> createState() => _BulkActionBarState();
}

class _BulkActionBarState extends State<BulkActionBar> {
  bool _showTagPicker = false;
  bool _applying = false;

  Future<void> _select(String? tagId) async {
    if (_applying) return;
    setState(() => _applying = true);
    try {
      await widget.onChangeTag(tagId);
    } finally {
      if (mounted) {
        setState(() {
          _applying = false;
          _showTagPicker = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'select.count'.tr(namedArgs: {'count': '${widget.count}'}),
                style: const TextStyle(
                  fontSize: AppFontSizes.sm,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              Row(
                children: [
                  FilledButton(
                    onPressed: _applying
                        ? null
                        : () => setState(() => _showTagPicker = !_showTagPicker),
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    child: Text('select.change_tag'.tr()),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  OutlinedButton(
                    onPressed: _applying ? null : widget.onCancel,
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    child: Text('select.cancel'.tr()),
                  ),
                ],
              ),
            ],
          ),
          if (_showTagPicker)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _tagChip('tag.no_tag'.tr(), false, () => _select(null)),
                    for (final tag in widget.tags)
                      _tagChip(tag.name, true, () => _select(tag.id)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _tagChip(String label, bool filled, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.xs),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: BoxDecoration(
            color: filled ? AppColors.primary : AppColors.white,
            borderRadius: BorderRadius.circular(AppRadii.full),
            border: Border.all(
              color: filled ? AppColors.primary : AppColors.inputBorder,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: AppFontSizes.sm,
              fontWeight: filled ? FontWeight.w700 : FontWeight.w500,
              color: filled ? AppColors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
