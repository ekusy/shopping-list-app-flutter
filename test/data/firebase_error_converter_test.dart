import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list_app/core/errors/app_error.dart';
import 'package:shopping_list_app/data/firebase/firebase_error_converter.dart';

void main() {
  group('toAppError', () {
    test('Firebase Auth コードをマッピングする', () {
      expect(
        toAppError(FirebaseAuthException(code: 'email-already-in-use')).code,
        AppErrorCode.authEmailAlreadyInUse,
      );
      expect(
        toAppError(FirebaseAuthException(code: 'weak-password')).code,
        AppErrorCode.authWeakPassword,
      );
    });

    test('user-not-found / wrong-password は invalid-credential に寄せる', () {
      expect(
        toAppError(FirebaseAuthException(code: 'user-not-found')).code,
        AppErrorCode.authInvalidCredential,
      );
      expect(
        toAppError(FirebaseAuthException(code: 'wrong-password')).code,
        AppErrorCode.authInvalidCredential,
      );
    });

    test('未知の auth コードは authUnknown', () {
      expect(
        toAppError(FirebaseAuthException(code: 'something-else')).code,
        AppErrorCode.authUnknown,
      );
    });

    test('Firestore コードをマッピングする', () {
      expect(
        toAppError(FirebaseException(
                plugin: 'cloud_firestore', code: 'permission-denied'))
            .code,
        AppErrorCode.dataPermissionDenied,
      );
      expect(
        toAppError(
                FirebaseException(plugin: 'cloud_firestore', code: 'not-found'))
            .code,
        AppErrorCode.dataNotFound,
      );
    });

    test('未知の Firestore コードは dataUnknown', () {
      expect(
        toAppError(FirebaseException(plugin: 'cloud_firestore', code: 'weird'))
            .code,
        AppErrorCode.dataUnknown,
      );
    });

    test('AppError はそのまま通す', () {
      const original = AppError(AppErrorCode.groupAlreadyMember, 'x');
      expect(identical(toAppError(original), original), isTrue);
    });

    test('一般例外は dataUnknown', () {
      expect(toAppError(Exception('boom')).code, AppErrorCode.dataUnknown);
    });
  });
}
