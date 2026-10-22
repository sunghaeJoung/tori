import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/router.dart';
import 'app/theme.dart';
import 'core/supabase/supabase_client.dart';

Future<void> main() async {
  // 주소를 '/#/join/abc' 대신 '/join/abc'로 쓴다. 초대 링크를 깔끔하게 하기 위해.
  usePathUrlStrategy();
  WidgetsFlutterBinding.ensureInitialized();
  await initSupabase();
  try {
    // 처음 한 번만 네트워크를 쓴다. 이후엔 브라우저에 저장된 세션을 쓴다.
    await ensureSignedIn(Supabase.instance.client);
  } catch (e) {
    // 네트워크가 안 돼도 앱은 띄운다. 저장할 때 다시 로그인을 시도한다.
    debugPrint('익명 로그인 실패: $e');
  }
  runApp(const ProviderScope(child: ToriApp()));
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
