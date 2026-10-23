import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../shared/messages.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/bottom_actions.dart';
import '../../trips/data/trip.dart';
import '../../trips/providers.dart';

/// 05 초대하기. 초대 코드·링크를 복사하거나 휴대폰 공유창으로 보낸다.
class InviteScreen extends ConsumerWidget {
  const InviteScreen({super.key, required this.tripId});

  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trip = ref.watch(tripDetailProvider(tripId));
    void toTrip() => context.go(Routes.trip(tripId));

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: '닫기',
            onPressed: toTrip,
            icon: const Icon(Icons.close),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: AsyncView(
        value: trip,
        onRetry: () => ref.invalidate(tripDetailProvider(tripId)),
        errorTitle: '여행을 불러오지 못했어요',
        data: (trip) => _InviteBody(trip: trip),
      ),
      bottomNavigationBar: BottomActions(
        children: [
          if (trip.value case final value?)
            FilledButton.icon(
              onPressed: () => _share(context, value),
              icon: const Icon(Icons.ios_share),
              label: const Text('친구에게 공유하기'),
            ),
          TextButton(onPressed: toTrip, child: const Text('여행방으로 가기')),
        ],
      ),
    );
  }

  /// 휴대폰 공유창을 연다. 공유창이 없는 브라우저(PC 등)면 링크를 복사한다.
  Future<void> _share(BuildContext context, TripDetail trip) async {
    final link = Routes.joinUrl(trip.inviteCode);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: '토리에서 "${trip.name}" 여행 경비를 같이 정리해요\n$link',
          mailToFallbackEnabled: false,
        ),
      );
    } on Exception {
      // 공유창이 없는 브라우저면 링크 복사로 대신한다
      try {
        await Clipboard.setData(ClipboardData(text: link));
        messenger.showMessage('공유할 수 없어서 초대 링크를 복사했어요');
      } on Exception {
        messenger.showMessage('공유하지 못했어요. 초대 코드 ${trip.inviteCode}를 알려주세요');
      }
    }
  }
}

class _InviteBody extends StatefulWidget {
  const _InviteBody({required this.trip});

  final TripDetail trip;

  @override
  State<_InviteBody> createState() => _InviteBodyState();
}

class _InviteBodyState extends State<_InviteBody> {
  var _copied = false;

  Future<void> _copy(String link) async {
    await Clipboard.setData(ClipboardData(text: link));
    setState(() => _copied = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final chars = widget.trip.inviteCode.split('');
    final link = Routes.joinUrl(widget.trip.inviteCode);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 28,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 8,
            children: [
              Text(
                '${widget.trip.name}\n여행방이 생겼어요',
                style: text.headlineMedium,
              ),
              Text(
                '친구들에게 초대 코드나 링크를 보내주세요',
                style: text.bodyMedium?.copyWith(color: ToriColors.textSub),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 10,
            children: [
              Text('초대 코드', style: text.labelLarge),
              Semantics(
                label: '초대 코드 ${chars.join(' ')}',
                child: ExcludeSemantics(
                  child: Row(
                    spacing: 6,
                    children: [
                      for (final char in chars) Expanded(child: _CodeBox(char)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 10,
            children: [
              Text('초대 링크', style: text.labelLarge),
              Container(
                height: 56,
                padding: const EdgeInsets.only(left: 16, right: 6),
                decoration: _box(16),
                child: Row(
                  spacing: 8,
                  children: [
                    Expanded(
                      child: Text(
                        link.replaceFirst(RegExp(r'^https?://'), ''),
                        overflow: TextOverflow.ellipsis,
                        style: text.bodyMedium?.copyWith(
                          color: ToriColors.textMuted,
                        ),
                      ),
                    ),
                    FilledButton.tonal(
                      onPressed: () => _copy(link),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(64, 44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: text.labelLarge,
                      ),
                      child: Text(_copied ? '복사했어요' : '복사'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CodeBox extends StatelessWidget {
  const _CodeBox(this.char);

  final String char;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      alignment: Alignment.center,
      decoration: _box(12),
      child: Text(
        char,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 22),
      ),
    );
  }
}

/// 입력칸처럼 보이는 흰 상자.
BoxDecoration _box(double radius) => BoxDecoration(
  color: ToriColors.surface,
  border: Border.all(color: ToriColors.border),
  borderRadius: BorderRadius.circular(radius),
);
