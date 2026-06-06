import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list_app/core/utils/stream_retry.dart';

void main() {
  test('初回イベントが即座に来る場合は再購読せず値を中継する', () async {
    var calls = 0;
    final wrapped = resubscribeIfNoFirstEvent<int>(() {
      calls++;
      return Stream.value(7);
    }, timeout: const Duration(milliseconds: 50));

    expect(await wrapped.first, 7);
    // タイムアウト経過後も再購読されないこと。
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(calls, 1);
  });

  test('初回イベントが来ない場合はタイムアウトで再購読して復旧する', () async {
    var calls = 0;
    final never = StreamController<int>(); // emit しない
    addTearDown(never.close);

    final wrapped = resubscribeIfNoFirstEvent<int>(
      () {
        calls++;
        // 1回目は永遠に待機、2回目以降は即 emit。
        return calls == 1 ? never.stream : Stream.value(42);
      },
      timeout: const Duration(milliseconds: 30),
      maxRetries: 2,
    );

    expect(await wrapped.first, 42);
    expect(calls, greaterThanOrEqualTo(2));
  });

  test('初回受信後は後続イベントも中継する', () async {
    final ctrl = StreamController<int>();
    addTearDown(ctrl.close);
    final wrapped = resubscribeIfNoFirstEvent<int>(
      () => ctrl.stream,
      timeout: const Duration(milliseconds: 50),
    );

    final received = <int>[];
    final sub = wrapped.listen(received.add);
    addTearDown(sub.cancel);

    ctrl.add(1);
    ctrl.add(2);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(received, [1, 2]);
  });

  test('エラーは再購読せずそのまま伝播する', () async {
    var calls = 0;
    final wrapped = resubscribeIfNoFirstEvent<int>(() {
      calls++;
      return Stream<int>.error(StateError('boom'));
    }, timeout: const Duration(milliseconds: 30));

    await expectLater(wrapped.first, throwsStateError);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(calls, 1);
  });
}
