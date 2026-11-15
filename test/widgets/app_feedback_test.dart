import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list_app/presentation/widgets/app_feedback.dart';

void main() {
  Widget buildHarness({required void Function(BuildContext) onPressed}) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => onPressed(context),
              child: const Text('trigger'),
            ),
          ),
        ),
      ),
    );
  }

  group('AppFeedback', () {
    testWidgets('showToast は画面上部に表示され、3 秒後に自動で閉じる', (tester) async {
      await tester.pumpWidget(
        buildHarness(
          onPressed: (ctx) =>
              AppFeedback.showToast(ctx, '追加しました', type: ToastType.success),
        ),
      );

      await tester.tap(find.text('trigger'));
      await tester.pump();

      final toastFinder = find.text('追加しました');
      expect(toastFinder, findsOneWidget);

      // 画面下部（入力欄エリア）ではなく画面上部に配置されていること
      final screenHeight =
          tester.view.physicalSize.height / tester.view.devicePixelRatio;
      final toastTopLeft = tester.getTopLeft(toastFinder);
      expect(toastTopLeft.dy, lessThan(screenHeight / 4));

      // 3 秒経過で自動的に閉じる
      await tester.pump(const Duration(seconds: 3));
      expect(toastFinder, findsNothing);
    });

    testWidgets('showToast はタップで即座に閉じられる', (tester) async {
      await tester.pumpWidget(
        buildHarness(onPressed: (ctx) => AppFeedback.showToast(ctx, '削除しました')),
      );

      await tester.tap(find.text('trigger'));
      await tester.pump();
      expect(find.text('削除しました'), findsOneWidget);

      await tester.tap(find.text('削除しました'));
      await tester.pump();
      expect(find.text('削除しました'), findsNothing);
    });

    testWidgets('showLoading は hide が呼ばれるまで表示され、hide で閉じる', (tester) async {
      late BuildContext capturedContext;
      await tester.pumpWidget(
        buildHarness(
          onPressed: (ctx) {
            capturedContext = ctx;
            AppFeedback.showLoading(ctx, '追加中...');
          },
        ),
      );

      await tester.tap(find.text('trigger'));
      await tester.pump();

      expect(find.text('追加中...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      AppFeedback.hide(capturedContext);
      await tester.pump();
      expect(find.text('追加中...'), findsNothing);
    });
  });
}
