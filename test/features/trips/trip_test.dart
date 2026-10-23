import 'package:flutter_test/flutter_test.dart';
import 'package:tori/core/money/currency.dart';
import 'package:tori/features/trips/data/trip.dart';

import '../../helpers/fake_app.dart';

void main() {
  // 여행 기간 2026-11-06 ~ 11-09
  final trip = sampleTrip();

  test('출발 전이면 다가오는 여행, 남은 날 수', () {
    final today = DateTime(2026, 11, 5, 23, 59);
    expect(trip.phaseOn(today), TripPhase.upcoming);
    expect(trip.daysUntilStart(today), 1);
    expect(trip.daysUntilStart(DateTime(2026, 10, 22)), 15);
  });

  test('출발일과 도착일 당일도 진행 중', () {
    expect(trip.phaseOn(DateTime(2026, 11, 6)), TripPhase.ongoing);
    expect(trip.phaseOn(DateTime(2026, 11, 9, 23, 59)), TripPhase.ongoing);
  });

  test('도착일이 지나면 지난 여행', () {
    expect(trip.phaseOn(DateTime(2026, 11, 10)), TripPhase.past);
  });

  test('정산을 마치면 날짜와 상관없이 지난 여행', () {
    final settled = sampleTrip(settled: true);
    expect(settled.phaseOn(DateTime(2026, 11, 7)), TripPhase.past);
  });

  test('여행에서 내 멤버 찾기', () {
    final detail = TripDetail(
      id: 't1',
      name: '상하이',
      startDate: DateTime(2026, 11, 6),
      endDate: DateTime(2026, 11, 9),
      currency: Currency.cny,
      inviteCode: 'ABCD2345',
      settled: false,
      members: const [
        Member(id: 'm1', name: '민지', userId: 'u1'),
        Member(id: 'm2', name: '수아'),
      ],
    );
    expect(detail.memberOf('u1')?.name, '민지');
    expect(detail.memberOf('someone-else'), isNull);
  });
}
