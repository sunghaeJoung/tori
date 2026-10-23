import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../shared/limits.dart';
import '../../../shared/messages.dart';
import '../../../shared/widgets/labeled_field.dart';
import '../../../shared/widgets/tori_mascot.dart';
import '../../../shared/widgets/tori_wordmark.dart';
import '../providers.dart';

/// 01 첫 실행. 닉네임을 저장하면 라우터가 원래 가려던 곳으로 보낸다.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _nickname = TextEditingController();
  var _saving = false;

  @override
  void dispose() {
    _nickname.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() => _saving = true);
    try {
      await ref.read(nicknameProvider.notifier).save(_nickname.text);
    } catch (e) {
      debugPrint('닉네임 저장 실패: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showMessage('저장하지 못했어요. $retryHint');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
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
                      style: text.bodyLarge?.copyWith(
                        height: 1.65,
                        color: ToriColors.textSub,
                      ),
                    ),
                  ],
                ),
              ),
              LabeledField(
                label: '친구들에게 보일 이름',
                child: TextField(
                  controller: _nickname,
                  maxLength: Limits.personName,
                  textInputAction: TextInputAction.done,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _canStart ? _start() : null,
                  decoration: InputDecoration(
                    hintText: '이름 또는 별명',
                    counterText: '',
                    errorText: _lengthError,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _canStart ? _start : null,
                child: Text(_saving ? '저장하는 중…' : '시작하기'),
              ),
              const SizedBox(height: 12),
              Text(
                '회원가입 없이 바로 시작해요',
                textAlign: TextAlign.center,
                style: text.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 입력 중엔 '비어 있음'은 보여주지 않고 길이 초과만 알린다.
  String? get _lengthError => _nickname.text.trim().isEmpty
      ? null
      : NicknameNotifier.validate(_nickname.text);

  bool get _canStart =>
      !_saving && NicknameNotifier.validate(_nickname.text) == null;
}
