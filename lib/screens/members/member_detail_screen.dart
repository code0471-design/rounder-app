import 'package:flutter/material.dart';
import '../../models/club_model.dart';
import '../../models/member_role.dart';
import '../../navigation/app_navigator.dart';
import '../../providers/club_provider.dart';
import '../../theme/app_theme.dart';
import 'member_form_screen.dart';
import 'treasurer_transfer_screen.dart';

class MemberDetailScreen extends StatelessWidget {
  final Member member;
  final ClubProvider provider;

  const MemberDetailScreen({
    super.key,
    required this.member,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    final canEditRole = provider.isClubExecutive && member.status == '활성';
    final canKick = provider.isClubExecutive &&
        member.id != provider.currentUserId &&
        member.status == '활성';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildProfileHeaderCard(context),
              _buildProfileSection(context),
              const SizedBox(height: 12),
              _buildInfoCard(context),
              const SizedBox(height: 12),
              _buildActivityCard(context),
              const SizedBox(height: 24),
              if (canEditRole) ...[
                _buildEditRoleButton(context),
                const SizedBox(height: 12),
              ],
              if (member.status == '활성' &&
                  ClubMemberRole.isTreasurer(member.role) &&
                  provider.canAccessTreasurerTransfer)
                _buildTreasurerTransferButton(context),
              if (member.status == '활성' &&
                  ClubMemberRole.isTreasurer(member.role) &&
                  provider.canAccessTreasurerTransfer)
                const SizedBox(height: 12),
              if (canKick) ...[
                _buildKickButton(context),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEditRoleButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ElevatedButton.icon(
        onPressed: () => _navigateToEdit(context),
        icon: const Icon(Icons.military_tech_outlined, size: 18),
        label: const Text(
          '직책·회원 정보 수정',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 46),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _buildProfileHeaderCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.card,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              Container(
                height: 96,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.sageLighter,
                      AppColors.surfaceVariant,
                    ],
                  ),
                ),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new,
                        color: AppColors.textSecondary, size: 18),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
              Positioned(
                top: 56,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        shape: BoxShape.circle,
                        boxShadow: AppShadows.soft,
                      ),
                      child: _buildAvatar(radius: 38, fontSize: 24),
                    ),
                    if (member.status == '활성' &&
                        member.id == provider.currentUserId)
                      Positioned(
                        bottom: 2,
                        right: 2,
                        child: GestureDetector(
                          onTap: () => _showPhotoEditDialog(context),
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: AppColors.primary, width: 1.5),
                              boxShadow: AppShadows.soft,
                            ),
                            child: const Icon(Icons.camera_alt,
                                color: AppColors.primary, size: 14),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 52),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      member.name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (member.status == '탈퇴') ...[
                      const SizedBox(width: 8),
                      _StatusBadge(
                          label: '탈퇴', color: AppColors.danger),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (ClubMemberRole.isOfficer(member.role))
                      _ChipBadge(
                          label: member.role,
                          bg: AppColors.sageLighter,
                          fg: AppColors.sageDarker),
                    _ChipBadge(
                        label: member.memberType,
                        bg: AppColors.surfaceVariant,
                        fg: AppColors.textSecondary),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────
  // 프로필 요약 카드 (핵심 수치)
  // ────────────────────────────────
  Widget _buildProfileSection(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _StatItem(
            icon: Icons.sports_golf,
            label: '핸디캡',
            value: member.handicap != null
                ? member.handicap!.toStringAsFixed(0)
                : '-',
          ),
          _Divider(),
          _StatItem(
            icon: Icons.cake_outlined,
            label: '나이',
            value: member.age > 0 ? '${member.age}세' : '-',
          ),
          _Divider(),
          _StatItem(
            icon: Icons.event_available_outlined,
            label: '가입',
            value: member.joinDate != null
                ? _ymd(member.joinDate!)
                : '-',
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────
  // 상세 정보 카드
  // ────────────────────────────────
  Widget _buildInfoCard(BuildContext context) {
    return _Card(
      title: '상세 정보',
      icon: Icons.info_outline,
      children: [
        if (member.gender.isNotEmpty)
          _InfoRow(icon: Icons.person_outline, label: '성별', value: member.gender),
        if (member.birthDate != null)
          _InfoRow(
            icon: Icons.cake_outlined,
            label: '생년월일',
            value:
                '${_fullDate(member.birthDate!)} (${member.age}세)',
          ),
        if (member.address != null && member.address!.isNotEmpty)
          _InfoRow(
              icon: Icons.location_on_outlined,
              label: '주소',
              value: member.address!),
        if (member.memo != null && member.memo!.isNotEmpty)
          _InfoRow(
              icon: Icons.notes_outlined,
              label: '메모',
              value: member.memo!),
        _InfoRow(
          icon: Icons.circle,
          label: '상태',
          value: member.status,
          valueColor:
              member.status == '활성' ? AppColors.success : AppColors.danger,
        ),
      ],
    );
  }

  // ────────────────────────────────
  // 활동 기록 카드 (실제 일정·회비 기준)
  // ────────────────────────────────
  Widget _buildActivityCard(BuildContext context) {
    final clubId = provider.selectedClub.id;
    final attendCount = provider.schedules
        .where((s) => s.clubId == clubId)
        .where((s) => s.responses.any(
            (r) => r.memberId == member.id && r.response == '참석'))
        .length;
    final now = DateTime.now();
    final monthly = provider.currentMonthDuesSetting(now.year, now.month);
    final paidThisMonth = monthly == null
        ? true
        : provider.duesPayments.any((p) =>
            p.memberId == member.id &&
            p.duesSettingId == monthly.id &&
            p.paidAt.year == now.year &&
            p.paidAt.month == now.month);
    final duesLabel = monthly == null
        ? '해당 없음'
        : (paidThisMonth ? '납부 완료' : '미납');
    final duesColor = monthly == null
        ? AppColors.textSecondary
        : (paidThisMonth ? AppColors.success : AppColors.danger);
    final handicap = member.handicap;
    final scoreLabel =
        handicap != null ? handicap.toStringAsFixed(1) : '-';

    return _Card(
      title: '활동 기록',
      icon: Icons.bar_chart_outlined,
      children: [
        _InfoRow(
            icon: Icons.golf_course,
            label: '참석 라운딩',
            value: '$attendCount회'),
        _InfoRow(
            icon: Icons.analytics_outlined,
            label: '핸디캡',
            value: scoreLabel),
        _InfoRow(
            icon: Icons.payments_outlined,
            label: '이번 달 회비',
            value: duesLabel,
            valueColor: duesColor),
      ],
    );
  }

  // ────────────────────────────────
  // 총무 인수인계 버튼
  // ────────────────────────────────
  Widget _buildTreasurerTransferButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ElevatedButton.icon(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const TreasurerTransferScreen(),
          ),
        ),
        icon: const Icon(Icons.swap_horiz_rounded, size: 18),
        label: const Text(
          '총무 인수인계',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 46),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 0,
        ),
      ),
    );
  }

  // ────────────────────────────────
  // 탈퇴 처리 버튼
  // ────────────────────────────────
  Widget _buildDeactivateButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: OutlinedButton.icon(
        onPressed: () => _confirmDeactivate(context),
        icon: const Icon(Icons.person_off_outlined, color: AppColors.danger, size: 18),
        label: const Text(
          '탈퇴 처리',
          style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.danger),
          minimumSize: const Size(double.infinity, 46),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  // ────────────────────────────────
  // 강퇴 처리 버튼 (총무 전용)
  // ────────────────────────────────
  Widget _buildKickButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ElevatedButton.icon(
        onPressed: () => _confirmKick(context),
        icon: const Icon(Icons.block_outlined, size: 18),
        label: const Text(
          '강퇴 처리',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.danger,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 46),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 0,
        ),
      ),
    );
  }

  void _confirmKick(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('회원 강퇴',
            style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.danger)),
        content: Text(
          '${member.name}님을 모임에서 강퇴 처리하시겠습니까?\n\n'
          '강퇴 시 즉시 앱 푸시 알림이 발송되며, 모임에서 제외됩니다.',
          style: const TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              final name = member.name;
              provider.kickMember(member.id);
              Navigator.pop(ctx);
              Navigator.pop(context);
              final snackCtx = AppNavigator.context;
              if (snackCtx != null && snackCtx.mounted) {
                ScaffoldMessenger.of(snackCtx).showSnackBar(
                  SnackBar(
                    content: Text('$name님을 강퇴 처리하고 푸시 알림을 보냈습니다.'),
                    backgroundColor: AppColors.danger,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('강퇴 확정'),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────
  // 아바타
  // ────────────────────────────────
  Widget _buildAvatar({required double radius, required double fontSize}) {
    final isOfficer = ClubMemberRole.isOfficer(member.role);
    if (member.photoUrl != null && member.photoUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(member.photoUrl!),
        onBackgroundImageError: (_, __) {},
        backgroundColor: AppColors.sageLighter,
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor:
          isOfficer ? AppColors.sageLighter : AppColors.surfaceVariant,
      child: Text(
        member.name.isNotEmpty ? member.name[0] : '?',
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: isOfficer ? AppColors.sageDarker : AppColors.textPrimary,
        ),
      ),
    );
  }

  // ────────────────────────────────
  // 프로필 사진 편집 다이얼로그
  // ────────────────────────────────
  void _showPhotoEditDialog(BuildContext context) {
    final urlCtrl = TextEditingController(text: member.photoUrl ?? '');
    // 컬러 아바타 선택용
    final colors = [
      '🔵', '🟢', '🔴', '🟡', '🟠', '🟣', '⚫', '🟤',
    ];
    // 사진 URL 없을 때 미리보기 아바타 색상
    final avatarColors = [
      const Color(0xFF4CAF50),
      AppColors.mintMedium,
      const Color(0xFFE91E63),
      const Color(0xFFFF9800),
      const Color(0xFF9C27B0),
      const Color(0xFF00BCD4),
      const Color(0xFF795548),
      const Color(0xFF607D8B),
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final urlText = urlCtrl.text.trim();
          return Padding(
            padding: EdgeInsets.fromLTRB(
                20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 핸들
                Center(
                  child: Container(
                    width: 36, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '📸 프로필 사진 설정',
                  style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  '사진 URL을 입력하거나 컬러 아바타를 선택하세요',
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade500),
                ),
                const SizedBox(height: 16),

                // 미리보기
                Center(
                  child: urlText.isNotEmpty
                      ? CircleAvatar(
                          radius: 40,
                          backgroundImage: NetworkImage(urlText),
                          onBackgroundImageError: (_, __) {},
                          backgroundColor: Colors.grey.shade200,
                        )
                      : CircleAvatar(
                          radius: 40,
                          backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                          child: Text(
                            member.name.isNotEmpty ? member.name[0] : '?',
                            style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                ),
                const SizedBox(height: 16),

                // URL 입력
                const Text(
                  '사진 URL 입력',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: urlCtrl,
                  onChanged: (_) => setS(() {}),
                  decoration: InputDecoration(
                    hintText: 'https://example.com/photo.jpg',
                    hintStyle: TextStyle(
                        fontSize: 12, color: Colors.grey.shade400),
                    filled: true,
                    fillColor: AppColors.background,
                    suffixIcon: urlCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              urlCtrl.clear();
                              setS(() {});
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                          color: AppColors.primary, width: 1.5),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 버튼
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          // 사진 초기화
                          final updated = member.copyWith(photoUrl: '');
                          provider.updateMember(updated);
                          Navigator.pop(ctx);
                        },
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('초기화',
                            style: TextStyle(color: AppColors.textSecondary)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () {
                          final updated = member.copyWith(
                              photoUrl: urlCtrl.text.trim());
                          provider.updateMember(updated);
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('프로필 사진이 업데이트되었습니다'),
                              backgroundColor: AppColors.success,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('저장',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ────────────────────────────────
  // 네비게이션
  // ────────────────────────────────
  Future<void> _navigateToEdit(BuildContext context) async {
    final result = await Navigator.push<Member>(
      context,
      MaterialPageRoute(
        builder: (_) => MemberFormScreen(member: member),
      ),
    );
    if (result != null) {
      provider.updateMember(result);
      if (context.mounted) Navigator.pop(context);
    }
  }

  void _confirmDeactivate(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('탈퇴 처리',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          '${member.name}님을 탈퇴 처리하시겠습니까?\n\n기록은 유지되며, 목록에서는 숨겨집니다.',
          style: const TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              provider.deactivateMember(member.id);
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('탈퇴 처리'),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────
  // 날짜 헬퍼
  // ────────────────────────────────
  String _ymd(DateTime d) => '${d.year}.${_z(d.month)}.${_z(d.day)}';
  String _fullDate(DateTime d) =>
      '${d.year}.${_z(d.month)}.${_z(d.day)}';
  String _z(int n) => n.toString().padLeft(2, '0');
}

// ════════════════════════════════════════
// 재사용 위젯들
// ════════════════════════════════════════

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _StatItem(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 40,
      color: AppColors.divider,
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  const _Card(
      {required this.title, required this.icon, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Row(
              children: [
                Icon(icon, size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
          ...children,
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  const _InfoRow(
      {required this.icon,
      required this.label,
      required this.value,
      this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: valueColor ?? AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.bold)),
    );
  }
}

class _ChipBadge extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;
  const _ChipBadge(
      {required this.label, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 12,
              color: fg,
              fontWeight: FontWeight.w600)),
    );
  }
}
