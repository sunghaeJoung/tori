import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase/supabase_client.dart';
import 'data/trips_repository.dart';
import 'ui/trip_draft.dart';

final tripsRepositoryProvider = Provider<TripsRepository>(
  (ref) => TripsRepository(ref.watch(supabaseProvider)),
);

/// 내 여행 목록. 로그인이 끝난 뒤에 불러온다.
final myTripsProvider = FutureProvider<List<TripSummary>>((ref) async {
  await ref.watch(authUserProvider.future);
  return ref.watch(tripsRepositoryProvider).myTrips();
});

/// 여행을 만들고 id를 돌려준다. 끝나면 홈 목록을 다시 불러온다.
Future<String> createTrip(
  WidgetRef ref,
  TripDraft draft, {
  required String myName,
}) async {
  await ref.read(authUserProvider.future);
  final id = await ref
      .read(tripsRepositoryProvider)
      .createTrip(
        name: draft.name.trim(),
        startDate: draft.startDate!,
        endDate: draft.endDate!,
        currency: draft.currency!,
        myName: myName,
        friendNames: draft.friends,
      );
  ref.invalidate(myTripsProvider);
  return id;
}
