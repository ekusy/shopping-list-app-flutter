import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/group.dart';
import '../../domain/entities/item.dart';
import '../../domain/entities/tag.dart';
import '../../domain/entities/user_doc.dart';

/// Firestore の値を [DateTime] に変換する（[Timestamp] / [DateTime] / null に対応）。
DateTime? toDateTime(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}

/// `users/{uid}` ドキュメント → [UserDoc]。
UserDoc userDocFromData(Map<String, dynamic> data) {
  return UserDoc(
    displayName: (data['displayName'] as String?) ?? '',
    avatarUrl: (data['avatarUrl'] as String?) ?? '',
    groupId: data['groupId'] as String?,
    notificationsEnabled: (data['notificationsEnabled'] as bool?) ?? false,
    fcmToken: data['fcmToken'] as String?,
    createdAt: toDateTime(data['createdAt']),
  );
}

/// `groups/{groupId}` ドキュメント → [Group]。
Group groupFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data() ?? <String, dynamic>{};
  return Group(
    id: doc.id,
    name: (data['name'] as String?) ?? '',
    ownerId: (data['ownerId'] as String?) ?? '',
    memberIds: (data['memberIds'] as List<dynamic>?)?.cast<String>() ?? const [],
    inviteCode: (data['inviteCode'] as String?) ?? '',
    createdAt: toDateTime(data['createdAt']),
    plan: data['plan'] as String?,
  );
}

/// `groups/{groupId}/tags/{tagId}` ドキュメント → [Tag]。
Tag tagFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data() ?? <String, dynamic>{};
  return Tag(
    id: doc.id,
    name: (data['name'] as String?) ?? '',
    createdAt: toDateTime(data['createdAt']),
    order: (data['order'] as num?)?.toInt(),
  );
}

/// `groups/{groupId}/items/{itemId}` ドキュメント → [Item]。
/// [pendingWrite] は `metadata.hasPendingWrites` から付与する。
Item itemFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data() ?? <String, dynamic>{};
  return Item(
    id: doc.id,
    name: (data['name'] as String?) ?? '',
    category: (data['category'] as String?) ?? '',
    note: (data['note'] as String?) ?? '',
    imageUrl: (data['imageUrl'] as String?) ?? '',
    createdAt: toDateTime(data['createdAt']),
    addedBy: data['addedBy'] as String?,
    order: (data['order'] as num?)?.toInt(),
    status: ItemStatus.fromCode(data['status'] as String?),
    buyingBy: data['buyingBy'] as String?,
    isBought: data['isBought'] as bool?,
    buyerId: data['buyerId'] as String?,
    tagId: data['tagId'] as String?,
    pendingWrite: doc.metadata.hasPendingWrites,
  );
}
