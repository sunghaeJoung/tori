import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../shared/widgets/bottom_actions.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../trips/data/trips_repository.dart';
import '../../trips/providers.dart';

/// 지금 열린 주소 기준의 초대 링크 (배포 주소가 바뀌어도 그대로 맞는다).
String inviteLink(String inviteCode) => Uri(
  scheme: Uri.base.scheme,
  host: Uri.base.host,
  port: Uri.base.hasPort ? Uri.base.port : null,
  path: Routes.join(inviteCode),
).toString();

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
      body: switch (trip) {
        AsyncValue(hasValue: true, :final value?) => _InviteBody(trip: value),
        AsyncValue(isLoading: true) => const Center(
          child: CircularProgressIndicator(),
        ),
        _ => EmptyState(
          title: '여행을 불러오지 못했어요',
          message: '인터넷 연결을 확인해 주세요',
          action: FilledButton.tonal(
            onPressed: () => ref.invalidate(tripDetailProvider(tripId)),
            child: const Text('다시 시도'),
          ),
        ),
      },
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
    final link = inviteLink(trip.inviteCode);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: '토리에서 "${trip.name}" 여행 경비를 같이 정리해요\n$link',
          mailToFallbackEnabled: false,
        ),
      );
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: link));
      messenger.showSnackBar(
        const SnackBar(content: Text('공유할 수 없어서 초대 링크를 복사했어요')),
      );
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
    final code = widget.trip.inviteCode;
    final link = inviteLink(code);

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
                label: '초대 코드 ${code.split('').join(' ')}',
                child: ExcludeSemantics(
                  child: Row(
                    spacing: 6,
                    children: [
                      for (final char in code.split(''))
                        Expanded(child: _CodeBox(char)),
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
                decoration: BoxDecoration(
                  color: ToriColors.surface,
                  border: Border.all(color: ToriColors.border),
                  borderRadius: BorderRadius.circular(16),
                ),
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
      decoration: BoxDecoration(
        color: ToriColors.surface,
        border: Border.all(color: ToriColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        char,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
      ),
    );
  }
}
