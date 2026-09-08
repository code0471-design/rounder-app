import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/club_model.dart';
import '../../providers/club_provider.dart';
import '../../utils/finance_onboarding.dart';

const _kTossInk = Color(0xFF191F28);
const _kTossGray = Color(0xFF6B7684);
const _kTossMuted = Color(0xFF8B95A1);
const _kTossLine = Color(0xFFE5E8EB);
const _kTossBlue = Color(0xFF3182F6);

/// 신규 모임 총무가 재무 탭에 처음 들어왔을 때 — 토스형 시작 안내
class TreasurerFinanceOnboardingScreen extends StatefulWidget {
  final void Function(DuesType kind, FinanceStartMode mode) onFinished;
  const TreasurerFinanceOnboardingScreen({
    super.key,
    required this.onFinished,
  });

  @override
  State<TreasurerFinanceOnboardingScreen> createState() =>
      _TreasurerFinanceOnboardingScreenState();
}

class _TreasurerFinanceOnboardingScreenState
    extends State<TreasurerFinanceOnboardingScreen> {
  int _step = 0;
  FinanceStartMode? _mode;
  final _amountCtrl = TextEditingController();

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  int get _amount {
    final digits = _amountCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(digits) ?? 0;
  }

  void _pick(FinanceStartMode mode) {
    setState(() {
      _mode = mode;
      _step = 1;
    });
  }

  void _saveBalance(ClubProvider provider) {
    final mode = _mode;
    if (mode == null) return;
    final now = DateTime.now();
    provider.setOpeningBalance(
      amount: _amount,
      asOf: FinanceOnboarding.openingAsOf(mode, now),
      memo: FinanceOnboarding.memoFor(mode, now),
    );
    setState(() => _step = 2);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ClubProvider>();
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 16),
          child: Column(
            children: [
              if (_step > 0)
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                    icon: const Icon(Icons.arrow_back_ios_new,
                        size: 18, color: _kTossInk),
                    onPressed: () => setState(() => _step = _step == 2 ? 1 : 0),
                  ),
                )
              else
                const SizedBox(height: 40),
              Expanded(
                child: _step == 0
                    ? _buildChoice()
                    : _step == 1
                        ? _buildAmount(provider)
                        : _buildDuesKind(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChoice() {
    return ListView(
      children: [
        const SizedBox(height: 12),
        const Text(
          '총무님 반갑습니다',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: _kTossInk,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          '모임을 처음 시작하셨네요.\n회계를 어디서부터 넣을지 하나만 골라 주세요.',
          style: TextStyle(
            fontSize: 16,
            height: 1.5,
            color: _kTossGray,
          ),
        ),
        const SizedBox(height: 28),
        _ChoiceCard(
          title: '올시즌 처음부터 회계 현황을 입력',
          subtitle: '올해 1월 1일 잔고를 넣고, 그때부터의 수입·지출을 기록합니다.',
          onTap: () => _pick(FinanceStartMode.season),
        ),
        const SizedBox(height: 12),
        _ChoiceCard(
          title: '이번달 회계자료부터 입력',
          subtitle: '이번 달 1일 잔고만 넣으면 됩니다. 이전 달은 생략해도 돼요.',
          onTap: () => _pick(FinanceStartMode.thisMonth),
        ),
      ],
    );
  }

  Widget _buildAmount(ClubProvider provider) {
    final mode = _mode!;
    final asOf = FinanceOnboarding.openingAsOf(mode);
    final season = mode == FinanceStartMode.season;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: ListView(
            children: [
              Text(
                season ? '올해 시작 잔고를 알려 주세요' : '이번 달 시작 잔고를 알려 주세요',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: _kTossInk,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                season
                    ? '${FinanceOnboarding.asOfLabel(asOf)} 통장에 있던 회비 잔고예요. 이후 수입·지출은 수입/지출 탭에서 이어서 넣으면 됩니다.'
                    : '${FinanceOnboarding.asOfLabel(asOf)} 통장 잔고만 넣으면 됩니다. 이번 달부터만 기록하면 돼요.',
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: _kTossGray,
                ),
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _amountCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: _kTossInk,
                ),
                decoration: const InputDecoration(
                  hintText: '0',
                  hintStyle: TextStyle(color: _kTossMuted, fontWeight: FontWeight.w600),
                  suffixText: '원',
                  suffixStyle: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: _kTossInk,
                  ),
                  border: InputBorder.none,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const Divider(color: _kTossLine, height: 1),
              const SizedBox(height: 12),
              const Text(
                '잔고가 없으면 0원으로 시작해도 됩니다',
                style: TextStyle(fontSize: 13, color: _kTossMuted),
              ),
            ],
          ),
        ),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            onPressed: () => _saveBalance(provider),
            style: FilledButton.styleFrom(
              backgroundColor: _kTossInk,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              textStyle:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            child: const Text('잔고 등록하기'),
          ),
        ),
      ],
    );
  }

  Widget _buildDuesKind() {
    return ListView(
      children: [
        const SizedBox(height: 12),
        const Text(
          '잔고등록을 잘 마쳤습니다',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: _kTossInk,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          '우리 모임은 연회비를 걷나요? 월회비를 걷나요?',
          style: TextStyle(
            fontSize: 16,
            height: 1.5,
            color: _kTossGray,
          ),
        ),
        const SizedBox(height: 28),
        _ChoiceCard(
          title: '연회비를 걷어요',
          subtitle: '1년에 한 번 회비를 걷습니다. 금액과 납부일을 바로 넣을 수 있어요.',
          onTap: () => widget.onFinished(DuesType.annual, _mode!),
        ),
        const SizedBox(height: 12),
        _ChoiceCard(
          title: '월회비를 걷어요',
          subtitle: '매달 회비를 걷습니다. 금액과 납부 기간을 바로 넣을 수 있어요.',
          onTap: () => widget.onFinished(DuesType.monthly, _mode!),
        ),
      ],
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _ChoiceCard({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, 18, 16, 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _kTossLine),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _kTossInk,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        color: _kTossGray,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: _kTossBlue),
            ],
          ),
        ),
      ),
    );
  }
}

/// 회비 설정 직후 — 수입/지출을 지금 넣을지
class TreasurerTxPromptScreen extends StatelessWidget {
  final VoidCallback onEnter;
  final VoidCallback onLater;
  const TreasurerTxPromptScreen({
    super.key,
    required this.onEnter,
    required this.onLater,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 52, 22, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '회비설정을 잘 마쳤어요',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: _kTossInk,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                '지금 수입/지출 내역을 입력하시겠어요?',
                style: TextStyle(
                  fontSize: 16,
                  height: 1.5,
                  color: _kTossGray,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: onEnter,
                  style: FilledButton.styleFrom(
                    backgroundColor: _kTossInk,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    textStyle: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  child: const Text('입력하기'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: onLater,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _kTossInk,
                    side: const BorderSide(color: _kTossLine),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    textStyle: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  child: const Text('나중에 하기'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
