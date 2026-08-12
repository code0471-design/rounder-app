import 'package:flutter/material.dart';
import '../../../models/club_model.dart';
import '../../../theme/app_theme.dart';

class AttendanceStatusWidget extends StatelessWidget {
  final AttendanceStatus status;

  const AttendanceStatusWidget({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showAttendanceDetail(context),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더
            Row(
              children: [
                Container(
                  width: 4, height: 16,
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  '참석 현황',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                Text(
                  '총 ${status.total}명',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 숫자 통계 (배경색 없이 깔끔하게)
            IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          '${status.confirmed}명',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.success,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text('참석',
                            style: TextStyle(fontSize: 12, color: Color(0xFF999999))),
                      ],
                    ),
                  ),
                  Container(width: 1, color: const Color(0xFFEEEEEE)),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          '${status.noResponse}명',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text('미답변',
                            style: TextStyle(fontSize: 12, color: Color(0xFF999999))),
                      ],
                    ),
                  ),
                  Container(width: 1, color: const Color(0xFFEEEEEE)),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          '${status.declined}명',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.danger,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text('불참',
                            style: TextStyle(fontSize: 12, color: Color(0xFF999999))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // 상세보기
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '상세 보기 >',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAttendanceDetail(BuildContext context) {
    // mock 멤버 데이터 (실제는 provider에서)
    final confirmed = [
      _AttendMember('홍길동', '남', '정회원', '회장', Icons.sports_golf),
      _AttendMember('김철수', '남', '정회원', '부회장', Icons.sports_golf),
      _AttendMember('이영희', '여', '정회원', '총무', Icons.sports_golf),
      _AttendMember('박민준', '남', '정회원', '일반', Icons.sports_golf),
      _AttendMember('강동원', '남', '정회원', '일반', Icons.sports_golf),
      _AttendMember('윤서준', '남', '정회원', '일반', Icons.sports_golf),
      _AttendMember('이준호', '남', '정회원', '일반', Icons.sports_golf),
      _AttendMember('김지수', '여', '정회원', '일반', Icons.sports_golf),
    ];
    final noResponse = [
      _AttendMember('정다은', '여', '정회원', '일반', Icons.help_outline),
      _AttendMember('최수연', '여', '정회원', '일반', Icons.help_outline),
    ];
    final declined = [
      _AttendMember('오세훈', '남', '준회원', '일반', Icons.cancel_outlined),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (_, scrollCtrl) => _AttendanceDetailSheet(
          controller: scrollCtrl,
          confirmed: confirmed,
          noResponse: noResponse,
          declined: declined,
        ),
      ),
    );
  }

  Widget _buildStatusChip({
    required String label,
    required int count,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text('$label: $count명',
              style: TextStyle(
                  fontSize: 12, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ── 멤버 데이터 클래스 ─────────────────────────────────────
class _AttendMember {
  final String name;
  final String gender;
  final String memberType;
  final String role;
  final IconData icon;
  const _AttendMember(this.name, this.gender, this.memberType, this.role, this.icon);
}

// ── 참석현황 상세 바텀시트 ──────────────────────────────────
class _AttendanceDetailSheet extends StatelessWidget {
  final ScrollController controller;
  final List<_AttendMember> confirmed;
  final List<_AttendMember> noResponse;
  final List<_AttendMember> declined;

  const _AttendanceDetailSheet({
    required this.controller,
    required this.confirmed,
    required this.noResponse,
    required this.declined,
  });

  @override
  Widget build(BuildContext context) {
    final total = confirmed.length + noResponse.length + declined.length;

    return Column(
      children: [
        // 핸들
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
          child: Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
        // 헤더
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
          child: Row(
            children: [
              const Icon(Icons.people, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              const Text('참석 현황',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E1B4B))),
              const Spacer(),
              Text('총 $total명',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
            ],
          ),
        ),
        // 요약 바
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Row(
            children: [
              _SummaryChip('참석 ${confirmed.length}', AppColors.success),
              const SizedBox(width: 8),
              _SummaryChip('미답변 ${noResponse.length}', AppColors.textSecondary),
              const SizedBox(width: 8),
              _SummaryChip('불참 ${declined.length}', AppColors.danger),
            ],
          ),
        ),
        const Divider(height: 1),
        // 리스트
        Expanded(
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              if (confirmed.isNotEmpty) ...[
                _GroupHeader('✅ 참석', confirmed.length, AppColors.success),
                ...confirmed.map((m) => _MemberRow(m, AppColors.success)),
                const SizedBox(height: 12),
              ],
              if (noResponse.isNotEmpty) ...[
                _GroupHeader('⏳ 미답변', noResponse.length, AppColors.textSecondary),
                ...noResponse.map((m) => _MemberRow(m, AppColors.textSecondary)),
                const SizedBox(height: 12),
              ],
              if (declined.isNotEmpty) ...[
                _GroupHeader('❌ 불참', declined.length, AppColors.danger),
                ...declined.map((m) => _MemberRow(m, AppColors.danger)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final Color color;
  const _SummaryChip(this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12, color: color, fontWeight: FontWeight.w600)),
      );
}

class _GroupHeader extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _GroupHeader(this.label, this.count, this.color);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 6, 0, 6),
        child: Text('$label ($count명)',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: color)),
      );
}

class _MemberRow extends StatelessWidget {
  final _AttendMember member;
  final Color color;
  const _MemberRow(this.member, this.color);
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  member.name.characters.first,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: color),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(member.name,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600,
                          color: Color(0xFF1E1B4B))),
                  Text('${member.role} · ${member.memberType} · ${member.gender}',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade500)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                color == AppColors.success
                    ? '참석'
                    : color == AppColors.danger
                        ? '불참'
                        : '미답변',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: color),
              ),
            ),
          ],
        ),
      );
}
