import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../shared/widgets/tori_mascot.dart';
import '../../../shared/widgets/tori_wordmark.dart';

/// 01 첫 실행. 닉네임 입력은 4단계에서 붙인다.
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: 14,
                  children: [
                    const ToriMascot(size: 112, face: ToriFace.smile),
                    const ToriWordmark(size: 44),
                    Text(
                      '여행 경비, 도토리처럼 공평하게.\n여행이 끝나면 원화로 깔끔하게 나눠드려요.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge
                          ?.copyWith(height: 1.65, color: ToriColors.textSub),
                    ),
                  ],
                ),
              ),
              FilledButton(
                onPressed: () => context.go(Routes.home),
                child: const Text('시작하기'),
              ),
              const SizedBox(height: 12),
              Text(
                '회원가입 없이 바로 시작해요',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
