import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/entities/item.dart';
import '../../domain/entities/tag.dart';
import '../providers/group_providers.dart';
import 'confirm_dialog.dart';
import 'dashboard/selectable_item_row.dart';

/// タグ単位でグルーピングした買い物リスト表示。
///
/// 各行は [SelectableItemRow] が選択状態の provider に接続する。選択モード時の
/// 一括操作バーはボトムバー（`DashboardAddBar`）側に固定表示するため、本ウィジェットは
/// 選択状態を保持しない（セクションの折りたたみ表示のみ管理する）。
class ShoppingList extends ConsumerStatefulWidget {
  const ShoppingList({
    super.key,
    required this.items,
    this.filterTagIds = const [],
    this.currentUid,
    this.memberNames = const {},
    required this.onSetVolunteer,
    required this.onSetPurchased,
    required this.onEdit,
    required this.onDelete,
    required this.onClearPurchased,
    required this.onDeleteSection,
  });

  final List<Item> items;
  final List<String> filterTagIds;
  final String? currentUid;
  final Map<String, String> memberNames;
  final void Function(String itemId, String? uid) onSetVolunteer;
  final void Function(String itemId, bool purchased) onSetPurchased;
  final void Function(String itemId) onEdit;
  final void Function(String itemId) onDelete;
  final VoidCallback onClearPurchased;
  final void Function(String? tagId) onDeleteSection;

  @override
  ConsumerState<ShoppingList> createState() => _ShoppingListState();
}

class _ShoppingListState extends ConsumerState<ShoppingList> {
  bool _purchasedExpanded = true;
  final Set<String> _collapsed = {};

  String _sectionKey(String? tagId) => tagId ?? '__no_tag__';

  void _toggleCollapse(String? tagId) {
    final key = _sectionKey(tagId);
    setState(() {
      if (!_collapsed.remove(key)) _collapsed.add(key);
    });
  }

  Future<void> _confirmDeleteSection(String? tagId, String tagName) async {
    final ok = await showConfirmDialog(
      context,
      title: 'tag.section_delete'.tr(),
      message: 'tag.section_confirm_delete'.tr(namedArgs: {'name': tagName}),
    );
    if (ok) widget.onDeleteSection(tagId);
  }

  @override
  Widget build(BuildContext context) {
    final tags = ref.watch(tagsProvider).value ?? const <Tag>[];

    if (widget.items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.only(top: AppSpacing.lg),
          child: Text(
            'list.empty'.tr(),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: AppFontSizes.md,
            ),
          ),
        ),
      );
    }

    bool matchesFilter(Item i) => widget.filterTagIds.isEmpty
        ? true
        : widget.filterTagIds.contains(i.tagId ?? '');

    final activeItems = widget.items
        .where((i) => !i.isPurchased)
        .where(matchesFilter)
        .toList();
    final boughtItems = widget.items.where((i) => i.isPurchased).toList();

    // タグ順でグルーピング（タグなし / 削除済みタグは末尾の「タグなし」セクション）。
    final tagIdSet = {for (final t in tags) t.id};
    final sections = <_Section>[];
    for (final tag in tags) {
      final tagItems = activeItems.where((i) => i.tagId == tag.id).toList();
      if (tagItems.isNotEmpty) {
        sections.add(_Section(tag.id, tag.name, tagItems));
      }
    }
    final noTagItems = activeItems
        .where((i) => i.tagId == null || !tagIdSet.contains(i.tagId))
        .toList();
    if (noTagItems.isNotEmpty) {
      sections.add(_Section(null, 'tag.no_tag'.tr(), noTagItems));
    }

    return ListView(
      children: [
        for (final section in sections) _buildSection(section),
        if (boughtItems.isNotEmpty) _buildPurchasedSection(boughtItems),
      ],
    );
  }

  Widget _buildSection(_Section section) {
    final collapsed = _collapsed.contains(_sectionKey(section.tagId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => _toggleCollapse(section.tagId),
          child: Container(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0x0D000000), width: 2),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      text: section.tagName,
                      style: const TextStyle(
                        fontSize: AppFontSizes.md,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                      children: [
                        TextSpan(
                          text:
                              '  ${'tag.items_count'.tr(namedArgs: {'count': '${section.items.length}'})}',
                          style: const TextStyle(
                            fontSize: AppFontSizes.sm,
                            fontWeight: FontWeight.w400,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      _confirmDeleteSection(section.tagId, section.tagName),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.error,
                    visualDensity: VisualDensity.compact,
                  ),
                  child: Text(
                    'tag.section_delete'.tr(),
                    style: const TextStyle(fontSize: AppFontSizes.xs),
                  ),
                ),
                Text(
                  collapsed ? '▼' : '▲',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        if (!collapsed)
          for (final item in section.items) _itemRow(item),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }

  Widget _buildPurchasedSection(List<Item> boughtItems) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => setState(() => _purchasedExpanded = !_purchasedExpanded),
          child: Container(
            margin: const EdgeInsets.only(top: AppSpacing.md),
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0x0D000000), width: 2),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'list.bought_section_count'.tr(
                      namedArgs: {'count': '${boughtItems.length}'},
                    ),
                    style: const TextStyle(
                      fontSize: AppFontSizes.xl,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: widget.onClearPurchased,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.error,
                    visualDensity: VisualDensity.compact,
                  ),
                  child: Text(
                    'list.clear_purchased'.tr(),
                    style: const TextStyle(fontSize: AppFontSizes.xs),
                  ),
                ),
                Text(
                  _purchasedExpanded ? '▲' : '▼',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (_purchasedExpanded)
          for (final item in boughtItems) _itemRow(item),
      ],
    );
  }

  Widget _itemRow(Item item) => SelectableItemRow(
    key: ValueKey(item.id),
    item: item,
    currentUid: widget.currentUid,
    memberNames: widget.memberNames,
    onSetVolunteer: (uid) => widget.onSetVolunteer(item.id, uid),
    onSetPurchased: (purchased) => widget.onSetPurchased(item.id, purchased),
    onEdit: () => widget.onEdit(item.id),
    onDelete: () => widget.onDelete(item.id),
  );
}

class _Section {
  _Section(this.tagId, this.tagName, this.items);
  final String? tagId;
  final String tagName;
  final List<Item> items;
}
