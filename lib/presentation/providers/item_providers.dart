import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/item.dart';
import 'group_providers.dart';
import 'repository_providers.dart';

/// アクティブグループ配下のアイテムをリアルタイム購読する（旧 `useItems`）。
///
/// グループ未所属時は空配列を返す。order 昇順優先、未設定時は createdAt 降順。
final itemsProvider = StreamProvider<List<Item>>((ref) {
  final gid = ref.watch(activeGroupIdProvider);
  if (gid == null) return Stream.value(const <Item>[]);
  return ref.watch(itemRepositoryProvider).watchItems(gid);
});

/// 未同期書き込み（オフライン更新待ち）アイテムの件数。
final pendingItemCountProvider = Provider<int>((ref) {
  final items = ref.watch(itemsProvider).value ?? const <Item>[];
  return items.where((i) => i.pendingWrite).length;
});
