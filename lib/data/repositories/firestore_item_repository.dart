import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/item.dart';
import '../../domain/repositories/item_repository.dart';
import '../firebase/firebase_error_converter.dart';
import '../firebase/firestore_mappers.dart';

/// Firestore を用いた [ItemRepository] 実装。
class FirestoreItemRepository implements ItemRepository {
  FirestoreItemRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _itemsCol(String groupId) =>
      _db.collection('groups').doc(groupId).collection('items');

  @override
  Future<String> addItem(String groupId, Item draft, int order) async {
    try {
      final ref = await _itemsCol(groupId).add({
        'name': draft.name,
        'category': draft.category,
        'note': draft.note,
        'imageUrl': draft.imageUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'order': order,
        'status': (draft.status ?? ItemStatus.active).code,
        'buyingBy': draft.buyingBy,
        'addedBy': ?draft.addedBy,
        'tagId': ?draft.tagId,
      });
      return ref.id;
    } catch (e) {
      throw toAppError(e);
    }
  }

  @override
  Future<void> setVolunteer(String groupId, String itemId, String? uid) async {
    try {
      // uid が null の場合は buyingBy: null（フィールドを残して値を空にする）。
      await _itemsCol(groupId).doc(itemId).update({'buyingBy': uid});
    } catch (e) {
      throw toAppError(e);
    }
  }

  @override
  Future<void> setPurchased(
    String groupId,
    String itemId,
    bool purchased,
  ) async {
    try {
      await _itemsCol(groupId).doc(itemId).update({
        'status': purchased ? ItemStatus.purchased.code : ItemStatus.active.code,
      });
    } catch (e) {
      throw toAppError(e);
    }
  }

  @override
  Future<void> updateItemDetails(
    String groupId,
    String itemId, {
    required String name,
    String? tagId,
    required String note,
    required String imageUrl,
  }) async {
    try {
      await _itemsCol(groupId).doc(itemId).update({
        'name': name,
        'note': note,
        'imageUrl': imageUrl,
        // tagId が null の場合はフィールド自体を削除する（タグ解除）。
        'tagId': tagId ?? FieldValue.delete(),
      });
    } catch (e) {
      throw toAppError(e);
    }
  }

  @override
  Future<void> deleteItem(String groupId, String itemId) async {
    try {
      await _itemsCol(groupId).doc(itemId).delete();
    } catch (e) {
      throw toAppError(e);
    }
  }

  @override
  Future<void> deletePurchasedItems(String groupId) async {
    try {
      final snapshot = await _itemsCol(groupId)
          .where('status', isEqualTo: ItemStatus.purchased.code)
          .get();
      if (snapshot.docs.isEmpty) return;
      final batch = _db.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      throw toAppError(e);
    }
  }

  @override
  Future<void> deleteItemsByTag(String groupId, String tagId) async {
    try {
      final snapshot =
          await _itemsCol(groupId).where('tagId', isEqualTo: tagId).get();
      if (snapshot.docs.isEmpty) return;
      final batch = _db.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      throw toAppError(e);
    }
  }

  @override
  Future<void> batchUpdateTag(
    String groupId,
    List<String> itemIds,
    String? tagId,
  ) async {
    try {
      final col = _itemsCol(groupId);
      final batch = _db.batch();
      for (final id in itemIds) {
        batch.update(col.doc(id), {'tagId': tagId});
      }
      await batch.commit();
    } catch (e) {
      throw toAppError(e);
    }
  }

  @override
  Stream<List<Item>> watchItems(String groupId) {
    return _itemsCol(groupId)
        .snapshots(includeMetadataChanges: true)
        .map((snapshot) {
      final items = snapshot.docs.map(itemFromDoc).toList();
      // order フィールド優先で昇順、未設定時は createdAt の降順（新しいものが上）。
      items.sort((a, b) {
        final aHasOrder = a.order != null;
        final bHasOrder = b.order != null;
        if (aHasOrder && bHasOrder) return a.order!.compareTo(b.order!);
        if (aHasOrder) return -1;
        if (bHasOrder) return 1;
        final aMs = a.createdAt?.millisecondsSinceEpoch ?? 0;
        final bMs = b.createdAt?.millisecondsSinceEpoch ?? 0;
        return bMs.compareTo(aMs);
      });
      return items;
    });
  }
}
