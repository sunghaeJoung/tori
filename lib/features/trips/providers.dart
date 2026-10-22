import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase/supabase_client.dart';
import 'data/trips_repository.dart';
import 'ui/trip_draft.dart';

final tripsRepositoryProvider = Provider<TripsRepository>(
  (ref) => TripsRepository(ref.watch(supabaseProvider)),
);

/// 오늘 날짜. 테스트에서 고정할 수 있게 provider로 둔다.
final todayProvider = Provider<DateTime>((ref) => DateTime.now());

/// 내 여행 목록. 로그인이 끝난 뒤에 불러온다.
final myTripsProvider = FutureProvider<List<TripSummary>>((ref) async {
  await ref.watch(authUserProvider.future);
  return ref.watch(tripsRepositoryProvider).myTrips();
});

/// 여행 하나(멤버 포함).
final tripDetailProvider = FutureProvider.family<TripDetail, String>((
  ref,
  tripId,
) async {
  await ref.watch(authUserProvider.future);
  return ref.watch(tripsRepositoryProvider).tripDetail(tripId);
});

/// 여행 쓰기 작업. 화면이 아니라 provider의 ref를 써서, 저장 도중 화면이 닫혀도
/// 목록 새로고침까지 끝까지 한다.
final tripActionsProvider = Provider<TripActions>(TripActions.new);

class TripActions {
  TripActions(this._ref);

  final Ref _ref;

  /// 여행을 만들고 id를 돌려준다. 끝나면 홈 목록을 다시 불러온다.
  Future<String> create(TripDraft draft, {required String myName}) async {
    await _ref.read(authUserProvider.future);
    final id = await _ref
        .read(tripsRepositoryProvider)
        .createTrip(
          name: draft.name.trim(),
          startDate: draft.startDate!,
          endDate: draft.endDate!,
          currency: draft.currency!,
          myName: myName,
          friendNames: List.of(draft.friends),
        );
    _ref.invalidate(myTripsProvider);
    return id;
  }

  /// 목록을 다시 불러온다. 로그인이 실패해 있었다면 로그인부터 다시 한다.
  void reloadTrips() {
    if (_ref.read(authUserProvider).hasError) _ref.invalidate(authUserProvider);
    _ref.invalidate(myTripsProvider);
  }
}
