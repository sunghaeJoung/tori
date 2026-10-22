import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tori/app/router.dart';
import 'package:tori/features/invite/ui/invite_screen.dart';

import '../../helpers/fake_app.dart';

void main() {
  testWidgets('여행 이름, 8자리 초대 코드, 초대 링크를 보여준다', (tester) async {
    await pumpApp(tester, location: Routes.invite('t1'));

    expect(find.text('상하이 우정여행\n여행방이 생겼어요'), findsOneWidget);
    for (final char in 'TR7K2QAB'.split('')) {
      expect(find.text(char), findsOneWidget);
    }
    expect(find.textContaining('/join/TR7K2QAB'), findsOneWidget);
  });

  testWidgets('복사를 누르면 링크가 클립보드에 들어간다', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await pumpApp(tester, location: Routes.invite('t1'));
    await tester.tap(find.text('복사'));
    await tester.pump();

    expect(copied, inviteLink('TR7K2QAB'));
    expect(find.text('복사했어요'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('복사'), findsOneWidget);
  });

  testWidgets('여행방으로 가기 / 닫기', (tester) async {
    await pumpApp(tester, location: Routes.invite('t1'));
    await tapButton<TextButton>(tester, '여행방으로 가기');
    expect(appBarTitle('여행방'), findsOneWidget);

    await pumpApp(tester, location: Routes.invite('t1'));
    await tester.tap(find.byTooltip('닫기'));
    await tester.pumpAndSettle();
    expect(appBarTitle('여행방'), findsOneWidget);
  });
}
