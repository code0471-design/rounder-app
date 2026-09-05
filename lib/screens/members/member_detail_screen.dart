import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../domain/services/attendance_stats.dart';
import '../../models/club_model.dart';
import '../../models/member_role.dart';
import '../../navigation/app_navigator.dart';
import '../../providers/club_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/avatar_image.dart';
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
          backgroundColor: AppColors.charcoal,
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
    // 예전엔 96px 그라데이션 배너 + 그 위에 겹친 아바타 + 52px 여백이라
    // 이름이 화면 한참 아래에서 시작했다. 가로 한 줄로 접는다.
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new,
                color: AppColors.textSecondary, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  _buildAvatar(radius: 34, fontSize: 22),
                  if (member.status == '활성' &&
                      member.id == provider.currentUserId)
                    Positioned(
                      bottom: -2,
                      right: -2,
                      child: GestureDetector(
                        onTap: () => _showPhotoEditDialog(context),
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: AppColors.sand, width: 1.5),
                            boxShadow: AppShadows.soft,
                          ),
                          child: const Icon(Icons.camera_alt_rounded,
                              color: AppColors.charcoal, size: 13),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            member.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.ink,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (member.status == '탈퇴') ...[
                          const SizedBox(width: 8),
                          _StatusBadge(
                              label: '탈퇴', color: AppColors.danger),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (ClubMemberRole.isOfficer(member.role))
                          _ChipBadge(
                              label: member.role,
                              bg: AppColors.cream2,
                              fg: AppColors.goldDeep),
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
        ),
      ],
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.06),
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
          _InfoRow(
              icon: Icons.person_rounded,
              label: '성별',
              value: member.gender),
        if (member.birthDate != null)
          _InfoRow(
            icon: Icons.cake_rounded,
            label: '생년월일',
            value: '${_fullDate(member.birthDate!)} (${member.age}세)',
          ),
        // 연락처는 명단 내보내기와 같은 기준으로 임원에게만 보여 준다.
        if (provider.isClubExecutive &&
            member.phone != null &&
            member.phone!.isNotEmpty)
          _InfoRow(
              icon: Icons.phone_rounded,
              label: '연락처',
              value: member.phone!),
        if (member.address != null && member.address!.isNotEmpty)
          _InfoRow(
              icon: Icons.location_on_rounded,
              label: '주소',
              value: member.address!),
        if (member.memo != null && member.memo!.isNotEmpty)
          _InfoRow(
              icon: Icons.notes_rounded,
              label: '메모',
              value: member.memo!),
        _InfoRow(
          icon: Icons.verified_rounded,
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
    final stats = AttendanceStats.forMember(
      schedules: provider.schedules,
      clubId: clubId,
      memberId: member.id,
    );

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

    return _Card(
      title: '활동 기록',
      icon: Icons.bar_chart_rounded,
      children: [
        _InfoRow(
            icon: Icons.golf_course_rounded,
            label: '참석 라운딩',
            value: stats.finished == 0
                ? '지난 라운딩 없음'
                : '${stats.attended}회 / 지난 ${stats.finished}회'),
        _InfoRow(
            icon: Icons.percent_rounded,
            label: '참석률',
            value: stats.ratePercent == null ? '-' : '${stats.ratePercent}%'),
        _InfoRow(
            icon: Icons.payments_rounded,
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
          backgroundColor: AppColors.charcoal,
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
    // 갤러리 사진은 data URI — NetworkImage 로는 안 그려진다.
    final img = avatarImage(member.photoUrl);
    if (img != null) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: img,
        onBackgroundImageError: (_, __) {},
        backgroundColor: AppColors.cream2,
      );
    }
    // 그린은 로고 헤더·하단 탭바 전용 — 임원은 딥골드로 구분한다.
    return CircleAvatar(
      radius: radius,
      backgroundColor:
          isOfficer ? AppColors.cream2 : AppColors.surfaceVariant,
      child: Text(
        member.name.isNotEmpty ? member.name[0] : '?',
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: isOfficer ? AppColors.goldDeep : AppColors.textPrimary,
        ),
      ),
    );
  }

  // ────────────────────────────────
  // 프로필 사진 편집 다이얼로그
  // ────────────────────────────────
  void _showPhotoEditDialog(BuildContext context) {
    // 예전엔 "사진 URL을 입력하세요" 텍스트 필드였다. 폰에서 쓸 수 없다.
    // 마이페이지 편집과 같은 방식으로 갤러리에서 고른다.
    String? photo = member.photoUrl;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          Future<void> pick() async {
            try {
              final picked = await ImagePicker().pickImage(
                source: ImageSource.gallery,
                maxWidth: 720,
                maxHeight: 720,
                imageQuality: 80,
              );
              if (picked == null) return;
              final bytes = await picked.readAsBytes();
              setS(() =>
                  photo = 'data:image/jpeg;base64,${base64Encode(bytes)}');
            } catch (_) {
              if (!ctx.mounted) return;
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(content: Text('사진을 불러오지 못했습니다')),
              );
            }
          }

          final preview = avatarImage(photo);
          // 홈 인디케이터에 버튼이 깔리지 않게 safe area 를 더한다.
          final safeBottom = MediaQuery.viewPaddingOf(ctx).bottom;

          return Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, safeBottom + 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Center(
                  child: Text(
                    '프로필 사진',
                    style:
                        TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 18),
                Center(
                  child: GestureDetector(
                    onTap: pick,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CircleAvatar(
                          radius: 46,
                          backgroundColor: AppColors.cream2,
                          backgroundImage: preview,
                          onBackgroundImageError:
                              preview == null ? null : (_, __) {},
                          child: preview == null
                              ? Text(
                                  member.name.isNotEmpty
                                      ? member.name[0]
                                      : '?',
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.goldDeep,
                                  ),
                                )
                              : null,
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: AppColors.charcoal,
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(Icons.camera_alt_rounded,
                                color: Colors.white, size: 15),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text('사진을 눌러 갤러리에서 선택',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade500)),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          side: const BorderSide(color: AppColors.divider),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        child: const Text('취소',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          provider.updateMember(
                              member.copyWith(clearPhoto: true));
                          Navigator.pop(ctx);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.danger,
                          side: const BorderSide(color: AppColors.divider),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        child: const Text('삭제',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () {
                          provider.updateMember(member.copyWith(
                            photoUrl: photo,
                            clearPhoto: photo == null || photo!.isEmpty,
                          ));
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('프로필 사진이 업데이트되었습니다'),
                              backgroundColor: AppColors.charcoal,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.charcoal,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 13),
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
          Icon(icon, size: 20, color: AppColors.goldDeep),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 3),
          Text(label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              )),
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Icon(icon, size: 16, color: AppColors.goldDeep),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 4),
          ...children,
          const SizedBox(height: 10),
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: AppColors.cream2,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 15, color: AppColors.goldDeep),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 76,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: valueColor ?? AppColors.ink,
                fontWeight: FontWeight.w700,
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
