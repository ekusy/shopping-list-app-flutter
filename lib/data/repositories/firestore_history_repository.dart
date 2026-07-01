import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/purchase_history_entry.dart';
import '../../domain/repositories/history_repository.dart';
import '../firebase/firebase_error_converter.dart';
import '../firebase/firestore_mappers.dart';

/// Firestore を用いた [HistoryRepository] 実装。
///
/// `groups/{groupId}/itemHistory` を `type == 'purchased'` で絞り、`occurredAt` 降順で
/// ページング取得する。複合インデックス `(type ASC, occurredAt DESC)` が必要
/// （`firestore.indexes.json`）。
class FirestoreHistoryRepository implements HistoryRepository {
  FirestoreHistoryRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _historyCol(String groupId) =>
      _db.collection('groups').doc(groupId).collection('itemHistory');

  @override
  Future<List<PurchaseHistoryEntry>> fetchPurchases(
    String groupId, {
    required int limit,
    DateTime? before,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _historyCol(groupId)
          .where('type', isEqualTo: 'purchased')
          .orderBy('occurredAt', descending: true);
      if (before != null) {
        // カーソル: 直前ページ末尾の occurredAt より前から取得する。
        query = query.startAfter([Timestamp.fromDate(before)]);
      }
      final snap = await query.limit(limit).get();
      return snap.docs.map(purchaseHistoryEntryFromDoc).toList();
    } catch (e) {
      throw toAppError(e);
    }
  }
}
