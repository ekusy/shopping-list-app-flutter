// ⚠️ テンプレート: 実際の Firebase 設定値に置き換えてください。
//
// FlutterFire CLI で自動生成するのが推奨です:
//   dart pub global activate flutterfire_cli
//   flutterfire configure
// これにより本ファイルが実際のプロジェクト値で上書きされます。
//
// 下記のプレースホルダのままでもビルドは通りますが、実行時に Firebase へは接続できません。
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// プラットフォームごとの Firebase 設定を提供する。
class DefaultFirebaseOptions {
  DefaultFirebaseOptions._();

  /// 現在のプラットフォームに対応する [FirebaseOptions] を返す。
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for this platform. '
          'Run `flutterfire configure` to generate them.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDtUI6cbIH3oGb9MUh9_li4NKRkn78JDeU',
    appId: '1:570396817942:web:a270ab1c582f5f6b075337',
    messagingSenderId: '570396817942',
    projectId: 'household-shopping-list-f7c12',
    authDomain: 'household-shopping-list-f7c12.firebaseapp.com',
    storageBucket: 'household-shopping-list-f7c12.firebasestorage.app',
    measurementId: 'G-TKWJ4302MT',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAcaVKAjZjT9yM5rXy7jO6inP85eVC-P7k',
    appId: '1:570396817942:android:eed6c7241c3f95f2075337',
    messagingSenderId: '570396817942',
    projectId: 'household-shopping-list-f7c12',
    storageBucket: 'household-shopping-list-f7c12.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyB2CXxZwk5Q_7fythbkUVA-1KMAqqqjjho',
    appId: '1:570396817942:ios:f570b65b66e0bb1d075337',
    messagingSenderId: '570396817942',
    projectId: 'household-shopping-list-f7c12',
    storageBucket: 'household-shopping-list-f7c12.firebasestorage.app',
    iosClientId: '570396817942-tmrg96k4u0ecc5gucr6tlhoqj5bvb5lc.apps.googleusercontent.com',
    iosBundleId: 'com.ekusy.shoppingListApp',
  );

}