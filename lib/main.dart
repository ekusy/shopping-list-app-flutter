import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'presentation/router/app_router.dart';

// --dart-define=USE_EMULATOR=true で Firebase Emulator に接続する。
// 詳細: docs/DEBUGGING.md の「Firebase Emulator Suite」を参照。
const _useEmulator = bool.fromEnvironment('USE_EMULATOR');
const _emulatorHost = String.fromEnvironment(
  'EMULATOR_HOST',
  defaultValue: 'localhost',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    if (_useEmulator) {
      FirebaseFirestore.instance.useFirestoreEmulator(_emulatorHost, 8080);
      await FirebaseAuth.instance.useAuthEmulator(_emulatorHost, 9099);
      debugPrint('Firebase Emulator connected: $_emulatorHost');
    }
  } catch (e) {
    // Firebase 未設定（テンプレート値のまま）でも UI はビルド・起動できるようにする。
    debugPrint('Firebase initialization failed: $e');
  }

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('ja'), Locale('en')],
      path: 'assets/translations',
      fallbackLocale: const Locale('ja'),
      useFallbackTranslations: true,
      child: const ProviderScope(child: ShoppingListApp()),
    ),
  );
}

/// アプリのルートウィジェット。
class ShoppingListApp extends ConsumerWidget {
  const ShoppingListApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Shopping List',
      theme: buildAppTheme(),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
    );
  }
}
