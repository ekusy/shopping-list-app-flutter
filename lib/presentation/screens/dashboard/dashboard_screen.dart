import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/tag.dart';
import '../../providers/auth_providers.dart';
import '../../providers/group_members_provider.dart';
import '../../providers/group_providers.dart';
import '../../providers/item_controller.dart';
import '../../providers/item_providers.dart';
import '../../providers/network_providers.dart';
import '../../widgets/app_feedback.dart';
import '../../widgets/app_sidebar.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/dashboard/dashboard_add_bar.dart';
import '../../widgets/dashboard/dashboard_header.dart';
import '../../widgets/filter_bar.dart';
import '../../widgets/item_edit_modal.dart';
import '../../widgets/shopping_list.dart';

/// ダッシュボード（メイン画面）。買い物リストの一覧表示・更新・削除を行う。
///
/// アイテムへの書き込み操作は [ItemController] に委譲し、本画面は一覧表示と
/// UI フィードバック（トースト / 確認ダイアログ / 画面遷移）に専念する。追加 UI は
/// [DashboardAddBar]、ヘッダーは [DashboardHeader] に分離している。
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  List<String> _filterTagIds = [];

  String? get _uid => ref.read(currentUserProvider)?.uid;

  Future<void> _setVolunteer(String id, String? uid) async {
    try {
      await ref.read(itemControllerProvider).setVolunteer(id, uid);
      if (uid != null && uid == _uid && mounted) {
        AppFeedback.showToast(
          context,
          'app.success.volunteer'.tr(),
          type: ToastType.success,
        );
      }
    } catch (_) {
      if (mounted) {
        AppFeedback.showToast(
          context,
          'app.error.update'.tr(),
          type: ToastType.error,
        );
      }
    }
  }

  Future<void> _setPurchased(String id, bool purchased) async {
    try {
      await ref.read(itemControllerProvider).setPurchased(id, purchased);
      if (purchased && mounted) {
        AppFeedback.showToast(
          context,
          'app.success.bought'.tr(),
          type: ToastType.success,
        );
      }
    } catch (_) {
      if (mounted) {
        AppFeedback.showToast(
          context,
          'app.error.update'.tr(),
          type: ToastType.error,
        );
      }
    }
  }

  void _editItem(String id) {
    final items = ref.read(itemsProvider).value ?? const [];
    final target = items.where((i) => i.id == id).firstOrNull;
    if (target == null) return;
    showItemEditModal(
      context,
      item: target,
      onSave: (name, tagId, note, imageUrl, imageBytes) async {
        try {
          await ref
              .read(itemControllerProvider)
              .updateItem(
                id,
                name: name,
                tagId: tagId,
                note: note,
                imageUrl: imageUrl,
                imageBytes: imageBytes,
                originalImageUrl: target.imageUrl,
              );
          if (mounted) {
            Navigator.of(context).pop();
            AppFeedback.showToast(
              context,
              'app.success.add'.tr(),
              type: ToastType.success,
            );
          }
        } catch (_) {
          if (mounted) {
            AppFeedback.showToast(
              context,
              'app.error.update'.tr(),
              type: ToastType.error,
            );
          }
        }
      },
    );
  }

  Future<void> _deleteItem(String id) async {
    final confirmed = await showConfirmDialog(
      context,
      message: 'app.info.delete_confirm'.tr(),
    );
    if (!confirmed) return;
    try {
      await ref.read(itemControllerProvider).deleteItem(id);
      if (mounted) {
        AppFeedback.showToast(context, 'app.success.delete'.tr());
      }
    } catch (_) {
      if (mounted) {
        AppFeedback.showToast(
          context,
          'app.error.delete'.tr(),
          type: ToastType.error,
        );
      }
    }
  }

  Future<void> _deleteSection(String? tagId) async {
    try {
      await ref.read(itemControllerProvider).deleteSection(tagId);
      if (mounted) AppFeedback.showToast(context, 'app.success.delete'.tr());
    } catch (_) {
      if (mounted) {
        AppFeedback.showToast(
          context,
          'app.error.delete'.tr(),
          type: ToastType.error,
        );
      }
    }
  }

  Future<void> _bulkTagChange(List<String> ids, String? tagId) async {
    try {
      await ref.read(itemControllerProvider).bulkTagChange(ids, tagId);
    } catch (_) {
      if (mounted) {
        AppFeedback.showToast(
          context,
          'app.error.update'.tr(),
          type: ToastType.error,
        );
      }
    }
  }

  Future<void> _clearPurchased() async {
    final confirmed = await showConfirmDialog(
      context,
      message: 'list.confirm_clear_purchased'.tr(),
    );
    if (!confirmed) return;
    try {
      await ref.read(groupControllerProvider.notifier).clearPurchasedItems();
      if (mounted) AppFeedback.showToast(context, 'app.success.delete'.tr());
    } catch (_) {
      if (mounted) {
        AppFeedback.showToast(
          context,
          'app.error.delete'.tr(),
          type: ToastType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // easy_localization の .tr() は static インスタンスを使うため BuildContext 依存が
    // 自動で作られない。context.locale を読むことで EasyLocalizationProvider への
    // InheritedWidget 依存を明示し、言語切替時に再ビルドされるようにする。
    final _ = context.locale;

    // オンライン復帰時に同期中スナックバーを表示する。
    ref.listen(isOnlineProvider, (prev, next) {
      final wasOffline = prev?.value == false;
      final isOnline = next.value == true;
      if (wasOffline && isOnline && mounted) {
        final messenger = ScaffoldMessenger.of(context);
        AppFeedback.showLoading(context, 'network.syncing'.tr());
        Future.delayed(
          const Duration(seconds: 3),
          messenger.hideCurrentSnackBar,
        );
      }
    });

    final items = ref.watch(itemsProvider);
    final tags = ref.watch(
      tagsProvider.select((s) => s.value ?? const <Tag>[]),
    );
    final memberNames = ref.watch(
      groupMemberNamesProvider.select(
        (s) => s.value ?? const <String, String>{},
      ),
    );
    final uid = ref.watch(currentUserProvider.select((u) => u?.uid));
    final isOnline = ref.watch(isOnlineProvider.select((s) => s.value ?? true));

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      endDrawer: const AppSidebar(),
      body: SafeArea(
        child: Column(
          children: [
            if (!isOnline)
              Container(
                width: double.infinity,
                color: AppColors.deleteBg,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Text(
                  'network.offline_banner'.tr(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.deleteText,
                    fontSize: AppFontSizes.sm,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            DashboardHeader(
              onOpenMenu: () => _scaffoldKey.currentState?.openEndDrawer(),
            ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppLayout.maxContentWidth,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      children: [
                        if (tags.isNotEmpty)
                          FilterBar(
                            tags: tags,
                            selectedTagIds: _filterTagIds,
                            onToggle: (id) => setState(() {
                              _filterTagIds = _filterTagIds.contains(id)
                                  ? (_filterTagIds
                                        .where((t) => t != id)
                                        .toList())
                                  : [..._filterTagIds, id];
                            }),
                            onClear: () => setState(() => _filterTagIds = []),
                          ),
                        Expanded(
                          child: items.isLoading
                              ? const Center(
                                  child: CircularProgressIndicator(
                                    color: AppColors.primary,
                                  ),
                                )
                              : ShoppingList(
                                  items: items.value ?? const [],
                                  filterTagIds: _filterTagIds,
                                  currentUid: uid,
                                  memberNames: memberNames,
                                  onSetVolunteer: _setVolunteer,
                                  onSetPurchased: _setPurchased,
                                  onEdit: _editItem,
                                  onDelete: _deleteItem,
                                  onClearPurchased: _clearPurchased,
                                  onDeleteSection: _deleteSection,
                                  onBulkTagChange: _bulkTagChange,
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const DashboardAddBar(),
          ],
        ),
      ),
    );
  }
}
