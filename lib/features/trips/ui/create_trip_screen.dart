import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/money/currency.dart';
import '../../../shared/dates.dart';
import '../../../shared/limits.dart';
import '../../../shared/widgets/bottom_actions.dart';
import '../../../shared/widgets/labeled_field.dart';
import '../../../shared/widgets/money_text.dart';
import '../../../shared/widgets/selectable_card.dart';
import '../../onboarding/providers.dart';
import '../providers.dart';
import 'trip_draft.dart';

/// 03·04 여행 만들기. 이름 → 날짜 → 통화 → 멤버 4단계.
class CreateTripScreen extends ConsumerStatefulWidget {
  const CreateTripScreen({super.key});

  @override
  ConsumerState<CreateTripScreen> createState() => _CreateTripScreenState();
}

class _CreateTripScreenState extends ConsumerState<CreateTripScreen> {
  static const _lastStep = 4;

  final _draft = TripDraft();
  final _friend = TextEditingController();
  var _step = 1;
  var _saving = false;
  String? _friendError;

  @override
  void dispose() {
    _friend.dispose();
    super.dispose();
  }

  String get _myName => ref.read(nicknameProvider) ?? '';

  void _back() {
    if (_saving) return;
    if (_step > 1) {
      setState(() => _step--);
    } else if (context.canPop()) {
      context.pop();
    } else {
      // 주소로 바로 들어와 돌아갈 화면이 없을 때
      context.go(Routes.home);
    }
  }

  Future<void> _next() async {
    if (_step < _lastStep) {
      setState(() => _step++);
      return;
    }
    setState(() => _saving = true);
    try {
      final id = await ref
          .read(tripActionsProvider)
          .create(_draft, myName: _myName);
      if (mounted) context.go(Routes.invite(id));
    } catch (e) {
      debugPrint('여행 만들기 실패: $e');
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('여행을 만들지 못했어요. 인터넷 연결을 확인하고 다시 시도해 주세요')),
      );
    }
  }

  void _addFriend() {
    final error = _draft.addFriend(_friend.text, myName: _myName);
    setState(() {
      _friendError = error;
      if (error == null) _friend.clear();
    });
  }

  Future<void> _pickDate({required bool start}) async {
    final first = start ? DateTime(2020) : (_draft.startDate ?? DateTime(2020));
    final current = start ? _draft.startDate : _draft.endDate;
    final picked = await showDatePicker(
      context: context,
      initialDate:
          current ?? _draft.startDate ?? DateUtils.dateOnly(DateTime.now()),
      firstDate: first,
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        _draft.setStartDate(picked);
      } else {
        _draft.endDate = picked;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _step == 1 && !_saving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: '뒤로',
            onPressed: _saving ? null : _back,
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 20),
              child: Text(
                '$_step / $_lastStep',
                style: Theme.of(context).textTheme.labelLarge
                    ?.copyWith(color: ToriColors.textSub),
              ),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: LinearProgressIndicator(
                value: _step / _lastStep,
                minHeight: 4,
                borderRadius: BorderRadius.circular(2),
                backgroundColor: ToriColors.cardBorder,
              ),
            ),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 24,
            children: switch (_step) {
              1 => _nameStep(),
              2 => _dateStep(),
              3 => _currencyStep(),
              _ => _memberStep(),
            },
          ),
        ),
        bottomNavigationBar: BottomActions(
          children: [
            FilledButton(
              onPressed: !_saving && _draft.canProceed(_step) ? _next : null,
              child: Text(
                _step < _lastStep ? '다음' : (_saving ? '만드는 중…' : '여행 만들기'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _nameStep() => [
    const _StepTitle('여행 이름을 정해주세요', '친구들이 한눈에 알아볼 수 있는 이름이면 좋아요'),
    LabeledField(
      label: '여행 이름',
      child: TextFormField(
        initialValue: _draft.name,
        autofocus: true,
        maxLength: Limits.tripName,
        textInputAction: TextInputAction.next,
        onChanged: (value) => setState(() => _draft.name = value),
        onFieldSubmitted: (_) => _draft.canProceed(1) ? _next() : null,
        decoration: InputDecoration(
          hintText: '예: 상하이 우정여행',
          counterText: '',
          errorText: textLength(_draft.name.trim()) > Limits.tripName
              ? '여행 이름은 ${Limits.tripName}자까지 쓸 수 있어요'
              : null,
        ),
      ),
    ),
  ];

  List<Widget> _dateStep() => [
    const _StepTitle('언제 떠나나요?', '지출을 날짜별로 정리할 때 써요'),
    Row(
      spacing: 12,
      children: [
        Expanded(
          child: LabeledField(
            label: '출발',
            child: _DateField(
              date: _draft.startDate,
              onTap: () => _pickDate(start: true),
            ),
          ),
        ),
        Expanded(
          child: LabeledField(
            label: '도착',
            child: _DateField(
              date: _draft.endDate,
              onTap: () => _pickDate(start: false),
            ),
          ),
        ),
      ],
    ),
  ];

  List<Widget> _currencyStep() => [
    const _StepTitle('어떤 돈을 쓰나요?', '여행지에서 쓸 통화를 골라주세요.\n정산은 언제나 원화로 해요.'),
    Column(
      spacing: 10,
      children: [
        for (final currency in Currency.values)
          _CurrencyOption(
            currency: currency,
            selected: _draft.currency == currency,
            onTap: () => setState(() => _draft.currency = currency),
          ),
      ],
    ),
  ];

  List<Widget> _memberStep() => [
    const _StepTitle('누구와 함께 가나요?', '이름을 미리 넣어두면, 초대받은 친구가\n자기 이름을 골라서 들어와요.'),
    Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _MemberChip(label: '${ref.watch(nicknameProvider) ?? ''} (나)'),
        for (final friend in _draft.friends)
          _MemberChip(
            label: friend,
            onRemove: () => setState(() => _draft.friends.remove(friend)),
          ),
      ],
    ),
    LabeledField(
      label: '친구 추가',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Expanded(
            child: TextField(
              controller: _friend,
              autofocus: true,
              maxLength: Limits.personName,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _addFriend(),
              decoration: InputDecoration(
                hintText: '친구 이름',
                counterText: '',
                errorText: _friendError,
              ),
            ),
          ),
          FilledButton.tonal(onPressed: _addFriend, child: const Text('추가')),
        ],
      ),
    ),
  ];
}

