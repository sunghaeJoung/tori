import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_app.dart';

void main() {
  testWidgets('여행이 없으면 안내', (tester) async {
    await pumpApp(tester);
    expect(find.text('아직 여행이 없어요'), findsOneWidget);
  });

  testWidgets('진행 중 · 다가오는 · 지난 여행으로 나눠 보여준다', (tester) async {
    // 카드 5개가 한 화면에 다 그려지도록 화면을 길게
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // 오늘은 2026-11-07
    await pumpApp(
      tester,
      repository: FakeTripsRepository(
        trips: [
          sampleTrip(
            id: 'a',
            name: '제주',
            start: DateTime(2026, 2, 14),
            end: DateTime(2026, 2, 16),
            settled: true,
          ),
          sampleTrip(
            id: 'b',
            name: '도쿄',
            start: DateTime(2026, 11, 20),
            end: DateTime(2026, 11, 22),
          ),
          sampleTrip(
            id: 'c',
            name: '부산',
            start: DateTime(2026, 11, 1),
            end: DateTime(2026, 11, 3),
          ),
          sampleTrip(id: 'd', name: '상하이'),
          sampleTrip(
            id: 'e',
            name: '내일 출발',
            start: DateTime(2026, 11, 8),
            end: DateTime(2026, 11, 8),
          ),
        ],
      ),
    );

    // 화면 위에서부터의 순서
    final order = [
      '진행 중인 여행',
      '상하이',
      '다가오는 여행',
      '내일 출발',
      '도쿄',
      '지난 여행',
      '부산',
      '제주',
    ];
    final ys = [for (final t in order) tester.getTopLeft(find.text(t)).dy];
    expect(ys, orderedEquals([...ys]..sort()));

    expect(find.text('여행 중'), findsOneWidget);
    expect(find.text('D-1'), findsOneWidget);
    expect(find.text('D-13'), findsOneWidget);
    expect(find.text('정산 전'), findsOneWidget);
    expect(find.text('정산 완료'), findsOneWidget);
    expect(find.text('CNY 위안화'), findsNWidgets(5));
    expect(find.text('2026.11.06 – 11.09 · 4명'), findsOneWidget);
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
    final repo = FakeTripsRepository(trips: [sampleTrip()])
      ..failWith = Exception('오프라인');
    await pumpApp(tester, repository: repo);
    // Riverpod 3은 실패한 provider를 자동으로 다시 시도하므로 그 사이 시간을 흘려보낸다
    await tester.pump(const Duration(seconds: 10));
    expect(find.text('불러오지 못했어요'), findsOneWidget);

    repo.failWith = null;
    await tapButton<FilledButton>(tester, '다시 시도');
    expect(find.text('상하이 우정여행'), findsOneWidget);
  });
}
