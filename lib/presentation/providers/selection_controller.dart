import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'group_providers.dart';

/// 複数選択モードの状態（選択中のアイテム ID 集合）。
///
/// `active`（選択モードか）は `ids.isNotEmpty` から導出する。将来、一括操作の種別
/// （削除・購入済みトグル等）を増やす場合は、この値オブジェクトにフィールドを足して
/// 吸収する（呼び出し側の API を変えずに拡張できる）。
class SelectionState {
  const SelectionState({this.ids = const {}});

  final Set<String> ids;

  bool get active => ids.isNotEmpty;

  SelectionState copyWith({Set<String>? ids}) =>
      SelectionState(ids: ids ?? this.ids);
}

/// 選択状態を保持・操作するコントローラ。
///
/// アクティブグループが変わると選択をリセットする（`build` で `activeGroupIdProvider`
/// を監視し、変化時に再構築 = 初期状態に戻す）。グループ間で選択 ID を持ち越さない。
class SelectionController extends Notifier<SelectionState> {
  @override
  SelectionState build() {
    // グループ切替で選択をリセットする（依存変化で build が再実行され初期化される）。
    ref.watch(activeGroupIdProvider);
    return const SelectionState();
  }

  /// 指定 ID の選択をトグルする。
  void toggle(String id) {
    final next = {...state.ids};
    if (!next.remove(id)) next.add(id);
    state = SelectionState(ids: next);
  }

  /// 指定 ID 群をすべて選択状態にする。
  void selectAll(Iterable<String> ids) {
    state = SelectionState(ids: {...ids});
  }

  /// 選択をすべて解除する（選択モード終了）。
  void clear() {
    state = const SelectionState();
  }
}

final selectionControllerProvider =
    NotifierProvider<SelectionController, SelectionState>(
      SelectionController.new,
    );

/// 選択モードかどうか（1 件以上選択されている）。
final selectionActiveProvider = Provider<bool>(
  (ref) => ref.watch(selectionControllerProvider.select((s) => s.active)),
);

/// 選択件数。
final selectionCountProvider = Provider<int>(
  (ref) => ref.watch(selectionControllerProvider.select((s) => s.ids.length)),
);

/// 指定アイテムが選択中かどうか（行単位の部分再ビルドのための family）。
final isItemSelectedProvider = Provider.family<bool, String>(
  (ref, id) =>
      ref.watch(selectionControllerProvider.select((s) => s.ids.contains(id))),
);
