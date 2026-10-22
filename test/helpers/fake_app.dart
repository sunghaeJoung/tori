import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tori/app/router.dart';
import 'package:tori/core/money/currency.dart';
import 'package:tori/core/supabase/supabase_client.dart';
import 'package:tori/features/onboarding/providers.dart';
import 'package:tori/features/trips/data/trips_repository.dart';
import 'package:tori/features/trips/providers.dart';
import 'package:tori/main.dart';

/// Supabase 없이 앱을 띄우기 위한 가짜들.

class FakeNickname extends NicknameNotifier {
  FakeNickname(this.initial);

  final String? initial;

  @override
  String? build() => initial;

  @override
  Future<void> save(String nickname) async => state = nickname.trim();
}

typedef CreatedTrip = ({
  String name,
  DateTime startDate,
  DateTime endDate,
  Currency currency,
  String myName,
  List<String> friendNames,
});

class FakeTripsRepository implements TripsRepository {
  FakeTripsRepository({List<TripSummary>? trips}) : trips = trips ?? [];

  final List<TripSummary> trips;
  final created = <CreatedTrip>[];

  /// 값이 있으면 모든 요청이 이 에러로 실패한다.
  Object? failWith;

  @override
  Future<List<TripSummary>> myTrips() async {
    if (failWith != null) throw failWith!;
    return trips;
  }

  @override
  Future<String> createTrip({
    required String name,
    required DateTime startDate,
    required DateTime endDate,
    required Currency currency,
    required String myName,
    required List<String> friendNames,
  }) async {
    if (failWith != null) throw failWith!;
    created.add((
      name: name,
      startDate: startDate,
      endDate: endDate,
      currency: currency,
      myName: myName,
      friendNames: List.of(friendNames),
    ));
    return 'new-trip';
  }
}

final fakeUser = User(
  id: 'user-1',
  appMetadata: const {},
  userMetadata: const {},
  aud: 'authenticated',
  createdAt: '2026-10-22T00:00:00Z',
  isAnonymous: true,
);

TripSummary sampleTrip({
  String id = 't1',
  String name = '상하이 우정여행',
  bool settled = false,
}) => TripSummary(
  id: id,
  name: name,
  startDate: DateTime(2026, 11, 6),
  endDate: DateTime(2026, 11, 9),
  currency: Currency.cny,
  memberCount: 4,
  settled: settled,
);

/// 앱을 띄우고, [location]이 있으면 그 주소로 이동한다.
/// 다른 가짜가 필요하면 [overrides]로 넘긴다.
Future<void> pumpApp(
  WidgetTester tester, {
  String? location,
  String? nickname = '민지',
  FakeTripsRepository? repository,
  List<Override> overrides = const [],
}) async {
  final repo = repository ?? FakeTripsRepository();
  final container = ProviderContainer(
    overrides: [
      nicknameProvider.overrideWith(() => FakeNickname(nickname)),
      authUserProvider.overrideWith((ref) => fakeUser),
      tripsRepositoryProvider.overrideWithValue(repo),
      ...overrides,
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const ToriApp()),
  );
  if (location != null) container.read(routerProvider).go(location);
  await tester.pumpAndSettle();
}

Finder appBarTitle(String title) =>
    find.descendant(of: find.byType(AppBar), matching: find.text(title));

Future<void> tapButton<T extends Widget>(
  WidgetTester tester,
  String label,
) async {
  await tester.tap(find.widgetWithText(T, label));
  await tester.pumpAndSettle();
}
