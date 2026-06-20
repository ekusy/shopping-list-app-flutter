import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/favorite_item.dart';
import '../../domain/repositories/favorite_item_repository.dart';
import '../firebase/firebase_error_converter.dart';
import '../firebase/firestore_mappers.dart';

/// Firestore を用いた [FavoriteItemRepository] 実装。
class FirestoreFavoriteItemRepository implements FavoriteItemRepository {
  FirestoreFavoriteItemRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _favoritesCol(String groupId) =>
      _db.collection('groups').doc(groupId).collection('favoriteItems');

  @override
  Stream<List<FavoriteItem>> watchFavorites(String groupId) {
    return _favoritesCol(groupId).snapshots().map((snapshot) {
      final items = snapshot.docs.map(favoriteItemFromDoc).toList();
      // order 昇順でソート。
      items.sort((a, b) => a.order.compareTo(b.order));
      return items;
    });
  }

  @override
  Future<String> addFavorite(
    String groupId,
    FavoriteItem draft,
    int order,
  ) async {
    try {
      final ref = await _favoritesCol(groupId).add({
        'name': draft.name,
        'note': draft.note,
        'imageUrl': draft.imageUrl,
        'order': order,
        'createdAt': FieldValue.serverTimestamp(),
        'addedBy': draft.addedBy,
        if (draft.tagId != null) 'tagId': draft.tagId,
      });
      return ref.id;
    } catch (e) {
      throw toAppError(e);
    }
  }

  @override
  Future<void> updateFavorite(
    String groupId,
    String id, {
    String? name,
    String? Function()? tagId,
    String? note,
    String? imageUrl,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (name != null) updates['name'] = name;
      if (note != null) updates['note'] = note;
      if (imageUrl != null) updates['imageUrl'] = imageUrl;
      // tagId が指定されている場合のみ更新する。
      // null を返す関数が渡された場合はタグ解除（フィールド削除）、
      // 値を返す関数の場合はその値を設定する。
      if (tagId != null) {
        final resolvedTagId = tagId();
        updates['tagId'] = resolvedTagId ?? FieldValue.delete();
      }
      if (updates.isNotEmpty) {
        await _favoritesCol(groupId).doc(id).update(updates);
      }
    } catch (e) {
      throw toAppError(e);
    }
  }

  @override
  Future<void> deleteFavorite(String groupId, String id) async {
    try {
      await _favoritesCol(groupId).doc(id).delete();
    } catch (e) {
      throw toAppError(e);
    }
  }
}
