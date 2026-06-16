import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list_app/data/firebase/firestore_mappers.dart';
import 'package:shopping_list_app/domain/entities/suggestion.dart';

const _groupId = 'g1';
const _weekId = '2026-W24';

Future<DocumentSnapshot<Map<String, dynamic>>> _putDoc(
  FakeFirebaseFirestore db,
  Map<String, dynamic> data,
) async {
  final ref = db
      .collection('groups')
      .doc(_groupId)
      .collection('suggestions')
      .doc(_weekId);
  await ref.set(data);
  return ref.get();
}

void main() {
  late FakeFirebaseFirestore db;

  setUp(() => db = FakeFirebaseFirestore());

  test('ready ドキュメントを正しくパースする', () async {
    final now = Timestamp.now();
    final doc = await _putDoc(db, {
      'generatedAt': now,
      'status': 'ready',
      'forgottenItems': [
        {'name': '牛乳', 'reason': '先週買い忘れた', 'confidence': 'high'},
        {'name': 'パン', 'reason': '2週連続で欠品', 'confidence': 'medium'},
      ],
      'recommendedItems': [
        {'name': '卵', 'reason': '毎週購入している'},
      ],
    });

    final suggestion = suggestionFromDoc(doc);

    expect(suggestion.id, _weekId);
    expect(
      suggestion.generatedAt.millisecondsSinceEpoch,
      closeTo(now.toDate().millisecondsSinceEpoch, 1000),
    );
    expect(suggestion.status, SuggestionStatus.ready);
    expect(suggestion.forgottenItems.length, 2);
    expect(suggestion.forgottenItems[0].name, '牛乳');
    expect(suggestion.forgottenItems[0].confidence, SuggestionConfidence.high);
    expect(
      suggestion.forgottenItems[1].confidence,
      SuggestionConfidence.medium,
    );
    expect(suggestion.recommendedItems.length, 1);
    expect(suggestion.recommendedItems[0].name, '卵');
  });

  test('empty ドキュメント（空リスト）を正しくパースする', () async {
    final doc = await _putDoc(db, {
      'generatedAt': Timestamp.now(),
      'status': 'empty',
      'forgottenItems': [],
      'recommendedItems': [],
    });

    final suggestion = suggestionFromDoc(doc);

    expect(suggestion.status, SuggestionStatus.empty);
    expect(suggestion.forgottenItems, isEmpty);
    expect(suggestion.recommendedItems, isEmpty);
  });

  test('未知の confidence は low にフォールバックする', () async {
    final doc = await _putDoc(db, {
      'generatedAt': Timestamp.now(),
      'status': 'ready',
      'forgottenItems': [
        {'name': 'テスト', 'reason': '理由', 'confidence': 'ultra_high'},
      ],
      'recommendedItems': [],
    });

    final suggestion = suggestionFromDoc(doc);
    expect(suggestion.forgottenItems[0].confidence, SuggestionConfidence.low);
  });

  test('未知の status は empty にフォールバックする', () async {
    final doc = await _putDoc(db, {
      'generatedAt': Timestamp.now(),
      'status': 'unknown_value',
      'forgottenItems': [],
      'recommendedItems': [],
    });

    final suggestion = suggestionFromDoc(doc);
    expect(suggestion.status, SuggestionStatus.empty);
  });

  test('フィールド欠損（null）でもクラッシュしない', () async {
    final doc = await _putDoc(db, {
      'generatedAt': Timestamp.now(),
      // status フィールドなし
      // forgottenItems フィールドなし
      // recommendedItems フィールドなし
    });

    final suggestion = suggestionFromDoc(doc);
    expect(suggestion.status, SuggestionStatus.empty);
    expect(suggestion.forgottenItems, isEmpty);
    expect(suggestion.recommendedItems, isEmpty);
  });
}
