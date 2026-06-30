import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list_app/presentation/providers/group_providers.dart';
import 'package:shopping_list_app/presentation/providers/selection_controller.dart';

/// グループ ID をテストから差し替えるための制御用 provider。
class _GroupIdNotifier extends Notifier<String?> {
  @override
  String? build() => 'g1';
  void set(String? value) => state = value;
}

final _testGroupId = NotifierProvider<_GroupIdNotifier, String?>(
  _GroupIdNotifier.new,
);

ProviderContainer _makeContainer() {
  final container = ProviderContainer(
    overrides: [
      // activeGroupIdProvider を制御用 provider 由来にして、グループ切替を再現する。
      activeGroupIdProvider.overrideWith((ref) => ref.watch(_testGroupId)),
    ],
  );
  // ライフサイクルを開始して selection を維持する。
  container.listen(selectionControllerProvider, (_, _) {});
  return container;
}

void main() {
  test('toggle で選択を追加・削除し、active / count に反映される', () {
    final container = _makeContainer();
    addTearDown(container.dispose);
    final notifier = container.read(selectionControllerProvider.notifier);

    expect(container.read(selectionActiveProvider), isFalse);
    expect(container.read(selectionCountProvider), 0);

    notifier.toggle('a');
    expect(container.read(selectionControllerProvider).ids, {'a'});
    expect(container.read(selectionActiveProvider), isTrue);
    expect(container.read(selectionCountProvider), 1);

    notifier.toggle('b');
    expect(container.read(selectionCountProvider), 2);

    notifier.toggle('a'); // 解除
    expect(container.read(selectionControllerProvider).ids, {'b'});
  });

  test('isItemSelectedProvider が ID ごとの選択状態を返す', () {
    final container = _makeContainer();
    addTearDown(container.dispose);
    container.read(selectionControllerProvider.notifier).toggle('a');

    expect(container.read(isItemSelectedProvider('a')), isTrue);
    expect(container.read(isItemSelectedProvider('b')), isFalse);
  });

  test('selectAll で全 ID を選択、clear で全解除する', () {
    final container = _makeContainer();
    addTearDown(container.dispose);
    final notifier = container.read(selectionControllerProvider.notifier);

    notifier.selectAll(['a', 'b', 'c']);
    expect(container.read(selectionCountProvider), 3);

    notifier.clear();
    expect(container.read(selectionActiveProvider), isFalse);
    expect(container.read(selectionControllerProvider).ids, isEmpty);
  });

  test('アクティブグループが変わると選択をリセットする', () async {
    final container = _makeContainer();
    addTearDown(container.dispose);
    container.read(selectionControllerProvider.notifier).toggle('a');
    expect(container.read(selectionControllerProvider).ids, {'a'});

    // グループ切替 → build 再実行で初期化される。
    container.read(_testGroupId.notifier).set('g2');
    await Future<void>.delayed(Duration.zero);

    expect(container.read(selectionControllerProvider).ids, isEmpty);
    expect(container.read(selectionActiveProvider), isFalse);
  });
}
