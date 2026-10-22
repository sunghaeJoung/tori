import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tori/features/trips/data/trips_repository.dart';

import '../../helpers/fake_app.dart';

class _FailingRepository extends FakeTripsRepository {
  var fail = true;

  @override
  Future<List<TripSummary>> myTrips() async {
    if (fail) throw Exception('오프라인');
    return [sampleTrip()];
  }
}

void main() {
  testWidgets('여행이 없으면 안내', (tester) async {
    await pumpApp(tester);
    expect(find.text('아직 여행이 없어요'), findsOneWidget);
  });

  testWidgets('진행 중인 여행과 지난 여행을 나눠 보여준다', (tester) async {
    await pumpApp(
      tester,
      repository: FakeTripsRepository(
        trips: [
          sampleTrip(),
          sampleTrip(id: 't0', name: '제주 겨울여행', settled: true),
        ],
      ),
    );

    expect(find.text('진행 중인 여행'), findsOneWidget);
    expect(find.text('지난 여행'), findsOneWidget);
    expect(find.text('상하이 우정여행'), findsOneWidget);
    expect(find.text('CNY 위안화'), findsNWidgets(2));
    expect(find.text('2026.11.06 – 11.09 · 4명'), findsNWidgets(2));
    expect(find.text('여행 중'), findsOneWidget);
    expect(find.text('정산 완료'), findsOneWidget);
    expect(find.text('민'), findsOneWidget); // 내 이름 첫 글자
  });

  testWidgets('여행 카드를 누르면 여행방', (tester) async {
    await pumpApp(
      tester,
      repository: FakeTripsRepository(trips: [sampleTrip()]),
    );
    await tester.tap(find.text('상하이 우정여행'));
    await tester.pumpAndSettle();
    expect(appBarTitle('여행방'), findsOneWidget);
  });

  testWidgets('불러오기에 실패하면 다시 시도할 수 있다', (tester) async {
    final repo = _FailingRepository();
    await pumpApp(tester, repository: repo);
    // Riverpod 3은 실패한 provider를 자동으로 다시 시도하므로 그 사이 시간을 흘려보낸다
    await tester.pump(const Duration(seconds: 10));
    expect(find.text('여행을 불러오지 못했어요'), findsOneWidget);

    repo.fail = false;
    await tapButton<FilledButton>(tester, '다시 시도');
    expect(find.text('상하이 우정여행'), findsOneWidget);
  });
}