class _StepTitle extends StatelessWidget {
  const _StepTitle(this.title, this.description);

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        Text(title, style: text.headlineMedium),
        Text(
          description,
          style: text.bodyMedium?.copyWith(
            height: 1.5,
            color: ToriColors.textSub,
          ),
        ),
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.date, required this.onTap});

  final DateTime? date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: InputDecorator(
        decoration: const InputDecoration(
          suffixIcon: Icon(Icons.calendar_today_outlined, size: 20),
        ),
        child: Text(
          date == null ? '날짜 선택' : formatDate(date!),
          style: TextStyle(
            fontSize: 16,
            color: date == null ? ToriColors.textSub : ToriColors.text,
          ),
        ),
      ),
    );
  }
}

class _CurrencyOption extends StatelessWidget {
  const _CurrencyOption({
    required this.currency,
    required this.selected,
    required this.onTap,
  });

  final Currency currency;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sampleAmount = switch (currency) {
      Currency.krw => 12350,
      Currency.jpy => 1500,
      Currency.cny => 12850,
      Currency.usd => 1299,
    };
    final text = Theme.of(context).textTheme;

    return SelectableCard(
      selected: selected,
      onTap: onTap,
      child: Row(
        spacing: 14,
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: ToriColors.tile,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              currency.code,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: ToriColors.acornCap,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 3,
              children: [
                Text(currency.label, style: text.titleMedium),
                Text(
                  currency == Currency.krw
                      ? '국내 여행 · 환율 없이 바로 정산'
                      : '정산할 때 원화로 바꿔요',
                  style: text.bodySmall,
                ),
              ],
            ),
          ),
          MoneyText(
            sampleAmount,
            currency,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: ToriColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberChip extends StatelessWidget {
  const _MemberChip({required this.label, this.onRemove});

  final String label;

  /// null이면 뺄 수 없는 멤버(나).
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return InputChip(
      label: Text(label),
      labelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      backgroundColor: ToriColors.surface,
      side: const BorderSide(color: ToriColors.border),
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      onDeleted: onRemove,
      deleteIcon: const Icon(Icons.close, size: 16),
      deleteIconColor: ToriColors.textSub,
      deleteButtonTooltipMessage: '$label 빼기',
    );
  }
}
