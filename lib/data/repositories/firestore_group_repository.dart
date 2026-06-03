import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/errors/app_error.dart';
import '../../core/utils/invite_code.dart';
import '../../domain/entities/group.dart';
import '../../domain/repositories/group_repository.dart';
import '../firebase/firebase_error_converter.dart';
import '../firebase/firestore_mappers.dart';

/// Firestore を用いた [GroupRepository] 実装。
class FirestoreGroupRepository implements GroupRepository {
  FirestoreGroupRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _groups =>
      _db.collection('groups');

  DocumentReference<Map<String, dynamic>> _userRef(String uid) =>
      _db.collection('users').doc(uid);

  @override
  Future<CreateGroupResult> createGroup(
    String uid,
    String groupName,
    List<String> defaultTagNames,
  ) async {
    try {
      final inviteCode = generateInviteCode();
      final batch = _db.batch();

      final groupRef = _groups.doc();
      batch.set(groupRef, {
        'name': groupName,
        'ownerId': uid,
        'memberIds': [uid],
        'inviteCode': inviteCode,
        'createdAt': FieldValue.serverTimestamp(),
      });

      for (var i = 0; i < defaultTagNames.length; i++) {
        final tagRef = groupRef.collection('tags').doc();
        batch.set(tagRef, {
          'name': defaultTagNames[i],
          'createdAt': FieldValue.serverTimestamp(),
          'order': i + 1,
        });
      }

      // merge: true で users ドキュメント未存在時も作成する。
      batch.set(_userRef(uid), {
        'groupId': groupRef.id,
      }, SetOptions(merge: true));

      await batch.commit();
      return (groupId: groupRef.id, inviteCode: inviteCode);
    } catch (e) {
      throw toAppError(e);
    }
  }

  @override
  Future<bool> isGroupOwner(String uid) async {
    try {
      final snap = await _groups
          .where('ownerId', isEqualTo: uid)
          .limit(1)
          .get();
      return snap.docs.isNotEmpty;
    } catch (e) {
      throw toAppError(e);
    }
  }

  @override
  Future<Group?> getGroup(String groupId) async {
    try {
      final snap = await _groups.doc(groupId).get();
      if (!snap.exists) return null;
      return groupFromDoc(snap);
    } catch (e) {
      throw toAppError(e);
    }
  }

  @override
  Future<List<Group>> getGroupsByMemberId(String uid) async {
    try {
      final snap = await _groups.where('memberIds', arrayContains: uid).get();
      return snap.docs.map(groupFromDoc).toList();
    } catch (e) {
      throw toAppError(e);
    }
  }

  @override
  Future<void> updateGroupName(String groupId, String name) async {
    try {
      await _groups.doc(groupId).update({'name': name});
    } catch (e) {
      throw toAppError(e);
    }
  }

  @override
  Future<void> leaveGroup(String uid, String groupId) async {
    try {
      await _groups.doc(groupId).update({
        'memberIds': FieldValue.arrayRemove([uid]),
      });
      await _userRef(uid).update({'groupId': null});
    } catch (e) {
      throw toAppError(e);
    }
  }

  @override
  Future<void> disbandGroup(String uid, String groupId) async {
    try {
      final groupSnap = await _groups.doc(groupId).get();
      if (!groupSnap.exists) {
        throw const AppError(AppErrorCode.dataNotFound, 'Group not found');
      }

      final userSnap = await _userRef(uid).get();
      final currentUserGroupId = userSnap.exists
          ? (userSnap.data()?['groupId'] as String?)
          : null;

      final batch = _db.batch();
      // 別グループをアクティブにしている場合は維持し、誤リダイレクトを防ぐ。
      if (currentUserGroupId == groupId) {
        batch.update(_userRef(uid), {'groupId': null});
      }
      batch.delete(_groups.doc(groupId));
      await batch.commit();
    } catch (e) {
      throw toAppError(e);
    }
  }

  @override
  Future<Group?> getGroupByInviteCode(String inviteCode) async {
    try {
      final snap = await _groups
          .where('inviteCode', isEqualTo: inviteCode.toUpperCase())
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      return groupFromDoc(snap.docs.first);
    } catch (e) {
      throw toAppError(e);
    }
  }

  @override
  Future<String> joinGroup(String uid, String inviteCode) async {
    try {
      final group = await getGroupByInviteCode(inviteCode);
      if (group == null) {
        throw AppError(
          AppErrorCode.groupInvalidInviteCode,
          'Invalid invite code: $inviteCode',
        );
      }
      if (group.memberIds.contains(uid)) {
        throw AppError(
          AppErrorCode.groupAlreadyMember,
          'User $uid is already a member',
        );
      }

      final batch = _db.batch();
      batch.update(_groups.doc(group.id), {
        'memberIds': FieldValue.arrayUnion([uid]),
      });
      batch.update(_userRef(uid), {'groupId': group.id});
      await batch.commit();

      return group.id;
    } catch (e) {
      throw toAppError(e);
    }
  }

  @override
  Future<void> removeMember(String groupId, String targetUid) async {
    try {
      final groupSnap = await _groups.doc(groupId).get();
      if (!groupSnap.exists) {
        throw AppError(AppErrorCode.dataNotFound, 'Group $groupId not found');
      }
      final ownerId = groupSnap.data()?['ownerId'] as String?;
      if (targetUid == ownerId) {
        throw AppError(
          AppErrorCode.groupCannotRemoveOwner,
          'Cannot remove owner $targetUid',
        );
      }
      final batch = _db.batch();
      batch.update(_groups.doc(groupId), {
        'memberIds': FieldValue.arrayRemove([targetUid]),
      });
      batch.update(_userRef(targetUid), {'groupId': null});
      await batch.commit();
    } catch (e) {
      throw toAppError(e);
    }
  }

  @override
  Stream<Group?> watchGroup(String groupId) {
    return _groups.doc(groupId).snapshots().map((snap) {
      if (!snap.exists) return null;
      return groupFromDoc(snap);
    });
  }
}
