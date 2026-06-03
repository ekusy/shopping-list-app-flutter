import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/plan_limits.dart';
import '../../core/constants/validation_limits.dart';
import '../../core/errors/app_error.dart';
import '../../core/theme/app_theme.dart';
import '../providers/group_providers.dart';
import 'app_feedback.dart';
import 'confirm_dialog.dart';

/// タグ管理モーダルをボトムシートで表示する（作成・名称変更・削除）。
Future<void> showTagManager(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.lg)),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: const _TagManagerContent(),
    ),
  );
}

class _TagManagerContent extends ConsumerStatefulWidget {
  const _TagManagerContent();

  @override
  ConsumerState<_TagManagerContent> createState() => _TagManagerContentState();
}

class _TagManagerContentState extends ConsumerState<_TagManagerContent> {
  final _newTag = TextEditingController();
  final _editing = TextEditingController();
  String? _editingId;

  @override
  void dispose() {
    _newTag.dispose();
    _editing.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final trimmed = _newTag.text.trim();
    if (trimmed.isEmpty) return;
    try {
      await ref.read(groupControllerProvider.notifier).addTag(trimmed);
      _newTag.clear();
    } catch (e) {
      if (!mounted) return;
      final isLimit =
          e is AppError && e.code == AppErrorCode.dataTagLimitExceeded;
      AppFeedback.showToast(
        context,
        isLimit ? 'tag.error.limit_exceeded'.tr() : 'tag.error.add_failed'.tr(),
        type: ToastType.error,
      );
    }
  }

  Future<void> _commitRename(String tagId) async {
    final trimmed = _editing.text.trim();
    if (trimmed.isNotEmpty) {
      try {
        await ref
            .read(groupControllerProvider.notifier)
            .renameTag(tagId, trimmed);
      } catch (_) {
        if (mounted) {
          AppFeedback.showToast(
            context,
            'tag.error.rename_failed'.tr(),
            type: ToastType.error,
          );
        }
      }
    }
    setState(() => _editingId = null);
  }

  Future<void> _delete(String tagId, String tagName) async {
    final ok = await showConfirmDialog(
      context,
      message: 'tag.confirm_delete'.tr(namedArgs: {'name': tagName}),
    );
    if (!ok) return;
    try {
      await ref.read(groupControllerProvider.notifier).deleteTag(tagId);
    } catch (_) {
      if (mounted) {
        AppFeedback.showToast(
          context,
          'tag.error.delete_failed'.tr(),
          type: ToastType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tags = ref.watch(tagsProvider).value ?? const [];
    final tagLimit = ref.watch(tagLimitProvider);
    final limitReached = ref.watch(tagLimitReachedProvider);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'tag.manage'.tr(),
                style: const TextStyle(
                  fontSize: AppFontSizes.xl,
                  fontWeight: FontWeight.w700,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final tag in tags)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xs,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _editingId == tag.id
                              ? TextField(
                                  controller: _editing,
                                  autofocus: true,
                                  maxLength: ValidationLimits.tagName,
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    counterText: '',
                                  ),
                                  onSubmitted: (_) => _commitRename(tag.id),
                                  onTapOutside: (_) => _commitRename(tag.id),
                                )
                              : GestureDetector(
                                  onLongPress: () => setState(() {
                                    _editingId = tag.id;
                                    _editing.text = tag.name;
                                  }),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: AppSpacing.sm,
                                    ),
                                    child: Text(
                                      tag.name,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                        ),
                        IconButton(
                          icon: const Text(
                            '×',
                            style: TextStyle(
                              color: AppColors.deleteText,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          onPressed: () => _delete(tag.id, tag.name),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Text(
              limitReached
                  ? (tagLimit <= PlanLimits.freeTagLimit
                            ? 'tag.limit_reached_free'
                            : 'tag.limit_reached_paid')
                        .tr()
                  : 'tag.remaining'.tr(
                      namedArgs: {'count': '${tagLimit - tags.length}'},
                    ),
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: AppFontSizes.xs,
                color: limitReached ? AppColors.error : AppColors.textSecondary,
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _newTag,
                  enabled: !limitReached,
                  maxLength: ValidationLimits.tagName,
                  decoration: InputDecoration(
                    hintText: 'tag.name_placeholder'.tr(),
                    counterText: '',
                    isDense: true,
                  ),
                  onSubmitted: (_) => _create(),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              FilledButton(
                onPressed: limitReached ? null : _create,
                child: Text('tag.create'.tr()),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
