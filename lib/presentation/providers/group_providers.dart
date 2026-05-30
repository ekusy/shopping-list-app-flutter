import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/plan_limits.dart';
import '../../core/errors/app_error.dart';
import '../../domain/entities/group.dart';
import '../../domain/entities/tag.dart';
import 'auth_providers.dart';
import 'repository_providers.dart';

/// グループ状態（アクティブグループ・参加グループ一覧・ロード中フラグ）。
class GroupState {
  const GroupState({
    this.group,
    this.joinedGroups = const [],
    this.loading = true,
  });

  /// 現在のアクティブグループ（未所属は null）。
  final Group? group;

  /// ログイン中ユーザーが参加しているグループ一覧。
  final List<Group> joinedGroups;

  final bool loading;

  GroupState copyWith({
    Group? Function()? group,
    List<Group>? joinedGroups,
    bool? loading,
  }) {
    return GroupState(
      group: group != null ? group() : this.group,
      joinedGroups: joinedGroups ?? this.joinedGroups,
      loading: loading ?? this.loading,
    );
  }
}

/// グループ状態と操作を管理するコントローラ（旧 `GroupContext`）。
///
/// ログイン中ユーザーの groupId を監視し、アクティブグループドキュメントを購読する。
/// Firebase 依存はリポジトリ層に閉じている。
class GroupController extends Notifier<GroupState> {
  StreamSubscription<Group?>? _groupSub;

  @override
  GroupState build() {
    final user = ref.watch(currentUserProvider);
    ref.onDispose(() {
      _groupSub?.cancel();
      _groupSub = null;
    });

    if (user == null) {
      return const GroupState(group: null, joinedGroups: [], loading: false);
    }

    // currentUser 確定時は loading=true を返しつつ非同期ロードを起動する。
    _loadForUser(user.uid);
    return const GroupState(loading: true);
  }

  /// ユーザーの groupId と参加グループを読み込み、アクティブグループを確定する。
  /// groupId が指すグループが消えている / null でも参加グループが残っていれば先頭で復旧する。
  Future<void> _loadForUser(String uid) async {
    final groupRepo = ref.read(groupRepositoryProvider);
    final userRepo = ref.read(userRepositoryProvider);
    try {
      final groupIdFuture = userRepo.getUserGroupId(uid);
      final groupsFuture = groupRepo.getGroupsByMemberId(uid);
      final groupId = await groupIdFuture;
      final groups = await groupsFuture;

      Group? active;
      if (groupId != null) {
        for (final g in groups) {
          if (g.id == groupId) {
            active = g;
            break;
          }
        }
      }
      // groupId が null / 指すグループが消えている場合は先頭グループで復旧する (#177)。
      active ??= groups.isNotEmpty ? groups.first : null;

      // 採用したアクティブグループが groupId と異なるなら永続化して復旧する。
      if (active != null && active.id != groupId) {
        unawaited(userRepo.updateUserGroupId(uid, active.id).catchError((_) {}));
      }

      state = GroupState(group: active, joinedGroups: groups, loading: false);
      _subscribeActiveGroup(uid, active?.id);
    } catch (_) {
      state = state.copyWith(loading: false);
    }
  }

  /// アクティブグループドキュメントを購読し、退場・解散・更新を反映する。
  void _subscribeActiveGroup(String uid, String? groupId) {
    _groupSub?.cancel();
    _groupSub = null;
    if (groupId == null) return;

    _groupSub = ref.read(groupRepositoryProvider).watchGroup(groupId).listen(
      (updated) {
        if (updated == null || !updated.memberIds.contains(uid)) {
          // 退場またはグループ解散 → メンバーシップ状態をリセット。
          state = state.copyWith(
            group: () => null,
            joinedGroups:
                state.joinedGroups.where((g) => g.id != groupId).toList(),
          );
          _groupSub?.cancel();
          _groupSub = null;
          return;
        }
        state = state.copyWith(
          group: () => updated,
          joinedGroups: state.joinedGroups
              .map((g) => g.id == groupId ? updated : g)
              .toList(),
        );
      },
      onError: (_) {},
    );
  }

  String _requireUid() {
    final uid = ref.read(authRepositoryProvider).currentUser?.uid;
    if (uid == null) {
      throw const AppError(AppErrorCode.authUnknown, 'Not authenticated');
    }
    return uid;
  }

