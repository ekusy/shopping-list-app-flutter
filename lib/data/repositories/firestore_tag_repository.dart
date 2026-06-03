import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/tag.dart';
import '../../domain/repositories/tag_repository.dart';
import '../firebase/firebase_error_converter.dart';
import '../firebase/firestore_mappers.dart';

/// Firestore を用いた [TagRepository] 実装。
class FirestoreTagRepository implements TagRepository {
  FirestoreTagRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _tagsCol(String groupId) =>
      _db.collection('groups').doc(groupId).collection('tags');

  CollectionReference<Map<String, dynamic>> _itemsCol(String groupId) =>
      _db.collection('groups').doc(groupId).collection('items');

  @override
  Future<Tag> addTag(String groupId, String name, int order) async {
    try {
      final ref = await _tagsCol(groupId).add({
        'name': name,
        'createdAt': FieldValue.serverTimestamp(),
        'order': order,
      });
      return Tag(
        id: ref.id,
        name: name,
        createdAt: DateTime.now(),
        order: order,
      );
    } catch (e) {
      throw toAppError(e);
    }
  }

  @override
  Future<void> updateTagName(String groupId, String tagId, String name) async {
    try {
      await _tagsCol(groupId).doc(tagId).update({'name': name});
    } catch (e) {
      throw toAppError(e);
    }
  }

  @override
  Future<void> deleteTagAndClearItems(String groupId, String tagId) async {
    try {
      final snapshot = await _itemsCol(
        groupId,
      ).where('tagId', isEqualTo: tagId).get();
      final batch = _db.batch();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {'tagId': FieldValue.delete()});
      }
      batch.delete(_tagsCol(groupId).doc(tagId));
      await batch.commit();
    } catch (e) {
      throw toAppError(e);
    }
  }

  @override
  Future<int> getTagsCount(String groupId) async {
    try {
      final snap = await _tagsCol(groupId).get();
      return snap.docs.length;
    } catch (e) {
      throw toAppError(e);
    }
  }

  @override
  Stream<List<Tag>> watchTags(String groupId) {
    return _tagsCol(groupId).snapshots().map((snapshot) {
      final tags = snapshot.docs.map(tagFromDoc).toList();
      // order 昇順 → createdAt 昇順でソート（order 未設定タグも落とさない）。
      tags.sort((a, b) {
        final aHasOrder = a.order != null;
        final bHasOrder = b.order != null;
        if (aHasOrder && bHasOrder) return a.order!.compareTo(b.order!);
        if (aHasOrder) return -1;
        if (bHasOrder) return 1;
        final aMs = a.createdAt?.millisecondsSinceEpoch ?? 0;
        final bMs = b.createdAt?.millisecondsSinceEpoch ?? 0;
        return aMs.compareTo(bMs);
      });
      return tags;
    });
  }
}
