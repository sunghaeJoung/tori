import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'app/router.dart';
import 'app/theme.dart';

void main() {
  // 주소를 '/#/join/abc' 대신 '/join/abc'로 쓴다. 초대 링크를 깔끔하게 하기 위해.
  usePathUrlStrategy();
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
