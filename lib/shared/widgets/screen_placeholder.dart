import 'package:flutter/material.dart';

import 'bottom_actions.dart';
import 'empty_state.dart';

/// 아직 만들지 않은 화면의 자리. 각 단계에서 실제 화면으로 바꾸면 지운다.
class ScreenPlaceholder extends StatelessWidget {
  const ScreenPlaceholder({
    super.key,
    required this.title,
    required this.stage,
    required this.actions,
  });

  final String title;

  /// 이 화면을 만드는 로드맵 단계.
  final int stage;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: EmptyState(title: title, message: '$stage단계에서 만들어요'),
      bottomNavigationBar: BottomActions(children: actions),
    );
  }
}
