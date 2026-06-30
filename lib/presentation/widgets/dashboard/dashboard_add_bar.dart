import 'dart:typed_data';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/item.dart';
import '../../../domain/entities/tag.dart';
import '../../providers/group_providers.dart';
import '../../providers/item_controller.dart';
import '../../providers/selection_controller.dart';
import '../add_item_form.dart';
import '../app_feedback.dart';
import '../bulk_action_bar.dart';
import '../quick_add_input.dart';

/// ダッシュボード下部の追加バー。
///
/// クイック追加入力と詳細追加（モーダル）への導線を 1 行に収める。アイテム書き込みは
/// [ItemController] に委譲し、ここでは UI フィードバック（ローディング / トースト /
/// モーダル開閉）のみを担う。`hasGroup` を自己購読する `ConsumerWidget` とし、画面全体の
/// 再ビルドに巻き込まれないようにしている。
class DashboardAddBar extends ConsumerWidget {
  const DashboardAddBar({super.key});

  Future<void> _quickAdd(
    BuildContext context,
    WidgetRef ref,
    String name,
  ) async {
    AppFeedback.showLoading(context, 'status.adding'.tr());
    try {
      await ref.read(itemControllerProvider).quickAdd(name);
    } catch (_) {
      if (context.mounted) {
        AppFeedback.showToast(
          context,
          'app.error.add'.tr(),
          type: ToastType.error,
        );
      }
    } finally {
      if (context.mounted) AppFeedback.hide(context);
    }
  }

  Future<void> _addItem(
    BuildContext context,
    WidgetRef ref,
    Item draft,
    Uint8List? imageBytes,
  ) async {
    try {
      final outcome = await ref
          .read(itemControllerProvider)
          .addItem(draft, imageBytes);
      if (!context.mounted) return;
      Navigator.of(context).pop(); // フォームのボトムシートを閉じる
      final imageFailed = outcome == AddItemOutcome.addedImageFailed;
      AppFeedback.showToast(
        context,
        imageFailed ? 'app.error.update'.tr() : 'app.success.add'.tr(),
        type: imageFailed ? ToastType.error : ToastType.success,
      );
    } catch (_) {
      if (context.mounted) {
        AppFeedback.showToast(
          context,
          'app.error.add'.tr(),
          type: ToastType.error,
        );
      }
    }
  }

  void _openAddForm(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.md,
          right: AppSpacing.md,
          top: AppSpacing.md,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.md,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'form.add_button'.tr(),
                    style: const TextStyle(
                      fontSize: AppFontSizes.xl,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              AddItemForm(
                onAdd: (draft, bytes) => _addItem(context, ref, draft, bytes),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 選択中アイテムのタグを一括変更し、選択を解除する。
  Future<void> _bulkTagChange(
    BuildContext context,
    WidgetRef ref,
    String? tagId,
  ) async {
    final ids = ref.read(selectionControllerProvider).ids.toList();
    try {
      await ref.read(itemControllerProvider).bulkTagChange(ids, tagId);
    } catch (_) {
      if (context.mounted) {
        AppFeedback.showToast(
          context,
          'app.error.update'.tr(),
          type: ToastType.error,
        );
      }
    } finally {
      ref.read(selectionControllerProvider.notifier).clear();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 選択モード中は追加 UI を一括操作バーに差し替える（ボトムに固定表示するため
    // スクロールで流れず常に見える）。
    final selectionActive = ref.watch(selectionActiveProvider);
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.surfaceBorder)),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppLayout.maxContentWidth,
          ),
          child: selectionActive
              ? _buildBulkBar(context, ref)
              : _buildAddRow(context, ref),
        ),
      ),
    );
  }

  Widget _buildAddRow(BuildContext context, WidgetRef ref) {
    final hasGroup = ref.watch(activeGroupProvider.select((g) => g != null));
    return QuickAddInput(
      onAdd: (name) => _quickAdd(context, ref, name),
      onDetailAdd: hasGroup ? () => _openAddForm(context, ref) : null,
      disabled: !hasGroup,
    );
  }

  Widget _buildBulkBar(BuildContext context, WidgetRef ref) {
    final count = ref.watch(selectionCountProvider);
    final tags = ref.watch(tagsProvider).value ?? const <Tag>[];
    return BulkActionBar(
      count: count,
      tags: tags,
      onChangeTag: (tagId) => _bulkTagChange(context, ref, tagId),
      onCancel: () => ref.read(selectionControllerProvider.notifier).clear(),
    );
  }
}
