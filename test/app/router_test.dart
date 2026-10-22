import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tori/app/router.dart';
import 'package:tori/main.dart';

/// 앱을 띄우고, [location]이 있으면 그 주소로 이동한다.
Future<void> pumpApp(WidgetTester tester, [String? location]) async {
  final container = ProviderContainer();
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

void main() {
  testWidgets('첫 실행 → 홈 → 여행 만들기 → 초대 → 여행방', (tester) async {
    await pumpApp(tester, Routes.onboarding);
    expect(find.text('회원가입 없이 바로 시작해요'), findsOneWidget);

    await tapButton<FilledButton>(tester, '시작하기');
    expect(find.text('아직 여행이 없어요'), findsOneWidget);

    await tapButton<FilledButton>(tester, '새 여행 만들기');
    expect(appBarTitle('여행 만들기'), findsOneWidget);

    await tapButton<FilledButton>(tester, '여행 만들기');
    expect(appBarTitle('초대하기'), findsOneWidget);

    await tapButton<FilledButton>(tester, '여행방으로 가기');
    expect(appBarTitle('여행방'), findsOneWidget);
  });

  testWidgets('여행방 → 지출 추가 → 저장하면 여행방으로 돌아온다', (tester) async {
    await pumpApp(tester, Routes.home);
    await tapButton<TextButton>(tester, '예시 여행방 열기');
    expect(appBarTitle('여행방'), findsOneWidget);

    await tapButton<FilledButton>(tester, '지출 추가');
    expect(appBarTitle('지출 추가'), findsOneWidget);

    await tapButton<FilledButton>(tester, '저장');
    expect(appBarTitle('여행방'), findsOneWidget);
  });

  testWidgets('여행방 → 정산 환율 → 취소하면 여행방으로 돌아온다', (tester) async {
    await pumpApp(tester, Routes.trip('t1'));
    await tapButton<TextButton>(tester, '정산하기');
    expect(appBarTitle('정산 환율 확인'), findsOneWidget);

    await tapButton<TextButton>(tester, '취소');
    expect(appBarTitle('여행방'), findsOneWidget);
  });

  testWidgets('주소로 바로 들어가기', (tester) async {
    await pumpApp(tester, Routes.newTrip);
    expect(appBarTitle('여행 만들기'), findsOneWidget);

    await pumpApp(tester, Routes.join('ABCD1234'));
    expect(appBarTitle('나는 누구?'), findsOneWidget);

    await pumpApp(tester, Routes.expense('t1', 'e1'));
    expect(appBarTitle('지출 수정'), findsOneWidget);
  });

  testWidgets('처음 열면 홈', (tester) async {
    await pumpApp(tester);
    expect(find.text('아직 여행이 없어요'), findsOneWidget);
  });

  testWidgets('없는 주소는 안내 화면 → 홈으로', (tester) async {
    await pumpApp(tester, '/nowhere');
    expect(find.text('페이지를 찾을 수 없어요'), findsOneWidget);

    await tapButton<FilledButton>(tester, '홈으로');
    expect(find.text('아직 여행이 없어요'), findsOneWidget);
  });
}
