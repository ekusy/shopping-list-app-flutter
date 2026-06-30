import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/item.dart';
import '../../providers/selection_controller.dart';
import '../item_card.dart';

/// [ItemCard] を選択状態の provider に接続するラッパー。
///
/// 選択 ID 集合のうち **自分の ID の所属だけ**（[isItemSelectedProvider]）と選択モードの
/// 有無（[selectionActiveProvider]）を watch するため、1 件をトグルしても**その行だけ**が
/// 再ビルドされる（リスト全体は再ビルドされない）。`ItemCard` は props のみを受け取る
/// pure な `StatelessWidget` のまま保ち、Riverpod への依存をこの行に閉じ込める。
class SelectableItemRow extends ConsumerWidget {
  const SelectableItemRow({
    super.key,
    required this.item,
    required this.currentUid,
    required this.memberNames,
    required this.onSetVolunteer,
    required this.onSetPurchased,
    required this.onEdit,
    required this.onDelete,
  });

  final Item item;
  final String? currentUid;
  final Map<String, String> memberNames;
  final void Function(String? uid) onSetVolunteer;
  final void Function(bool purchased) onSetPurchased;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectionMode = ref.watch(selectionActiveProvider);
    final isSelected = ref.watch(isItemSelectedProvider(item.id));
    return ItemCard(
      item: item,
      currentUid: currentUid,
      memberNames: memberNames,
      selectionMode: selectionMode,
      isSelected: isSelected,
      onSelect: () =>
          ref.read(selectionControllerProvider.notifier).toggle(item.id),
      onSetVolunteer: onSetVolunteer,
      onSetPurchased: onSetPurchased,
      onEdit: onEdit,
      onDelete: onDelete,
    );
  }
}
