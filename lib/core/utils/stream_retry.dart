import 'dart:async';

/// 初回イベントが [timeout] 以内に届かない場合に、元ストリームを最大 [maxRetries] 回
/// 再購読（再生成）するラッパ。
///
/// 背景 (#24): 実機 Web（CanvasKit / Firestore）で初回ログイン直後に張った最初の
/// `snapshots()` リスナーが、初回スナップショットを返さないまま待機し続けることがある。
/// リロードや画面遷移による「再購読」で復旧する症状が報告されており、本ラッパは
/// その再購読を自動化して緩和する。
///
/// - 初回イベント受信後は通常どおりすべてのイベント・エラー・完了を中継する。
/// - 健全時（初回イベントが [timeout] 未満で届く）は再購読は発生せず、挙動は素のストリームと同じ。
/// - エラーは「初回到達」とみなし再購読しない（無限リトライを避ける）。
///
/// [create] は購読のたびに新しいストリームを返すファクトリであること。
Stream<T> resubscribeIfNoFirstEvent<T>(
  Stream<T> Function() create, {
  Duration timeout = const Duration(seconds: 2),
  int maxRetries = 2,
}) {
  late final StreamController<T> controller;
  StreamSubscription<T>? sub;
  Timer? timer;
  var receivedFirst = false;
  var attempt = 0;

  void subscribe() {
    timer?.cancel();
    // 初回未受信かつリトライ上限未満なら、タイムアウトで再購読する。
    if (!receivedFirst && attempt < maxRetries) {
      timer = Timer(timeout, () {
        if (receivedFirst || controller.isClosed) return;
        attempt++;
        sub?.cancel();
        sub = null;
        subscribe();
      });
    }
    sub = create().listen(
      (event) {
        receivedFirst = true;
        timer?.cancel();
        timer = null;
        if (!controller.isClosed) controller.add(event);
      },
      onError: (Object e, StackTrace st) {
        // エラーは初回到達扱い（再購読しない）。
        receivedFirst = true;
        timer?.cancel();
        timer = null;
        if (!controller.isClosed) controller.addError(e, st);
      },
      onDone: () {
        if (!controller.isClosed) controller.close();
      },
    );
  }

  controller = StreamController<T>(
    onListen: subscribe,
    onCancel: () async {
      timer?.cancel();
      timer = null;
      await sub?.cancel();
      sub = null;
    },
  );

  return controller.stream;
}
