import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase/supabase_client.dart';
import 'data/trips_repository.dart';

final tripsRepositoryProvider = Provider<TripsRepository>(
  (ref) => TripsRepository(ref.watch(supabaseProvider)),
);

/// 내 여행 목록. 로그인이 끝난 뒤에 불러온다.
final myTripsProvider = FutureProvider<List<TripSummary>>((ref) async {
  await ref.watch(authUserProvider.future);
  return ref.watch(tripsRepositoryProvider).myTrips();
});
