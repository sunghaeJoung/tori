import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../shared/widgets/screen_placeholder.dart';

/// 06 나는 누구? 초대 링크 `/join/:code`로 들어온다.
class JoinScreen extends StatelessWidget {
  const JoinScreen({super.key, required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return ScreenPlaceholder(
      title: '나는 누구?',
      stage: 5,
      actions: [
        FilledButton(
          onPressed: () => context.go(Routes.trip('sample')),
          child: const Text('입장하기'),
        ),
      ],
    );
  }
}