  /// グループを新規作成し、アクティブグループに設定する。
  ///
  /// @returns 生成された招待コード
  Future<String> createGroup(String groupName) async {
    final uid = _requireUid();
    final groupRepo = ref.read(groupRepositoryProvider);
    final defaultTagNames = ['tag.default_urgent'.tr(), 'tag.default_bulk'.tr()];
    final result = await groupRepo.createGroup(uid, groupName, defaultTagNames);

    final groupData = await groupRepo.getGroup(result.groupId);
    final groups = await groupRepo.getGroupsByMemberId(uid);
    state = GroupState(group: groupData, joinedGroups: groups, loading: false);
    _subscribeActiveGroup(uid, groupData?.id);
    return result.inviteCode;
  }

  /// グループ名を変更する（空文字は拒否）。
  Future<void> renameGroup(String name) async {
    final group = state.group;
    if (group == null) {
      throw const AppError(AppErrorCode.dataUnknown, 'No active group');
    }
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const AppError(AppErrorCode.dataUnknown, 'empty_name');
    }
    await ref.read(groupRepositoryProvider).updateGroupName(group.id, trimmed);
    // 楽観的更新（購読でも反映されるが即時反映する）。
    state = state.copyWith(
      group: () => group.copyWith(name: trimmed),
      joinedGroups: state.joinedGroups
          .map((g) => g.id == group.id ? g.copyWith(name: trimmed) : g)
          .toList(),
    );
  }

  /// グループから脱退する（オーナーは脱退不可）。
  /// [targetGroupId] 省略時はアクティブグループを対象とする。
  Future<void> leaveGroup([String? targetGroupId]) async {
    final uid = _requireUid();
    final gid = targetGroupId ?? state.group?.id;
    if (gid == null) {
      throw const AppError(AppErrorCode.dataUnknown, 'Not in group');
    }
    final target = _findGroup(gid);
    if (target == null) {
      throw const AppError(AppErrorCode.dataNotFound, 'Group not found');
    }
    if (target.ownerId == uid) {
      throw const AppError(
        AppErrorCode.groupOwnerCannotLeave,
        'Owner must disband or transfer',
      );
    }
    await ref.read(groupRepositoryProvider).leaveGroup(uid, gid);
    final remaining = state.joinedGroups.where((g) => g.id != gid).toList();
    if (gid == state.group?.id) {
      state = state.copyWith(group: () => null, joinedGroups: remaining);
      _subscribeActiveGroup(uid, null);
    } else {
      state = state.copyWith(joinedGroups: remaining);
    }
  }

  /// グループを解散する（オーナーのみ）。
  /// [targetGroupId] 省略時はアクティブグループを対象とする。
  Future<void> disbandGroup([String? targetGroupId]) async {
    final uid = _requireUid();
    final gid = targetGroupId ?? state.group?.id;
    if (gid == null) {
      throw const AppError(AppErrorCode.dataUnknown, 'Not in group');
    }
    final target = _findGroup(gid);
    if (target == null) {
      throw const AppError(AppErrorCode.dataNotFound, 'Group not found');
    }
    if (target.ownerId != uid) {
      throw const AppError(
        AppErrorCode.dataPermissionDenied,
        'Only owner can disband',
      );
    }
    final groupRepo = ref.read(groupRepositoryProvider);
    await groupRepo.disbandGroup(uid, gid);
    final groups = await groupRepo.getGroupsByMemberId(uid);
    if (gid == state.group?.id) {
      state = state.copyWith(group: () => null, joinedGroups: groups);
      _subscribeActiveGroup(uid, null);
    } else {
      state = state.copyWith(joinedGroups: groups);
    }
  }

  /// アクティブグループを即時切り替える（永続化は非同期）。
  void switchGroup(String groupId) {
    final uid = ref.read(authRepositoryProvider).currentUser?.uid;
    if (uid == null) return;
    final target = _findGroup(groupId);
    if (target == null) return;
    state = state.copyWith(group: () => target);
    _subscribeActiveGroup(uid, groupId);
    unawaited(
      ref.read(userRepositoryProvider).updateUserGroupId(uid, groupId).catchError((_) {}),
    );
  }

  /// 招待コードでグループに参加し、そのグループに切り替える。
  Future<void> joinGroupByCode(String inviteCode) async {
    final uid = _requireUid();
    final groupRepo = ref.read(groupRepositoryProvider);
    final groupId = await groupRepo.joinGroup(uid, inviteCode);
    final groupData = await groupRepo.getGroup(groupId);
    final joined = state.joinedGroups.any((g) => g.id == groupId)
        ? state.joinedGroups
        : [...state.joinedGroups, ?groupData];
    state = state.copyWith(group: () => groupData, joinedGroups: joined);
    _subscribeActiveGroup(uid, groupData?.id);
  }

  /// タグを追加する。プラン上限に達している場合は [AppErrorCode.dataTagLimitExceeded] を throw する。
  Future<void> addTag(String name) async {
    final group = state.group;
    if (group == null) {
      throw const AppError(AppErrorCode.dataUnknown, 'No active group');
    }
    // tagsProvider は groupController に依存するため、循環依存を避けて
    // リポジトリから現在のタグを直接取得する。
    final tags = await ref.read(tagRepositoryProvider).watchTags(group.id).first;
    final limit = PlanLimits.tagLimitFor(group.plan);
    if (tags.length >= limit) {
      throw AppError(
        AppErrorCode.dataTagLimitExceeded,
        'Tag limit reached ($limit)',
      );
    }
    final nextOrder = tags.fold<int>(0, (max, t) {
          final o = t.order ?? 0;
          return o > max ? o : max;
        }) +
        1;
    await ref.read(tagRepositoryProvider).addTag(group.id, name.trim(), nextOrder);
  }

  /// タグ名を変更する。
  Future<void> renameTag(String tagId, String name) async {
    final group = state.group;
    if (group == null) {
      throw const AppError(AppErrorCode.dataUnknown, 'No active group');
    }
    await ref.read(tagRepositoryProvider).updateTagName(group.id, tagId, name.trim());
  }

  /// タグを削除する（参照アイテムの tagId も同一バッチでクリア）。
  Future<void> deleteTag(String tagId) async {
    final group = state.group;
    if (group == null) {
      throw const AppError(AppErrorCode.dataUnknown, 'No active group');
    }
    await ref.read(tagRepositoryProvider).deleteTagAndClearItems(group.id, tagId);
  }

  /// オーナーが指定メンバーを強制退場させる（更新は購読で反映）。
  Future<void> removeMember(String targetUid) async {
    final group = state.group;
    if (group == null) {
      throw const AppError(AppErrorCode.dataUnknown, 'Not in group');
    }
    await ref.read(groupRepositoryProvider).removeMember(group.id, targetUid);
  }

  /// アクティブグループの購入済みアイテムをすべて削除する。
  Future<void> clearPurchasedItems() async {
    final group = state.group;
    if (group == null) {
      throw const AppError(AppErrorCode.dataUnknown, 'No active group');
    }
    await ref.read(itemRepositoryProvider).deletePurchasedItems(group.id);
  }

  /// 招待コードでグループを検索する（参加前の確認表示用）。
  Future<Group?> findGroupByInviteCode(String inviteCode) {
    return ref.read(groupRepositoryProvider).getGroupByInviteCode(inviteCode);
  }

  Group? _findGroup(String gid) {
    for (final g in state.joinedGroups) {
      if (g.id == gid) return g;
    }
    return state.group?.id == gid ? state.group : null;
  }
}

