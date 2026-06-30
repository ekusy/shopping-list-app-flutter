import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/favorite_item.dart';
import '../../domain/entities/group.dart';
import '../../domain/entities/item.dart';
import '../../domain/entities/purchase_history_entry.dart';
import '../../domain/entities/suggestion.dart';
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
    memberIds:
        (data['memberIds'] as List<dynamic>?)?.cast<String>() ?? const [],
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

/// `groups/{groupId}/favoriteItems/{favoriteId}` ドキュメント → [FavoriteItem]。
FavoriteItem favoriteItemFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data() ?? <String, dynamic>{};
  return FavoriteItem(
    id: doc.id,
    name: (data['name'] as String?) ?? '',
    tagId: data['tagId'] as String?,
    note: (data['note'] as String?) ?? '',
    imageUrl: (data['imageUrl'] as String?) ?? '',
    order: (data['order'] as num?)?.toInt() ?? 0,
    createdAt: toDateTime(data['createdAt']),
    addedBy: (data['addedBy'] as String?) ?? '',
  );
}

/// `groups/{groupId}/itemHistory/{eventId}` ドキュメント → [PurchaseHistoryEntry]。
///
/// Cloud Functions（`functions/src/lib/history.ts`）が書き込むフィールド名に合わせる
/// （`itemId` / `name` / `tagId` / `purchasedBy` / `occurredAt`）。`type == 'purchased'`
/// のドキュメントのみを対象とする想定。
PurchaseHistoryEntry purchaseHistoryEntryFromDoc(
  DocumentSnapshot<Map<String, dynamic>> doc,
) {
  final data = doc.data() ?? <String, dynamic>{};
  return PurchaseHistoryEntry(
    id: doc.id,
    itemId: (data['itemId'] as String?) ?? '',
    name: (data['name'] as String?) ?? '',
    tagId: data['tagId'] as String?,
    purchasedBy: data['purchasedBy'] as String?,
    occurredAt:
        toDateTime(data['occurredAt']) ??
        DateTime.fromMillisecondsSinceEpoch(0),
  );
}

/// `groups/{groupId}/suggestions/{weekId}` ドキュメント → [Suggestion]。
///
/// #40 が書き込むフィールド名と完全一致させる（`generatedAt` / `status` /
/// `forgottenItems` / `recommendedItems`）。
/// - `forgottenItems[].confidence` は [SuggestionConfidence.fromCode] で解決。
/// - `status` は [SuggestionStatus.fromCode] で解決。
Suggestion suggestionFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data() ?? <String, dynamic>{};

  final rawForgotten = (data['forgottenItems'] as List<dynamic>?) ?? const [];
  final forgottenItems = rawForgotten.map((e) {
    final m = e as Map<String, dynamic>;
    return ForgottenItem(
      name: (m['name'] as String?) ?? '',
      reason: (m['reason'] as String?) ?? '',
      confidence: SuggestionConfidence.fromCode(m['confidence'] as String?),
    );
  }).toList();

  final rawRecommended =
      (data['recommendedItems'] as List<dynamic>?) ?? const [];
  final recommendedItems = rawRecommended.map((e) {
    final m = e as Map<String, dynamic>;
    return RecommendedItem(
      name: (m['name'] as String?) ?? '',
      reason: (m['reason'] as String?) ?? '',
    );
  }).toList();

  return Suggestion(
    id: doc.id,
    generatedAt:
        toDateTime(data['generatedAt']) ??
        DateTime.fromMillisecondsSinceEpoch(0),
    status: SuggestionStatus.fromCode(data['status'] as String?),
    forgottenItems: forgottenItems,
    recommendedItems: recommendedItems,
  );
}
