import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'app/router.dart';
import 'app/theme.dart';
import 'core/supabase/supabase_client.dart';

Future<void> main() async {
  // 주소를 '/#/join/abc' 대신 '/join/abc'로 쓴다. 초대 링크를 깔끔하게 하기 위해.
  usePathUrlStrategy();
  WidgetsFlutterBinding.ensureInitialized();
  await initSupabase();

  // 로그인을 기다리지 않고 화면부터 띄운다. 로그인은 뒤에서 시작하고,
  // 데이터가 필요한 곳에서 authUserProvider를 기다린다.
  final container = ProviderContainer();
  container.read(authUserProvider);
  runApp(
    UncontrolledProviderScope(container: container, child: const ToriApp()),
  );
}

class ToriApp extends ConsumerWidget {
  const ToriApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: '토리',
      debugShowCheckedModeBanner: false,
      theme: toriTheme,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
