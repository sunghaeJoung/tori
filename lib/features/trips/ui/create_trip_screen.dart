import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../shared/widgets/screen_placeholder.dart';

/// 03·04 여행 만들기.
class CreateTripScreen extends StatelessWidget {
  const CreateTripScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenPlaceholder(
      title: '여행 만들기',
      stage: 4,
      actions: [
        FilledButton(
          onPressed: () => context.go(Routes.invite('sample')),
          child: const Text('여행 만들기'),
        ),
      ],
    );
  }
}
