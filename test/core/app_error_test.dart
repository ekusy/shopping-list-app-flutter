import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list_app/core/errors/app_error.dart';

void main() {
  group('AppErrorCode', () {
    test('元実装と互換の文字列コードを保持する', () {
      expect(
        AppErrorCode.authInvalidCredential.code,
        'auth/invalid-credential',
      );
      expect(AppErrorCode.dataPermissionDenied.code, 'data/permission-denied');
      expect(
        AppErrorCode.groupOwnerCannotLeave.code,
        'group/owner-cannot-leave',
      );
      expect(AppErrorCode.dataTagLimitExceeded.code, 'data/tag-limit-exceeded');
    });
  });

  group('AppError', () {
    test('code / message / cause を保持する', () {
      final cause = Exception('boom');
      final err = AppError(AppErrorCode.dataUnknown, 'failed', cause);
      expect(err.code, AppErrorCode.dataUnknown);
      expect(err.message, 'failed');
      expect(err.cause, cause);
      expect(err.toString(), contains('data/unknown'));
    });
  });
}
