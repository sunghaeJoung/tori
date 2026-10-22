import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// `--dart-define-from-file=env/dev.json`으로 주입하는 Supabase 설정.
///
/// 웹 번들에 들어가므로 공개용(publishable/anon) 키만 넣는다.
abstract final class SupabaseEnv {
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );
}

Future<void> initSupabase() async {
  if (SupabaseEnv.url.isEmpty || SupabaseEnv.publishableKey.isEmpty) {
    throw StateError(
      'Supabase 설정이 없다. '
      'flutter run -d chrome --dart-define-from-file=env/dev.json 으로 실행할 것',
    );
  }
  await Supabase.initialize(
    url: SupabaseEnv.url,
    publishableKey: SupabaseEnv.publishableKey,
  );
}

final supabaseProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

/// 로그인한 사용자. 세션이 없으면 익명으로 로그인한다.
///
/// 익명 세션은 브라우저에 저장되므로 같은 브라우저에서는 계속 같은 사용자다.
Future<User> ensureSignedIn(SupabaseClient client) async {
  final user = client.auth.currentUser;
  if (user != null) return user;
  final response = await client.auth.signInAnonymously();
  return response.user!;
}
