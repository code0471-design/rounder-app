import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/club_model.dart';
import '../../models/member_role.dart';
import '../../providers/club_provider.dart';
import '../../theme/app_theme.dart';

// ════════════════════════════════════════════════════════════
//  TreasurerTransferScreen — 총무 인수인계
//  · 현 총무가 새 총무를 선택
//  · 체크리스트 확인 후 역할 교체
// ════════════════════════════════════════════════════════════
class TreasurerTransferScreen extends StatefulWidget {
  const TreasurerTransferScreen({super.key});

  @override
  State<TreasurerTransferScreen> createState() =>
      _TreasurerTransferScreenState();
}

class _TreasurerTransferScreenState extends State<TreasurerTransferScreen> {
  String? _selectedNewTreasurerId;
  final Map<String, bool> _checklist = {
    '회비 장부 인수인계': false,
    '회원 명단 전달': false,
    '미납 회원 현황 공유': false,
    // '후원사 연락처 공유': false,
    '모임 계좌 권한 이전': false,
  };
  bool _confirmed = false;

  bool get _allChecked =>
      _checklist.values.every((v) => v) &&
      _selectedNewTreasurerId != null;

  @override
  Widget build(BuildContext context) {
    return Consumer<ClubProvider>(
      builder: (context, provider, _) {
        if (!provider.canAccessTreasurerTransfer) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('총무·회장만 접근할 수 있습니다. (공석 시 부회장 포함)'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final vacantAppoint = provider.isSelectedTreasurerVacant ||
            !provider.hasActiveTreasurer();
        final me = provider.currentMember;

        // 총무 공석/최초 선임: 본인(회장 등)도 총무로 선택 가능
        final members = provider.members
            .where((m) {
              if (m.status != '활성') return false;
              if (m.memberType == ClubMemberRole.guest) return false;
              if (ClubMemberRole.isTreasurer(m.role)) return false;
              final isSelf = m.id == provider.currentUserId ||
                  m.id == me?.id ||
                  m.id == 'm_creator_${provider.selectedClub.id}';
              if (isSelf) return vacantAppoint; // 본인 선임은 공석일 때만
              return true;
            })
            .toList();

        final currentTreasurer = provider.members
            .where((m) => ClubMemberRole.isTreasurer(m.role))
            .firstOrNull;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.primaryDark,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new,
                  color: Colors.white, size: 18),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              vacantAppoint ? '총무 선임' : '총무 인수인계',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold),
            ),
          ),
          body: _confirmed
              ? _buildSuccess(currentTreasurer, provider)
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // ── 안내 배너 ──
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primaryDark, AppColors.primary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Text('🔑', style: TextStyle(fontSize: 20)),
                              SizedBox(width: 8),
                              Text(
                                '총무 인수인계 절차',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '새 총무를 선택하고 체크리스트를 완료하면\n권한이 자동으로 이전됩니다.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 12,
                              height: 1.5,
                            ),
                          ),
                          if (currentTreasurer != null) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '현 총무: ${currentTreasurer.name}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── 새 총무 선택 ──
                    const Text(
                      '새 총무 선택',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '인수인계할 회원을 선택해 주세요',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade500),
                    ),
                    const SizedBox(height: 12),
                    ...members.map((m) => _MemberSelectCard(
                          member: m,
                          selected: _selectedNewTreasurerId == m.id,
                          onTap: () => setState(
                              () => _selectedNewTreasurerId = m.id),
                        )),
                    const SizedBox(height: 20),

                    // ── 인수인계 체크리스트 ──
                    const Text(
                      '인수인계 체크리스트',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '모든 항목을 완료해야 인수인계가 가능합니다',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade500),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: _checklist.entries.map((entry) {
                          final isLast =
                              entry.key == _checklist.keys.last;
                          return Column(
                            children: [
                              CheckboxListTile(
                                value: entry.value,
                                onChanged: (v) => setState(() =>
                                    _checklist[entry.key] = v ?? false),
                                title: Text(
                                  entry.key,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: entry.value
                                        ? AppColors.primary
                                        : AppColors.textPrimary,
                                    fontWeight: entry.value
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                    decoration: entry.value
                                        ? TextDecoration.lineThrough
                                        : null,
                                    decorationColor: AppColors.primary,
                                  ),
                                ),
                                secondary: entry.value
                                    ? const Icon(Icons.check_circle,
                                        color: AppColors.success, size: 20)
                                    : Icon(Icons.radio_button_unchecked,
                                        color: Colors.grey.shade300,
                                        size: 20),
                                activeColor: AppColors.primary,
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 4),
                              ),
                              if (!isLast)
                                Divider(
                                    height: 1,
                                    color: Colors.grey.shade100,
                                    indent: 14,
                                    endIndent: 14),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── 진행률 표시 ──
                    _buildProgress(),

                    const SizedBox(height: 20),

                    // ── 인수인계 버튼 ──
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _allChecked
                            ? () => _showConfirmDialog(
                                context, provider, members)
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey.shade200,
                          disabledForegroundColor: Colors.grey.shade400,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(
                          _allChecked
                              ? '인수인계 완료하기 🔑'
                              : '체크리스트를 모두 완료해 주세요',
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildProgress() {
    final checkedCount =
        _checklist.values.where((v) => v).length;
    final total = _checklist.length;
    final ratio = checkedCount / total;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '진행률',
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Text(
                '$checkedCount / $total 완료',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: ratio == 1.0
                      ? AppColors.success
                      : AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              backgroundColor: Colors.grey.shade100,
              valueColor: AlwaysStoppedAnimation<Color>(
                ratio == 1.0 ? AppColors.success : AppColors.primary,
              ),
              minHeight: 8,
            ),
          ),
          if (_selectedNewTreasurerId == null) ...[
            const SizedBox(height: 8),
            Text(
              '⚠️ 새 총무를 먼저 선택해 주세요',
              style: TextStyle(fontSize: 11, color: Colors.orange.shade600),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSuccess(Member? currentTreasurer, ClubProvider provider) {
    final newTreasurer = _selectedNewTreasurerId != null
        ? provider.members
            .where((m) => m.id == _selectedNewTreasurerId)
            .firstOrNull
        : null;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle,
                  color: AppColors.success, size: 48),
            ),
            const SizedBox(height: 20),
            const Text(
              '인수인계 완료!',
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (newTreasurer != null)
              Text(
                '${newTreasurer.name}님이 새 총무가 되었습니다.',
                style: const TextStyle(
                    fontSize: 14, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 32, vertical: 14),
              ),
              child: const Text('확인',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showConfirmDialog(
      BuildContext context, ClubProvider provider, List<Member> members) {
    final newMember = members
        .where((m) => m.id == _selectedNewTreasurerId)
        .firstOrNull;
    if (newMember == null) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('인수인계 확인',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('아래 회원에게 총무 권한을 이전합니다.'),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor:
                        AppColors.primary.withValues(alpha: 0.15),
                    child: Text(
                      newMember.name[0],
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(newMember.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      Text(newMember.role,
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary)),
                    ],
                  ),
                  const Spacer(),
                  const Icon(Icons.arrow_forward,
                      color: AppColors.primary, size: 18),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('총무',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              final currentTreasurer = provider.members
                  .where((m) => ClubMemberRole.isTreasurer(m.role))
                  .firstOrNull;
              provider.transferTreasurer(
                // 공석 선임 시 빈 값 — 회장을 전 총무로 오인·강등하지 않음
                currentTreasurerId: currentTreasurer?.id ?? '',
                newTreasurerId: _selectedNewTreasurerId!,
              );
              Navigator.pop(ctx);
              setState(() => _confirmed = true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('인수인계 확인'),
          ),
        ],
      ),
    );
  }
}

class _MemberSelectCard extends StatelessWidget {
  final Member member;
  final bool selected;
  final VoidCallback onTap;

  const _MemberSelectCard({
    required this.member,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.06)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.4)
                : Colors.grey.shade200,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: selected
                  ? AppColors.primary.withValues(alpha: 0.15)
                  : Colors.grey.shade100,
              child: Text(
                member.name[0],
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: selected ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: selected
                          ? AppColors.primary
                          : AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    '${member.role} · ${member.memberType}',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle,
                  color: AppColors.primary, size: 22)
            else
              Icon(Icons.radio_button_unchecked,
                  color: Colors.grey.shade300, size: 22),
          ],
        ),
      ),
    );
  }
}
