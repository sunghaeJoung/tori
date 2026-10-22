import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/expenses/ui/expense_form_screen.dart';
import '../features/invite/ui/invite_screen.dart';
import '../features/invite/ui/join_screen.dart';
import '../features/onboarding/ui/onboarding_screen.dart';
import '../features/settlement/ui/rate_screen.dart';
import '../features/trips/ui/create_trip_screen.dart';
import '../features/trips/ui/home_screen.dart';
import '../features/trips/ui/trip_screen.dart';
import '../shared/widgets/empty_state.dart';

/// 앱의 경로. 화면에서 이동할 때는 문자열 대신 이걸 쓴다.
abstract final class Routes {
  static const onboarding = '/onboarding';
  static const home = '/';
  static const newTrip = '/trips/new';
  static String trip(String tripId) => '/trips/$tripId';
  static String invite(String tripId) => '/trips/$tripId/invite';
  static String newExpense(String tripId) => '/trips/$tripId/expenses/new';
  static String expense(String tripId, String expenseId) =>
      '/trips/$tripId/expenses/$expenseId';
  static String settle(String tripId) => '/trips/$tripId/settle';
  static String join(String code) => '/join/$code';
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    // 닉네임이 있으면 홈으로 보내는 처리는 4단계에서 redirect로 넣는다.
    initialLocation: Routes.onboarding,
    routes: [
      GoRoute(
        path: Routes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: Routes.home,
        builder: (context, state) => const HomeScreen(),
      ),
      // '/trips/:tripId'보다 먼저 둬야 'new'가 tripId로 잡히지 않는다.
      GoRoute(
        path: Routes.newTrip,
        builder: (context, state) => const CreateTripScreen(),
      ),
      GoRoute(
        path: '/trips/:tripId',
        builder: (context, state) =>
            TripScreen(tripId: state.pathParameters['tripId']!),
        routes: [
          GoRoute(
            path: 'invite',
            builder: (context, state) =>
                InviteScreen(tripId: state.pathParameters['tripId']!),
          ),
          GoRoute(
            path: 'expenses/new',
            builder: (context, state) =>
                ExpenseFormScreen(tripId: state.pathParameters['tripId']!),
          ),
          GoRoute(
            path: 'expenses/:expenseId',
            builder: (context, state) => ExpenseFormScreen(
              tripId: state.pathParameters['tripId']!,
              expenseId: state.pathParameters['expenseId'],
            ),
          ),
          GoRoute(
            path: 'settle',
            builder: (context, state) =>
                RateScreen(tripId: state.pathParameters['tripId']!),
          ),
        ],
      ),
      GoRoute(
        path: '/join/:code',
        builder: (context, state) =>
            JoinScreen(code: state.pathParameters['code']!),
      ),
    ],
    errorBuilder: (context, state) => const _NotFoundScreen(),
  );
});

class _NotFoundScreen extends StatelessWidget {
  const _NotFoundScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: EmptyState(
        title: '페이지를 찾을 수 없어요',
        message: '주소를 다시 확인해주세요',
        action: FilledButton(
          onPressed: () => context.go(Routes.home),
          child: const Text('홈으로'),
        ),
      ),
    );
  }
}
