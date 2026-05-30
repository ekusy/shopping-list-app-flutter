import 'package:easy_localization/easy_localization.dart';

import '../../core/errors/app_error.dart';

/// 認証エラーをログイン画面向けの i18n メッセージに変換する（旧 Login のエラー分岐）。
String loginErrorMessage(Object e) {
  if (e is AppError) {
    switch (e.code) {
      case AppErrorCode.authInvalidCredential:
        return 'auth.error.invalid_credential'.tr();
      case AppErrorCode.authTooManyRequests:
        return 'auth.error.too_many_requests'.tr();
      default:
        return 'auth.error.login_failed'.tr();
    }
  }
  return 'auth.error.login_failed'.tr();
}

/// 認証エラーをサインアップ画面向けの i18n メッセージに変換する（旧 Signup のエラー分岐）。
String signupErrorMessage(Object e) {
  if (e is AppError) {
    switch (e.code) {
      case AppErrorCode.authEmailAlreadyInUse:
        return 'auth.error.email_already_in_use'.tr();
      case AppErrorCode.authWeakPassword:
        return 'auth.error.weak_password'.tr();
      case AppErrorCode.authInvalidEmail:
        return 'auth.error.invalid_email'.tr();
      default:
        return 'auth.error.signup_failed'.tr();
    }
  }
  return 'auth.error.signup_failed'.tr();
}
