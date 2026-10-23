import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/exchange_rate/frankfurter_api.dart';
import '../../core/money/currency.dart';
import '../../core/supabase/supabase_client.dart';
import '../expenses/providers.dart';
import '../trips/data/trip.dart';
import '../trips/providers.dart';
import 'data/settlement.dart';
import 'data/settlement_repository.dart';

final frankfurterApiProvider = Provider<FrankfurterApi>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return FrankfurterApi(client);
});

/// 오늘(최근 영업일) 환율. 화면을 떠나면 버려서 다시 열면 새로 불러온다.
/// 실패해도 저절로 다시 시도하지 않는다 (화면에 다시 시도·직접 입력이 있다).
final latestRateProvider = FutureProvider.autoDispose
    .family<ExchangeRate, Currency>(
      (ref, currency) => ref.watch(frankfurterApiProvider).latest(currency),
      retry: (_, _) => null,
    );

/// 원화 여행의 "환율" (1원 = 1원).
ExchangeRate wonRate(DateTime today) =>
    ExchangeRate(currency: Currency.krw, krwPerUnit: Decimal.one, date: today);

/// "약 ○○원" 참고 표시에 쓰는 환율.
/// 정산을 확정했으면 그 환율, 원화 여행이면 1, 아니면 오늘 환율. 오늘 환율을 못 불러오면 null.
final referenceRateProvider = FutureProvider.autoDispose
    .family<ExchangeRate?, String>((ref, tripId) async {
      final trip = await ref.watch(tripDetailProvider(tripId).future);
      if (trip.settled) return trip.settledRate;
      if (trip.currency == Currency.krw) {
        return wonRate(ref.watch(todayProvider));
      }
      try {
        return await ref.watch(latestRateProvider(trip.currency).future);
      } on Exception {
        return null;
      }
    });

/// 멤버별 잔액과 총 지출.
final balancesProvider = FutureProvider.autoDispose
    .family<TripBalances, String>((ref, tripId) async {
      final trip = await ref.watch(tripDetailProvider(tripId).future);
      final expenses = await ref.watch(expensesProvider(tripId).future);
      return TripBalances(trip.memberIds, expenses);
    });

final settlementRepositoryProvider = Provider<SettlementRepository>(
  (ref) => SettlementRepository(ref.watch(supabaseProvider)),
);

/// 확정한 송금 목록. 친구가 완료를 체크하면 다시 불러온다.
final transfersProvider = FutureProvider.autoDispose
    .family<List<SettlementTransfer>, String>((ref, tripId) async {
      ref.watch(tripChangesProvider(tripId));
      await ref.watch(authUserProvider.future);
      return ref.watch(settlementRepositoryProvider).transfers(tripId);
    });

final settlementActionsProvider = Provider<SettlementActions>(
  SettlementActions.new,
);

class SettlementActions {
  SettlementActions(this._ref);

  final Ref _ref;

  /// [rate]로 정산을 확정한다. 송금 목록은 지금 잔액으로 계산한다.
  Future<void> confirm(
    TripDetail trip,
    TripBalances balances,
    ExchangeRate rate,
  ) async {
    await _ref
        .read(settlementRepositoryProvider)
        .confirm(trip.id, rate, balances.plan(trip.currency, rate.krwPerUnit));
    _ref
      ..invalidate(tripDetailProvider(trip.id))
      ..invalidate(transfersProvider(trip.id));
  }

  Future<void> setDone(
    String tripId,
    String transferId, {
    required bool done,
  }) async {
    await _ref
        .read(settlementRepositoryProvider)
        .setDone(transferId, done: done);
    _ref.invalidate(transfersProvider(tripId));
  }
}
