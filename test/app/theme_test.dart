import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tori/app/theme.dart';

void main() {
  testWidgets('FilledButton을 Row 안에 둬도 레이아웃이 깨지지 않는다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: toriTheme,
        home: Scaffold(
          body: Row(
            children: [
              FilledButton(onPressed: () {}, child: const Text('취소')),
              FilledButton(onPressed: () {}, child: const Text('저장')),
            ],
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(FilledButton).first).height, 56);
  });
}
