import 'package:flutter/material.dart';

import '../../models/club_model.dart';
import '../../providers/club_provider.dart';
import '../../theme/app_theme.dart';

/// 회비납부 탭에서 연다. 지금 보고 있는 회비 + 그 월·해만.
void showPaymentReminderSheet(
  BuildContext context,
  ClubProvider provider, {
  required DuesSetting setting,
  required int year,
  int? month,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _PaymentReminderSheet(
      provider: provider,
      setting: setting,
      year: year,
      month: month,
    ),
  );
}

class _PaymentReminderSheet extends StatefulWidget {
  final ClubProvider provider;
  final DuesSetting setting;
  final int year;
  final int? month;

  const _PaymentReminderSheet({
    required this.provider,
    required this.setting,
    required this.year,
    this.month,
  });

  @override
  State<_PaymentReminderSheet> createState() => _PaymentReminderSheetState();
}

class _PaymentReminderSheetState extends State<_PaymentReminderSheet> {
  int _step = 0;
  final Set<String> _selectedMemberIds = {};

  ClubProvider get pv => widget.provider;

  List<DuesReminderUnpaidRow> get _unpaidRows => pv.reminderUnpaidMembers(
        widget.setting,
        year: widget.year,
        month: widget.month,
      );

  List<Member> get _unpaidMembers =>
      _unpaidRows.map((e) => e.member).toList();

  @override
  void initState() {
    super.initState();
    _selectedMemberIds.addAll(_unpaidMembers.map((m) => m.id));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
          0, 12, 0, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                if (_step > 0)
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios, size: 16),
                    onPressed: () => setState(() => _step--),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                if (_step > 0) const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _step == 0 ? '미납자 선택' : '발송 확인',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 20, color: Color(0xFFEEEEEE)),
          if (_step == 0) _buildStep0(),
          if (_step == 1) _buildStep1(),
        ],
      ),
    );
  }

  Widget _buildStep0() {
    final unpaid = _unpaidMembers;
    if (unpaid.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.check_circle, size: 40, color: AppColors.success),
            SizedBox(height: 8),
            Text('모든 회원이 납부했습니다',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text('미납자 ${unpaid.length}명',
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondary)),
              const Spacer(),
              TextButton(
                onPressed: () {
                  setState(() {
                    if (_selectedMemberIds.length == unpaid.length) {
                      _selectedMemberIds.clear();
                    } else {
                      _selectedMemberIds.addAll(unpaid.map((m) => m.id));
                    }
                  });
                },
                child: Text(
                  _selectedMemberIds.length == unpaid.length
                      ? '전체 해제'
                      : '전체 선택',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 240),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: unpaid.length,
            itemBuilder: (_, i) {
              final row = _unpaidRows[i];
              final m = row.member;
              final sel = _selectedMemberIds.contains(m.id);
              return CheckboxListTile(
                value: sel,
                onChanged: (_) {
                  setState(() {
                    if (sel) {
                      _selectedMemberIds.remove(m.id);
                    } else {
                      _selectedMemberIds.add(m.id);
                    }
                  });
                },
                title: Text(m.name,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500)),
                subtitle: Text(row.periodLabel,
                    style: const TextStyle(fontSize: 11)),
                secondary: CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.danger.withValues(alpha: 0.12),
                  child: Text(m.name[0],
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.danger)),
                ),
                activeColor: AppColors.primary,
                controlAffinity: ListTileControlAffinity.trailing,
                dense: true,
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _selectedMemberIds.isEmpty
                  ? null
                  : () => setState(() => _step = 1),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('${_selectedMemberIds.length}명에게 독촉 보내기',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _buildStep1() {
    final names = _unpaidMembers
        .where((m) => _selectedMemberIds.contains(m.id))
        .map((m) => m.name)
        .join(', ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.notifications_active_outlined,
                        size: 16, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text('${widget.setting.title} 납부 독촉',
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary)),
                  ],
                ),
                const SizedBox(height: 8),
                Text('대상: $names', style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 4),
                Text('총 ${_selectedMemberIds.length}명에게 알림톡이 발송됩니다.',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () {
                pv.sendDuesNudge(
                  memberIds: _selectedMemberIds.toList(),
                  duesTitle: widget.setting.title,
                );
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        '${_selectedMemberIds.length}명에게 납부 독촉 알림을 발송했습니다.'),
                    backgroundColor: AppColors.primary,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                );
              },
              icon: const Icon(Icons.send_outlined, size: 18),
              label: const Text('발송하기',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
