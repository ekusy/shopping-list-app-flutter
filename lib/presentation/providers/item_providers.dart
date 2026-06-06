import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/stream_retry.dart';
import '../../domain/entities/item.dart';
import 'group_providers.dart';
import 'repository_providers.dart';

/// アクティブグループ配下のアイテムをリアルタイム購読する（旧 `useItems`）。
///
/// グループ未所属時は空配列を返す。order 昇順優先、未設定時は createdAt 降順。
///
/// 実機 Web の初回ログイン直後に Firestore リスナーが初回スナップショットを返さない
/// ことがある事象 (#24) を緩和するため、初回イベントが一定時間来なければ自動で再購読する。
final itemsProvider = StreamProvider<List<Item>>((ref) {
  final gid = ref.watch(activeGroupIdProvider);
  if (gid == null) return Stream.value(const <Item>[]);
  final repo = ref.watch(itemRepositoryProvider);
  return resubscribeIfNoFirstEvent(() => repo.watchItems(gid));
});

/// 未同期書き込み（オフライン更新待ち）アイテムの件数。
final pendingItemCountProvider = Provider<int>((ref) {
  final items = ref.watch(itemsProvider).value ?? const <Item>[];
  return items.where((i) => i.pendingWrite).length;
});
