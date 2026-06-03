import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/repositories/user_repository.dart';
import 'group_providers.dart';
import 'repository_providers.dart';

/// uid を表示名にフォールバック変換する（表示名が空なら uid 先頭 6 文字）。
String _fallbackName(String uid) => uid.length <= 6 ? uid : uid.substring(0, 6);

/// 各メンバーのユーザードキュメントを購読し、`uid → displayName` マップを合成するストリーム。
Stream<Map<String, String>> _watchMemberNames(
  UserRepository repo,
  List<String> memberIds,
) {
  if (memberIds.isEmpty) return Stream.value(const {});

  final names = <String, String>{};
  final subs = <StreamSubscription<dynamic>>[];
  late final StreamController<Map<String, String>> controller;

  controller = StreamController<Map<String, String>>(
    onCancel: () {
      for (final s in subs) {
        s.cancel();
      }
    },
  );

  for (final uid in memberIds) {
    final sub = repo
        .watchUser(uid)
        .listen(
          (user) {
            final dn = user?.displayName.trim();
            names[uid] = (dn != null && dn.isNotEmpty)
                ? dn
                : _fallbackName(uid);
            controller.add(Map.of(names));
          },
          onError: (_) {
            // 表示名解決エラーは UI を止めない（uid フォールバック）。
            names[uid] = _fallbackName(uid);
            controller.add(Map.of(names));
          },
        );
    subs.add(sub);
  }

  return controller.stream;
}

/// 現在グループのメンバーの表示名マップをリアルタイム購読する（旧 `useGroupMembers`）。
///
/// 「買います」宣言者の表示名をパートナーの画面に表示するために利用する。
final groupMemberNamesProvider = StreamProvider<Map<String, String>>((ref) {
  final group = ref.watch(groupControllerProvider).group;
  if (group == null || group.memberIds.isEmpty) {
    return Stream.value(const <String, String>{});
  }
  return _watchMemberNames(ref.watch(userRepositoryProvider), group.memberIds);
});
