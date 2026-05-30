import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// 確認ダイアログを表示し、ユーザーの選択を返す（旧 `platformAlert.confirmAsync`）。
///
/// @param message 本文
/// @param title 任意のタイトル
/// @param confirmLabel 確認ボタンのラベル（省略時は `common.ok`）
/// @returns 確認したら true、キャンセル / 閉じたら false
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String message,
  String? title,
  String? confirmLabel,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: title != null ? Text(title) : null,
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text('common.cancel'.tr()),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(confirmLabel ?? 'common.ok'.tr()),
        ),
      ],
    ),
  );
  return result ?? false;
}
