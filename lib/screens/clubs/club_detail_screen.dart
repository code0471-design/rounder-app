import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/club_model.dart';
import '../../models/member_role.dart';
import '../../providers/club_provider.dart';
import '../../theme/app_theme.dart';
import '../ad/ad_screen.dart';
import '../sponsor/sponsor_screen.dart';

// ════════════════════════════════════════════════════════════
//  ClubDetailScreen — 모임 상세 + 가입신청 + 승인 관리
// ════════════════════════════════════════════════════════════
class ClubDetailScreen extends StatelessWidget {
  final Club club;
  final ClubProvider provider;

  const ClubDetailScreen({
    super.key,
    required this.club,
    required this.provider,
  });

  bool get _isAdmin =>
      ClubMemberRole.isOfficer(club.myRole);

  @override
  Widget build(BuildContext context) {
    return Consumer<ClubProvider>(
      builder: (context, prov, _) {
        final isMine    = prov.isMyClub(club.id);
        final isPending = prov.hasPendingRequest(club.id);
        final pending   = prov.pendingRequestsOf(club.id);

        return Scaffold(
          backgroundColor: AppColors.background,
          body: CustomScrollView(
            slivers: [
              _buildAppBar(context, prov, isMine, isPending),
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    _buildInfoCard(context, prov),
                    if (isMine && _isAdmin && pending.isNotEmpty)
                      _buildJoinRequestsCard(context, prov, pending),
                    _buildStatsCard(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ────────────────────────────────
  //  SliverAppBar
  // ────────────────────────────────
  Widget _buildAppBar(BuildContext context, ClubProvider prov,
      bool isMine, bool isPending) {
    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      backgroundColor: AppColors.primaryDark,
      iconTheme: const IconThemeData(color: Colors.white),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primaryDark, AppColors.primary],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding:
                  const EdgeInsets.fromLTRB(20, 52, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // 아이콘 + 이름
                  Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color:
                              Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: Text(
                            clubIndustryEmoji(club.industry),
                            style: const TextStyle(fontSize: 26),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(club.name,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(
                              '${club.region} · ${club.industry}',
                              style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // 통계 칩들
                  Wrap(
                    spacing: 8,
                    children: [
                      _HeaderChip(
                          icon: Icons.people_outline,
                          label: '${club.memberCount}명'),
                      _HeaderChip(
                          icon: Icons.sports_golf,
                          label: '${club.teamCount}팀'),
                      if (isMine)
                        _HeaderChip(
                            icon: Icons.military_tech,
                            label: club.myRole),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      // 가입 / 신청중 버튼
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(52),
        child: Container(
          color: AppColors.primaryDark,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: isMine
              ? _AdminBar(club: club, provider: prov)
              : isPending
                  ? _PendingBar()
                  : _JoinBar(club: club, provider: prov, context: context),
        ),
      ),
    );
  }

  // ────────────────────────────────
  //  모임 정보 카드
  // ────────────────────────────────
  Widget _buildInfoCard(BuildContext context, ClubProvider prov) {
    return _Card(
      margin: const EdgeInsets.fromLTRB(14, 14, 14, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(icon: Icons.info_outline, title: '모임 정보'),
          const Divider(height: 1, color: AppColors.divider),
          _InfoRow(icon: Icons.location_on_outlined,
              label: '지역', value: club.region),
          _InfoRow(icon: Icons.business_outlined,
              label: '업종', value: club.industry),
          _InfoRow(icon: Icons.people_outline,
              label: '회원 수', value: '${club.memberCount}명'),
          _InfoRow(icon: Icons.sports_golf,
              label: '팀 수', value: '${club.teamCount}팀'),
          _InfoRow(
            icon: Icons.calendar_today_outlined,
            label: '개설일',
            value: _ymd(club.createdAt),
          ),
          if (club.description.isNotEmpty) ...[
            const Divider(height: 1, color: AppColors.divider),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.notes_outlined,
                          size: 15, color: AppColors.textSecondary),
                      SizedBox(width: 6),
                      Text('모임 소개',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textSecondary)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(club.description,
                      style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textPrimary,
                          height: 1.6)),
                ],
              ),
            ),
          ],
          // 팀 수 수정 (관리자)
          if (provider.isMyClub(club.id) && _isAdmin) ...[
            const Divider(height: 1, color: AppColors.divider),
            _TeamCountEditor(club: club, provider: prov),
          ],
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  // ────────────────────────────────
  //  가입 신청 관리 카드 (관리자용)
  // ────────────────────────────────
  Widget _buildJoinRequestsCard(BuildContext context, ClubProvider prov,
      List<JoinRequest> pending) {
    return _Card(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
            icon: Icons.notifications_active_outlined,
            title: '가입 신청 대기 (${pending.length})',
            badgeCount: pending.length,
          ),
          const Divider(height: 1, color: AppColors.divider),
          ...pending.map((req) =>
              _JoinRequestTile(req: req, provider: prov, context: context)),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  // ────────────────────────────────
  //  통계 카드
  // ────────────────────────────────
  Widget _buildStatsCard() {
    return _Card(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardHeader(icon: Icons.bar_chart_outlined, title: '모임 현황'),
          const Divider(height: 1, color: AppColors.divider),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              children: [
                _StatItem(label: '총 라운딩', value: '24회'),
                _StatVDivider(),
                _StatItem(label: '평균 스코어', value: '86.4'),
                _StatVDivider(),
                _StatItem(label: '이달 예정', value: '1회'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _ymd(DateTime d) =>
      '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
}

// ════════════════════════════════════════
//  가입 신청 타일
// ════════════════════════════════════════
class _JoinRequestTile extends StatelessWidget {
  final JoinRequest req;
  final ClubProvider provider;
  final BuildContext context;
  const _JoinRequestTile(
      {required this.req,
      required this.provider,
      required this.context});

  @override
  Widget build(BuildContext ctx) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor:
                AppColors.primary.withValues(alpha: 0.12),
            child: Text(
              req.userName.isNotEmpty ? req.userName[0] : '?',
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(req.userName,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppColors.textPrimary)),
                    const SizedBox(width: 6),
                    Text(
                      '${req.userGender} · 핸디 ${req.userHandicap?.toStringAsFixed(0) ?? "-"}',
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary),
                    ),
                  ],
                ),
                if (req.message.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('"${req.message}"',
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontStyle: FontStyle.italic,
                          height: 1.4)),
                ],
                const SizedBox(height: 8),
                // 승인 버튼 행
                Row(
                  children: [
                    _ApproveBtn(
                      label: '정회원 승인',
                      color: AppColors.primary,
                      onTap: () => _approve(ctx, '정회원'),
                    ),
                    const SizedBox(width: 6),
                    _ApproveBtn(
                      label: '게스트 승인',
                      color: AppColors.warning,
                      onTap: () => _approve(ctx, '게스트'),
                    ),
                    const SizedBox(width: 6),
                    _ApproveBtn(
                      label: '거절',
                      color: AppColors.danger,
                      onTap: () => _reject(ctx),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _approve(BuildContext ctx, String memberType) {
    String role = memberType == '게스트' ? '게스트' : '정회원';
    showDialog(
      context: ctx,
      builder: (_) => StatefulBuilder(
        builder: (dCtx, setDlg) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: Text('${req.userName}님 승인',
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$memberType으로 승인합니다. 직책을 선택해 주세요.',
                  style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: role,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFFF7F8FA),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: const [
                  '회장',
                  '부회장',
                  '총무',
                  '정회원',
                  '게스트',
                ]
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setDlg(() => role = v);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dCtx),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () {
                provider.approveRequest(
                  req.id,
                  memberType: role == '게스트' ? '게스트' : '정회원',
                  role: role,
                );
                Navigator.pop(dCtx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        '${req.userName}님을 $role으로 승인했습니다.'),
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                );
              },
              child: const Text('승인'),
            ),
          ],
        ),
      ),
    );
  }

  void _reject(BuildContext ctx) {
    provider.rejectRequest(req.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${req.userName}님의 신청을 거절했습니다.'),
        backgroundColor: AppColors.danger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

// ════════════════════════════════════════
//  AppBar 하단 바 위젯들
// ════════════════════════════════════════
class _JoinBar extends StatelessWidget {
  final Club club;
  final ClubProvider provider;
  final BuildContext context;
  const _JoinBar(
      {required this.club,
      required this.provider,
      required this.context});

  @override
  Widget build(BuildContext ctx) {
    return Row(
      children: [
        // 가입 신청 버튼
        Expanded(
          child: SizedBox(
            height: 40,
            child: ElevatedButton.icon(
              onPressed: () => _showJoinDialog(ctx),
              icon: const Icon(Icons.person_add_outlined, size: 16),
              label: const Text('가입 신청',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        // 후원하기 버튼 (숨김)
        // GestureDetector(
        //   onTap: () => Navigator.push(
        //     ctx,
        //     MaterialPageRoute(
        //       builder: (_) => SponsorApplicationScreen(club: club),
        //     ),
        //   ),
        //   child: Container(
        //     height: 40,
        //     padding: const EdgeInsets.symmetric(horizontal: 10),
        //     decoration: BoxDecoration(
        //       color: const Color(0xFF4F46E5),
        //       borderRadius: BorderRadius.circular(10),
        //     ),
        //     child: const Row(
        //       children: [
        //         Icon(Icons.volunteer_activism, size: 14, color: Colors.white),
        //         SizedBox(width: 4),
        //         Text('후원하기',
        //             style: TextStyle(
        //                 color: Colors.white,
        //                 fontWeight: FontWeight.bold,
        //                 fontSize: 12)),
        //       ],
        //     ),
        //   ),
        // ),
        // const SizedBox(width: 6),
        // 광고 신청 버튼 (숨김)
        // GestureDetector(
        //   onTap: () => Navigator.push(
        //     ctx,
        //     MaterialPageRoute(
        //       builder: (_) => AdApplicationScreen(club: club),
        //     ),
        //   ),
        //   child: Container(
        //     height: 40,
        //     padding: const EdgeInsets.symmetric(horizontal: 10),
        //     decoration: BoxDecoration(
        //       color: const Color(0xFFFF6D00),
        //       borderRadius: BorderRadius.circular(10),
        //     ),
        //     child: const Row(
        //       children: [
        //         Icon(Icons.campaign_outlined, size: 14, color: Colors.white),
        //         SizedBox(width: 4),
        //         Text('광고 신청',
        //             style: TextStyle(
        //                 color: Colors.white,
        //                 fontWeight: FontWeight.bold,
        //                 fontSize: 12)),
        //       ],
        //     ),
        //   ),
        // ),
      ],
    );
  }

  void _showJoinDialog(BuildContext ctx) {
    final msgCtrl = TextEditingController();
    showDialog(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('${club.name} 가입 신청',
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('가입 신청 메시지를 남겨주세요. (선택)',
                style: TextStyle(
                    fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 10),
            TextField(
              controller: msgCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: '자기 소개나 신청 이유를 적어주세요...',
                hintStyle: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('취소',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              await provider.submitJoinRequest(
                  clubId: club.id, message: msgCtrl.text.trim());
              if (!dialogCtx.mounted) return;
              Navigator.pop(dialogCtx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Row(
                    children: [
                      Icon(Icons.check_circle,
                          color: Colors.white, size: 16),
                      SizedBox(width: 8),
                      Text('가입 신청이 완료되었습니다.',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
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
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('신청하기',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _PendingBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.hourglass_top,
              size: 16, color: AppColors.warning),
          SizedBox(width: 8),
          Text('가입 신청 대기 중',
              style: TextStyle(
                  color: AppColors.warning,
                  fontWeight: FontWeight.bold,
                  fontSize: 13)),
        ],
      ),
    );
  }
}

class _AdminBar extends StatelessWidget {
  final Club club;
  final ClubProvider provider;
  const _AdminBar({required this.club, required this.provider});

  @override
  Widget build(BuildContext context) {
    final pending = provider.pendingRequestsOf(club.id);
    return Row(
      children: [
        // 직책 표시
        Expanded(
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.admin_panel_settings_outlined,
                    size: 16, color: Colors.white),
                const SizedBox(width: 6),
                Text('${club.myRole} · 관리자',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
              ],
            ),
          ),
        ),
        // 후원하기 버튼 (숨김)
        // const SizedBox(width: 6),
        // GestureDetector(
        //   onTap: () => Navigator.push(
        //     context,
        //     MaterialPageRoute(
        //       builder: (_) => SponsorApplicationScreen(club: club),
        //     ),
        //   ),
        //   child: Container(
        //     height: 40,
        //     padding: const EdgeInsets.symmetric(horizontal: 10),
        //     decoration: BoxDecoration(
        //       color: const Color(0xFF4F46E5),
        //       borderRadius: BorderRadius.circular(10),
        //     ),
        //     child: const Row(
        //       children: [
        //         Icon(Icons.volunteer_activism, size: 14, color: Colors.white),
        //         SizedBox(width: 4),
        //         Text('후원하기',
        //             style: TextStyle(
        //                 color: Colors.white,
        //                 fontWeight: FontWeight.bold,
        //                 fontSize: 12)),
        //       ],
        //     ),
        //   ),
        // ),
        // 광고 신청하기 버튼 (숨김)
        // const SizedBox(width: 6),
        // GestureDetector(
        //   onTap: () => Navigator.push(
        //     context,
        //     MaterialPageRoute(
        //       builder: (_) => AdApplicationScreen(club: club),
        //     ),
        //   ),
        //   child: Container(
        //     height: 40,
        //     padding: const EdgeInsets.symmetric(horizontal: 10),
        //     decoration: BoxDecoration(
        //       color: const Color(0xFFFF6D00),
        //       borderRadius: BorderRadius.circular(10),
        //     ),
        //     child: const Row(
        //       children: [
        //         Icon(Icons.campaign_outlined, size: 14, color: Colors.white),
        //         SizedBox(width: 4),
        //         Text('광고 신청',
        //             style: TextStyle(
        //                 color: Colors.white,
        //                 fontWeight: FontWeight.bold,
        //                 fontSize: 12)),
        //       ],
        //     ),
        //   ),
        // ),
        if (pending.isNotEmpty) ...[
          const SizedBox(width: 8),
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.notifications_outlined,
                        size: 16, color: Colors.white),
                    SizedBox(width: 4),
                    Text('신청',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13)),
                  ],
                ),
              ),
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: const BoxDecoration(
                    color: AppColors.danger,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text('${pending.length}',
                        style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

// ════════════════════════════════════════
//  팀 수 수정 위젯 (관리자)
// ════════════════════════════════════════
class _TeamCountEditor extends StatefulWidget {
  final Club club;
  final ClubProvider provider;
  const _TeamCountEditor({required this.club, required this.provider});

  @override
  State<_TeamCountEditor> createState() => _TeamCountEditorState();
}

class _TeamCountEditorState extends State<_TeamCountEditor> {
  late int _count;

  @override
  void initState() {
    super.initState();
    _count = widget.club.teamCount;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          const Icon(Icons.people_outline,
              size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          const Text('이달 팀 수',
              style: TextStyle(
                  fontSize: 13, color: AppColors.textSecondary)),
          const Spacer(),
          GestureDetector(
            onTap: () {
              if (_count > 1) {
                setState(() => _count--);
                widget.provider.updateClubTeamCount(
                    widget.club.id, _count);
              }
            },
            child: _SmallBtn(icon: Icons.remove),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text('$_count팀',
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold,
                    color: AppColors.primary)),
          ),
          GestureDetector(
            onTap: () {
              if (_count < 30) {
                setState(() => _count++);
                widget.provider.updateClubTeamCount(
                    widget.club.id, _count);
              }
            },
            child: _SmallBtn(icon: Icons.add),
          ),
        ],
      ),
    );
  }
}

class _SmallBtn extends StatelessWidget {
  final IconData icon;
  const _SmallBtn({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.divider),
      ),
      child: Icon(icon, size: 14, color: AppColors.primary),
    );
  }
}

// ════════════════════════════════════════
//  공통 위젯들
// ════════════════════════════════════════
class _Card extends StatelessWidget {
  final Widget child;
  final EdgeInsets margin;
  const _Card({required this.child, required this.margin});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: child,
    );
  }
}

class _CardHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final int badgeCount;
  const _CardHeader(
      {required this.icon,
      required this.title,
      this.badgeCount = 0});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(title,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
          if (badgeCount > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.danger,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('$badgeCount',
                  style: const TextStyle(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow(
      {required this.icon,
      required this.label,
      required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
      child: Row(
        children: [
          Icon(icon, size: 15, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          SizedBox(
            width: 64,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary)),
          ),
          Text(value,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _StatVDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 36, color: AppColors.divider);
  }
}

class _HeaderChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _HeaderChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white70),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _ApproveBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ApproveBtn(
      {required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.bold)),
      ),
    );
  }
}