/// グループコントローラのプロバイダ。
final groupControllerProvider =
    NotifierProvider<GroupController, GroupState>(GroupController.new);

/// アクティブグループ（未所属は null）。
final activeGroupProvider = Provider<Group?>(
  (ref) => ref.watch(groupControllerProvider).group,
);

/// アクティブグループの ID。
final activeGroupIdProvider = Provider<String?>(
  (ref) => ref.watch(groupControllerProvider.select((s) => s.group?.id)),
);

/// グループのロード中フラグ。
final groupLoadingProvider = Provider<bool>(
  (ref) => ref.watch(groupControllerProvider.select((s) => s.loading)),
);

/// アクティブグループのタグ一覧（order 昇順）。
final tagsProvider = StreamProvider<List<Tag>>((ref) {
  final gid = ref.watch(activeGroupIdProvider);
  if (gid == null) return Stream.value(const <Tag>[]);
  return ref.watch(tagRepositoryProvider).watchTags(gid);
});

/// プランのタグ上限数。
final tagLimitProvider = Provider<int>((ref) {
  final plan = ref.watch(groupControllerProvider.select((s) => s.group?.plan));
  return PlanLimits.tagLimitFor(plan);
});

/// プランのタグ上限に達しているかどうか。
final tagLimitReachedProvider = Provider<bool>((ref) {
  final tags = ref.watch(tagsProvider).value ?? const <Tag>[];
  return tags.length >= ref.watch(tagLimitProvider);
});
