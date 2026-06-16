import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/suggestion.dart';
import '../../domain/repositories/suggestion_repository.dart';
import '../firebase/firebase_error_converter.dart';
import '../firebase/firestore_mappers.dart';

/// Firestore を用いた [SuggestionRepository] 実装。
///
/// `groups/{groupId}/suggestions` を `generatedAt` 降順 `limit(1)` で購読し、
/// 最新の提案ドキュメントをリアルタイムに返す。
class FirestoreSuggestionRepository implements SuggestionRepository {
  FirestoreSuggestionRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _suggestionsCol(String groupId) =>
      _db.collection('groups').doc(groupId).collection('suggestions');

  @override
  Stream<Suggestion?> watchLatestSuggestion(String groupId) {
    return _suggestionsCol(groupId)
        .orderBy('generatedAt', descending: true)
        .limit(1)
        .snapshots()
        .map((snap) {
          if (snap.docs.isEmpty) return null;
          return suggestionFromDoc(snap.docs.first);
        })
        .handleError((Object e) => throw toAppError(e));
  }
}
