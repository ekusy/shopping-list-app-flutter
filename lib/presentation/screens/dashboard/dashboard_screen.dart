import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/item.dart';
import '../../providers/auth_providers.dart';
import '../../providers/group_members_provider.dart';
import '../../providers/group_providers.dart';
import '../../providers/item_providers.dart';
import '../../providers/network_providers.dart';
import '../../providers/repository_providers.dart';
import '../../widgets/add_item_form.dart';
import '../../widgets/app_feedback.dart';
import '../../widgets/app_sidebar.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/filter_bar.dart';
import '../../widgets/group_switcher.dart';
import '../../widgets/item_edit_modal.dart';
import '../../widgets/quick_add_input.dart';
import '../../widgets/shopping_list.dart';
import '../../widgets/tag_manager.dart';

/// ダッシュボード（メイン画面）。買い物リストの追加・更新・削除を行う。
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  List<String> _filterTagIds = [];

  String? get _groupId => ref.read(activeGroupProvider)?.id;
  String? get _uid => ref.read(currentUserProvider)?.uid;

  int _nextOrder() {
    final items = ref.read(itemsProvider).value ?? const [];
    return items.fold<int>(0, (max, i) => (i.order ?? 0) > max ? i.order! : max) + 1;
  }

  Future<void> _quickAdd(String name) async {
    final groupId = _groupId;
    if (groupId == null) return;
    final draft = Item(
      id: '',
      name: name,
      category: '',
      note: '',
      imageUrl: '',
      status: ItemStatus.active,
      buyingBy: null,
      addedBy: _uid,
    );
    AppFeedback.showLoading(context, 'status.adding'.tr());
    try {
      await ref.read(itemRepositoryProvider).addItem(groupId, draft, _nextOrder());
    } catch (_) {
      if (mounted) {
        AppFeedback.showToast(context, 'app.error.add'.tr(),
            type: ToastType.error);
      }
    } finally {
      if (mounted) AppFeedback.hide(context);
    }
  }

  Future<void> _addItem(Item draft) async {
    final groupId = _groupId;
    if (groupId == null) return;
    try {
      await ref
          .read(itemRepositoryProvider)
          .addItem(groupId, draft.copyWith(addedBy: _uid), _nextOrder());
      if (mounted) {
        Navigator.of(context).pop(); // フォームのボトムシートを閉じる
        AppFeedback.showToast(context, 'app.success.add'.tr(),
            type: ToastType.success);
      }
    } catch (_) {
      if (mounted) {
        AppFeedback.showToast(context, 'app.error.add'.tr(),
            type: ToastType.error);
      }
    }
  }

  Future<void> _setVolunteer(String id, String? uid) async {
    final groupId = _groupId;
    if (groupId == null) return;
    try {
      await ref.read(itemRepositoryProvider).setVolunteer(groupId, id, uid);
      if (uid != null && uid == _uid && mounted) {
        AppFeedback.showToast(context, 'app.success.volunteer'.tr(),
            type: ToastType.success);
      }
    } catch (_) {
      if (mounted) {
        AppFeedback.showToast(context, 'app.error.update'.tr(),
            type: ToastType.error);
      }
    }
  }

  Future<void> _setPurchased(String id, bool purchased) async {
    final groupId = _groupId;
    if (groupId == null) return;
    try {
      await ref.read(itemRepositoryProvider).setPurchased(groupId, id, purchased);
      if (purchased && mounted) {
        AppFeedback.showToast(context, 'app.success.bought'.tr(),
            type: ToastType.success);
      }
    } catch (_) {
      if (mounted) {
        AppFeedback.showToast(context, 'app.error.update'.tr(),
            type: ToastType.error);
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
      onSave: (name, tagId, note, imageUrl) async {
        final groupId = _groupId;
        if (groupId == null) return;
        try {
          await ref.read(itemRepositoryProvider).updateItemDetails(
                groupId,
                id,
                name: name,
                tagId: tagId,
                note: note,
                imageUrl: imageUrl,
              );
          if (mounted) {
            Navigator.of(context).pop();
            AppFeedback.showToast(context, 'app.success.add'.tr(),
                type: ToastType.success);
          }
        } catch (_) {
          if (mounted) {
            AppFeedback.showToast(context, 'app.error.update'.tr(),
                type: ToastType.error);
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
    final groupId = _groupId;
    if (groupId == null) return;
    try {
      await ref.read(itemRepositoryProvider).deleteItem(groupId, id);
      if (mounted) {
        AppFeedback.showToast(context, 'app.success.delete'.tr());
      }
    } catch (_) {
      if (mounted) {
        AppFeedback.showToast(context, 'app.error.delete'.tr(),
            type: ToastType.error);
      }
    }
  }

  Future<void> _deleteSection(String? tagId) async {
    final groupId = _groupId;
    if (groupId == null) return;
    final repo = ref.read(itemRepositoryProvider);
    try {
      if (tagId != null) {
        await repo.deleteItemsByTag(groupId, tagId);
      } else {
        final items = ref.read(itemsProvider).value ?? const [];
        final noTagIds = items
            .where((i) => i.tagId == null && !i.isPurchased)
            .map((i) => i.id);
        await Future.wait(noTagIds.map((id) => repo.deleteItem(groupId, id)));
      }
      if (mounted) AppFeedback.showToast(context, 'app.success.delete'.tr());
    } catch (_) {
      if (mounted) {
        AppFeedback.showToast(context, 'app.error.delete'.tr(),
            type: ToastType.error);
      }
    }
  }

  Future<void> _bulkTagChange(List<String> ids, String? tagId) async {
    final groupId = _groupId;
    if (groupId == null) return;
    try {
      await ref.read(itemRepositoryProvider).batchUpdateTag(groupId, ids, tagId);
    } catch (_) {
      if (mounted) {
        AppFeedback.showToast(context, 'app.error.update'.tr(),
            type: ToastType.error);
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
        AppFeedback.showToast(context, 'app.error.delete'.tr(),
            type: ToastType.error);
      }
    }
  }

  void _openAddForm() {
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
                  Text('form.add_button'.tr(),
                      style: const TextStyle(
                          fontSize: AppFontSizes.xl,
                          fontWeight: FontWeight.w700)),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              AddItemForm(onAdd: _addItem),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // オンライン復帰時に同期中スナックバーを表示する。
    ref.listen(isOnlineProvider, (prev, next) {
      final wasOffline = prev?.value == false;
      final isOnline = next.value == true;
      if (wasOffline && isOnline && mounted) {
        final messenger = ScaffoldMessenger.of(context);
        AppFeedback.showLoading(context, 'network.syncing'.tr());
        Future.delayed(const Duration(seconds: 3), messenger.hideCurrentSnackBar);
      }
    });

    final group = ref.watch(activeGroupProvider);
    final items = ref.watch(itemsProvider);
    final tags = ref.watch(tagsProvider).value ?? const [];
    final memberNames = ref.watch(groupMemberNamesProvider).value ?? const {};
    final uid = ref.watch(currentUserProvider)?.uid;
    final isOnline = ref.watch(isOnlineProvider).value ?? true;
    final pendingCount = ref.watch(pendingItemCountProvider);

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
            _buildHeader(group?.name ?? 'app.title'.tr(), pendingCount),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                      maxWidth: AppLayout.maxContentWidth),
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
                                  ? (_filterTagIds.where((t) => t != id).toList())
                                  : [..._filterTagIds, id];
                            }),
                            onClear: () => setState(() => _filterTagIds = []),
                          ),
                        Expanded(
                          child: items.isLoading
                              ? const Center(
                                  child: CircularProgressIndicator(
                                      color: AppColors.primary))
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
            _buildBottomBar(group != null),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String title, int pendingCount) {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppLayout.maxContentWidth),
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
                      const Text(' ▼',
                          style: TextStyle(color: AppColors.primary)),
                    ],
                  ),
                ),
              ),
              if (pendingCount > 0)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.xs),
                  child: Text(
                    'status.pending_count'
                        .tr(namedArgs: {'count': '$pendingCount'}),
                    style: const TextStyle(
                      fontSize: AppFontSizes.xs,
                      color: AppColors.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              OutlinedButton(
                onPressed: () => showTagManager(context),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  backgroundColor: AppColors.primaryLight,
                ),
                child: Text('tag.manage'.tr(),
                    style: const TextStyle(fontSize: AppFontSizes.xs)),
              ),
              IconButton(
                icon: const Icon(Icons.menu),
                tooltip: 'sidebar.open'.tr(),
                onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(bool hasGroup) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.surfaceBorder)),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppLayout.maxContentWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              QuickAddInput(onAdd: _quickAdd, disabled: !hasGroup),
              const SizedBox(height: AppSpacing.xs),
              OutlinedButton(
                onPressed: _openAddForm,
                child: Text('＋ ${'list.detail_add'.tr()}'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
