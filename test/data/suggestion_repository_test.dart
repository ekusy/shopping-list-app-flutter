import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list_app/data/repositories/firestore_suggestion_repository.dart';
import 'package:shopping_list_app/domain/entities/suggestion.dart';

const _groupId = 'g1';

Map<String, dynamic> _suggestionData({
  required String weekId,
  required String status,
  DateTime? generatedAt,
}) => {
  'generatedAt': Timestamp.fromDate(generatedAt ?? DateTime.now()),
  'status': status,
  'forgottenItems': [
    {'name': '牛乳', 'reason': '先週忘れた', 'confidence': 'high'},
  ],
  'recommendedItems': [
    {'name': '卵', 'reason': '毎週購入'},
  ],
};

void main() {
  late FakeFirebaseFirestore db;
  late FirestoreSuggestionRepository repo;

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = FirestoreSuggestionRepository(db);
  });

  Future<void> putSuggestion(String weekId, Map<String, dynamic> data) => db
      .collection('groups')
      .doc(_groupId)
      .collection('suggestions')
      .doc(weekId)
      .set(data);

  test('ドキュメントがない場合は null を返す', () async {
    final result = await repo.watchLatestSuggestion(_groupId).first;
    expect(result, isNull);
  });

  test('最新の提案（generatedAt 降順 1 件）を返す', () async {
    final older = DateTime(2026, 6, 7);
    final newer = DateTime(2026, 6, 14);

    await putSuggestion(
      '2026-W23',
      _suggestionData(weekId: '2026-W23', status: 'ready', generatedAt: older),
    );
    await putSuggestion(
      '2026-W24',
      _suggestionData(weekId: '2026-W24', status: 'ready', generatedAt: newer),
    );

    final result = await repo.watchLatestSuggestion(_groupId).first;
    expect(result, isNotNull);
    expect(result!.id, '2026-W24');
    expect(result.status, SuggestionStatus.ready);
    expect(result.forgottenItems.length, 1);
    expect(result.forgottenItems.first.name, '牛乳');
    expect(result.recommendedItems.length, 1);
  });

  test('status: empty のドキュメントも返す', () async {
    await putSuggestion(
      '2026-W24',
      _suggestionData(weekId: '2026-W24', status: 'empty'),
    );

    final result = await repo.watchLatestSuggestion(_groupId).first;
    expect(result, isNotNull);
    expect(result!.status, SuggestionStatus.empty);
  });
}
