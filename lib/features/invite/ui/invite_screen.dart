import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../shared/widgets/screen_placeholder.dart';

/// 05 초대하기.
class InviteScreen extends StatelessWidget {
  const InviteScreen({super.key, required this.tripId});

  final String tripId;

  @override
  Widget build(BuildContext context) {
    return ScreenPlaceholder(
      title: '초대하기',
      stage: 5,
      actions: [
        FilledButton(
          onPressed: () => context.go(Routes.trip(tripId)),
          child: const Text('여행방으로 가기'),
        ),
      ],
    );
  }
}
