import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../shared/widgets/bottom_actions.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/tori_mascot.dart';

/// 02 홈. 여행 목록은 4단계에서 붙인다.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        titleSpacing: 20,
        title: const Row(
          spacing: 8,
          children: [
            ToriMascot(size: 28, face: ToriFace.none),
            Text(
              '토리',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: ToriColors.acornCap,
              ),
            ),
          ],
        ),
      ),
      body: const EmptyState(
        title: '아직 여행이 없어요',
        message: '새 여행을 만들고 친구들을 초대해보세요',
      ),
      bottomNavigationBar: BottomActions(
        children: [
          FilledButton.icon(
            onPressed: () => context.push(Routes.newTrip),
            icon: const Icon(Icons.add),
            label: const Text('새 여행 만들기'),
          ),
          // 임시: 여행방 화면들로 가는 길. 4단계에서 여행 목록으로 바꾼다.
          TextButton(
            onPressed: () => context.push(Routes.trip('sample')),
            child: const Text('예시 여행방 열기'),
          ),
        ],
      ),
    );
  }
}
