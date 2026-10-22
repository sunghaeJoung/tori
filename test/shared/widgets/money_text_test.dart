import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tori/app/theme.dart';
import 'package:tori/core/money/currency.dart';
import 'package:tori/shared/widgets/money_text.dart';

Future<Text> pumpMoney(WidgetTester tester, MoneyText money) async {
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: money)));
  return tester.widget<Text>(find.byType(Text));
}

void main() {
  testWidgets('통화 표기 그대로, 색은 바꾸지 않는다', (tester) async {
    final text = await pumpMoney(
      tester,
      const MoneyText(
        12850,
        Currency.cny,
        style: TextStyle(color: Colors.black),
      ),
    );
    expect(text.data, '128.50위안');
    expect(text.style?.color, Colors.black);
    expect(text.style?.fontFeatures, [const FontFeature.tabularFigures()]);
  });

  testWidgets('잔액: 받을 돈은 + 와 파랑', (tester) async {
    final text = await pumpMoney(
      tester,
      const MoneyText(325550, Currency.krw, balance: true),
    );
    expect(text.data, '+325,550원');
    expect(text.style?.color, ToriColors.receive);
  });

  testWidgets('잔액: 줄 돈은 - 와 빨강', (tester) async {
    final text = await pumpMoney(
      tester,
      const MoneyText(-568010, Currency.krw, balance: true),
    );
    expect(text.data, '-568,010원');
    expect(text.style?.color, ToriColors.pay);
  });

  testWidgets('잔액 0은 부호·색 없음', (tester) async {
    final text = await pumpMoney(
      tester,
      const MoneyText(0, Currency.krw, balance: true),
    );
    expect(text.data, '0원');
    expect(text.style?.color, isNull);
  });
}
