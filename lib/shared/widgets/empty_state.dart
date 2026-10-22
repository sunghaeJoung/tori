import 'package:flutter/material.dart';

import 'tori_mascot.dart';

/// 내용이 없을 때 보여주는 토리 + 안내 문구.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.title, this.message, this.action});

  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 12,
          children: [
            const ToriMascot(),
            Text(title, style: text.titleMedium, textAlign: TextAlign.center),
            if (message != null)
              Text(
                message!,
                style: text.bodySmall?.copyWith(fontSize: 14, height: 1.6),
                textAlign: TextAlign.center,
              ),
            if (action != null)
              Padding(padding: const EdgeInsets.only(top: 8), child: action),
          ],
        ),
      ),
    );
  }
}
