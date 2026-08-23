import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/club_model.dart';
import '../../../models/member_role.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/club_provider.dart';
import '../../../screens/club_room/club_room_screen.dart';
import '../../../theme/app_theme.dart';
import '../application/club_detail_controller.dart';

/// 모임 상세 + 가입신청 — Firestore Controller 기반
class ClubDetailDashboardScreen extends StatelessWidget {
  final String clubId;
  final ClubProvider legacyProvider;

  const ClubDetailDashboardScreen({
    super.key,
    required this.clubId,
    required this.legacyProvider,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ClubDetailController>(
      builder: (context, controller, _) {
        if (controller.state == ClubDetailLoadState.loading &&
            controller.club == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (controller.state == ClubDetailLoadState.error &&
            controller.club == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('모임 상세')),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline,
                      size: 48, color: AppColors.textSecondary),
                  const SizedBox(height: 12),
                  Text(controller.errorMessage ?? '불러오기 실패'),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      final auth = context.read<AuthProvider>();
                      controller.load(
                        clubId: clubId,
                        userId: auth.currentUser?.id ?? '',
                      );
                    },
                    child: const Text('다시 시도'),
                  ),
                ],
              ),
            ),
          );
        }

        final club = controller.club!;
        final left = legacyProvider.hasLeftClub(club.id);
        // 탈퇴 후 재신청은 left여도 pending으로 보여야 함
        final isPending = controller.isPending ||
            legacyProvider.hasPendingRequest(club.id) ||
            legacyProvider.hasPendingRequest(
                ClubProvider.legacyClubIdFor(club.id));
        // Firestore 모임은 controller.isMember만 신뢰 (legacy isMyClub 오판으로
        // 가입 버튼이 '모임 입장'으로 바뀌는 문제 방지)
        final isLegacyDemo = RegExp(r'^c[1-5]$').hasMatch(club.id) ||
            club.id.startsWith('seed_');
        final isMine = !left &&
            !isPending &&
            (controller.isMember ||
                (isLegacyDemo && legacyProvider.isMyClub(club.id)));
        final pending = controller.pendingRequests.isNotEmpty
            ? controller.pendingRequests
            : legacyProvider.pendingRequestsOf(club.id);
        final isAdmin = controller.isAdmin ||
            (isMine &&
                ClubMemberRole.isOfficer(club.myRole));

        if (left && controller.isMember) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (controller.isMember) controller.allowRejoinAfterLeave();
          });
        }

        return Scaffold(
          backgroundColor: AppColors.background,
          body: CustomScrollView(
            slivers: [
              _DetailAppBar(
                club: club,
                isMine: isMine,
                isPending: isPending,
                isAdmin: isAdmin,
                allowRejoin: left,
                controller: controller,
                legacyProvider: legacyProvider,
              ),
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    _InfoCard(club: club, isAdmin: isAdmin, controller: controller),
                    if (isMine && isAdmin && pending.isNotEmpty)
                      _JoinRequestsCard(
                        pending: pending,
                        controller: controller,
                      ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: Material(
            color: AppColors.primaryDark,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: isMine
                    ? _MemberBar(
                        club: club,
                        isAdmin: isAdmin,
                        pendingCount: controller.pendingRequests.length,
                        controller: controller,
                        legacyProvider: legacyProvider,
                      )
                    : isPending
                        ? _PendingBar(
                            club: club,
                            controller: controller,
                            legacyProvider: legacyProvider,
                          )
                        : _JoinBar(
                            club: club,
                            controller: controller,
                            legacyProvider: legacyProvider,
                            allowRejoin: left,
                          ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DetailAppBar extends StatelessWidget {
  final Club club;
  final bool isMine;
  final bool isPending;
  final bool isAdmin;
  final bool allowRejoin;
  final ClubDetailController controller;
  final ClubProvider legacyProvider;

  const _DetailAppBar({
    required this.club,
    required this.isMine,
    required this.isPending,
    required this.isAdmin,
    required this.allowRejoin,
    required this.controller,
    required this.legacyProvider,
  });

  @override
  Widget build(BuildContext context) {
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
              padding: const EdgeInsets.fromLTRB(20, 52, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
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
                            Text(
                              club.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${club.region} · ${club.industry}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    children: [
                      _HeaderChip(
                        icon: Icons.people_outline,
                        label: '${club.memberCount}명',
                      ),
                      _HeaderChip(
                        icon: Icons.sports_golf,
                        label: '${club.teamCount}팀',
                      ),
                      if (isMine)
                        _HeaderChip(
                          icon: Icons.military_tech,
                          label: club.myRole,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _JoinBar extends StatelessWidget {
  final Club club;
  final ClubDetailController controller;
  final ClubProvider legacyProvider;
  final bool allowRejoin;

  const _JoinBar({
    required this.club,
    required this.controller,
    required this.legacyProvider,
    this.allowRejoin = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: controller.actionInProgress
            ? null
            : () => _showJoinDialog(context),
        icon: const Icon(Icons.person_add_outlined, size: 18),
        label: const Text(
          '가입 신청',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            height: 1.2,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          minimumSize: const Size(0, 48),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }

  void _showJoinDialog(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다')),
      );
      return;
    }

    final msgCtrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('${club.name} 가입 신청',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('가입 신청 메시지를 남겨주세요. (선택)',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 10),
            TextField(
              controller: msgCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: '자기 소개나 신청 이유를 적어주세요...',
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              final message = msgCtrl.text.trim();
              if (allowRejoin) {
                controller.allowRejoinAfterLeave();
              }

              // Firestore 가입 신청을 우선 — legacy isMyClub 오판으로 조용히 실패하던 문제 방지
              var ok = await controller.submitJoinRequest(
                user: user,
                message: message,
                allowRejoin: allowRejoin,
              );
              if (!ok) {
                final legacyId = ClubProvider.legacyClubIdFor(club.id);
                final legacyOk = await legacyProvider.submitJoinRequest(
                  clubId: legacyId,
                  message: message,
                  userId: user.id,
                  userName: user.name,
                  handicap: user.handicap,
                );
                ok = legacyOk ||
                    legacyProvider.hasPendingRequest(legacyId) ||
                    legacyProvider.hasPendingRequest(club.id);
                if (ok) {
                  final pending = legacyProvider.pendingRequestsOf(legacyId);
                  JoinRequest? mine;
                  for (final r in pending) {
                    if (r.userId == user.id ||
                        r.userId == 'user_guest' ||
                        r.userId == 'mg1') {
                      mine = r;
                      break;
                    }
                  }
                  if (mine != null) {
                    controller.markJoinPending(mine);
                  } else {
                    await controller.load(clubId: club.id, userId: user.id);
                  }
                }
              }

              if (!dialogCtx.mounted) return;
              Navigator.pop(dialogCtx);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(ok
                      ? '가입 신청이 완료되었습니다.'
                      : controller.errorMessage ??
                          '신청에 실패했습니다. 이미 가입된 모임인지 확인해 주세요.'),
                  backgroundColor:
                      ok ? AppColors.success : AppColors.danger,
                ),
              );
            },
            child: const Text('신청하기'),
          ),
        ],
      ),
    );
  }
}

class _PendingBar extends StatelessWidget {
  final Club club;
  final ClubDetailController controller;
  final ClubProvider legacyProvider;

  const _PendingBar({
    required this.club,
    required this.controller,
    required this.legacyProvider,
  });

  Future<void> _confirmCancel(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('가입 신청 취소',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: const Text('가입 신청을 취소하시겠습니까?',
            style: TextStyle(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('닫기'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('취소하기',
                style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    var cancelled =
        await legacyProvider.cancelMyPendingJoinRequest(club.id);
    if (!cancelled) {
      cancelled = await controller.cancelMyJoinRequest();
    } else {
      controller.allowRejoinAfterLeave();
    }
    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.maybeOf(context);
    Navigator.of(context).popUntil((route) => route.isFirst);
    await Navigator.of(context).pushNamed('/clubs');
    messenger?.showSnackBar(
      SnackBar(
        content: Text(cancelled
            ? '가입 신청을 취소했습니다.'
            : controller.errorMessage ?? '취소에 실패했습니다'),
        backgroundColor: cancelled ? AppColors.success : AppColors.danger,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border:
                  Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.hourglass_top, size: 16, color: AppColors.warning),
                SizedBox(width: 8),
                Text('가입 신청 대기 중',
                    style: TextStyle(
                        color: AppColors.warning,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        height: 1.2)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 48,
          child: OutlinedButton(
            onPressed: controller.actionInProgress
                ? null
                : () => _confirmCancel(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white54),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              minimumSize: const Size(0, 48),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('신청 취소', style: TextStyle(fontSize: 12, height: 1.2)),
          ),
        ),
      ],
    );
  }
}

class _MemberBar extends StatelessWidget {
  final Club club;
  final bool isAdmin;
  final int pendingCount;
  final ClubDetailController controller;
  final ClubProvider legacyProvider;

  const _MemberBar({
    required this.club,
    required this.isAdmin,
    required this.pendingCount,
    required this.controller,
    required this.legacyProvider,
  });

  void _enterClubRoom(BuildContext context) {
    final legacyId = controller.legacyClubIdForRoom ?? club.id;
    legacyProvider.selectClubById(legacyId);
    Club selected;
    try {
      selected = legacyProvider.myClubs.firstWhere((c) => c.id == legacyId);
    } catch (_) {
      selected = Club(
        id: legacyId,
        name: club.name,
        myRole: club.myRole,
        memberCount: club.memberCount,
        region: club.region,
        industry: club.industry,
        teamCount: club.teamCount,
        description: club.description,
      );
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ClubRoomScreen(club: selected),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (isAdmin) ...[
          Expanded(
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 10),
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
                  Flexible(
                    child: Text('${club.myRole} · 관리자',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            height: 1.2)),
                  ),
                  if (pendingCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.danger,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('$pendingCount',
                          style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () => _enterClubRoom(context),
              icon: const Icon(Icons.meeting_room_outlined, size: 18),
              label: Text(isAdmin ? '입장' : '모임 입장',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13, height: 1.2)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                minimumSize: const Size(0, 48),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoCard extends StatefulWidget {
  final Club club;
  final bool isAdmin;
  final ClubDetailController controller;

  const _InfoCard({
    required this.club,
    required this.isAdmin,
    required this.controller,
  });

  @override
  State<_InfoCard> createState() => _InfoCardState();
}

class _InfoCardState extends State<_InfoCard> {
  late int _teamCount;

  @override
  void initState() {
    super.initState();
    _teamCount = widget.club.teamCount;
  }

  @override
  void didUpdateWidget(covariant _InfoCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _teamCount = widget.club.teamCount;
  }

  @override
  Widget build(BuildContext context) {
    final club = widget.club;
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 14, 14, 0),
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
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: AppColors.primary),
                SizedBox(width: 6),
                Text('모임 정보',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary)),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
          _InfoRow(icon: Icons.location_on_outlined, label: '지역', value: club.region),
          _InfoRow(icon: Icons.business_outlined, label: '업종', value: club.industry),
          _InfoRow(icon: Icons.people_outline, label: '회원 수', value: '${club.memberCount}명'),
          _InfoRow(icon: Icons.sports_golf, label: '팀 수', value: '${club.teamCount}팀'),
          if (club.description.isNotEmpty) ...[
            const Divider(height: 1, color: AppColors.divider),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(club.description,
                  style: const TextStyle(fontSize: 13, height: 1.6)),
            ),
          ],
          if (widget.isAdmin) ...[
            const Divider(height: 1, color: AppColors.divider),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(
                children: [
                  const Text('이달 팀 수',
                      style: TextStyle(
                          fontSize: 13, color: AppColors.textSecondary)),
                  const Spacer(),
                  IconButton(
                    onPressed: _teamCount > 1
                        ? () => _updateTeamCount(_teamCount - 1)
                        : null,
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Text('$_teamCount팀',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary)),
                  IconButton(
                    onPressed: _teamCount < 30
                        ? () => _updateTeamCount(_teamCount + 1)
                        : null,
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _updateTeamCount(int count) async {
    setState(() => _teamCount = count);
    await widget.controller.updateTeamCount(count);
  }
}

class _JoinRequestsCard extends StatelessWidget {
  final List<JoinRequest> pending;
  final ClubDetailController controller;

  const _JoinRequestsCard({
    required this.pending,
    required this.controller,
  });

  Future<void> _approveWithRole(
    BuildContext context, {
    required ClubDetailController controller,
    required JoinRequest request,
    required String reviewer,
  }) async {
    var role = '정회원';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: Text('${request.userName}님 승인',
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('직책을 지정해 주세요. 권한이 자동으로 설정됩니다.',
                  style: TextStyle(fontSize: 13)),
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
                items: const ['회장', '부회장', '총무', '정회원', '게스트']
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
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('승인'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final ok = await controller.approveRequest(
      request,
      memberType: role == '게스트' ? '게스트' : '정회원',
      role: role,
      reviewedBy: reviewer,
    );
    if (context.mounted && ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${request.userName}님을 $role으로 승인했습니다'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final reviewer = auth.currentUser?.name ?? '관리자';

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Text('가입 신청 대기 (${pending.length})',
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.bold)),
          ),
          const Divider(height: 1),
          ...pending.map(
            (req) => ListTile(
              title: Text(req.userName,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: req.message.isNotEmpty ? Text(req.message) : null,
              trailing: Wrap(
                spacing: 4,
                children: [
                  TextButton(
                    onPressed: controller.actionInProgress
                        ? null
                        : () => _approveWithRole(
                              context,
                              controller: controller,
                              request: req,
                              reviewer: reviewer,
                            ),
                    child: const Text('승인'),
                  ),
                  TextButton(
                    onPressed: controller.actionInProgress
                        ? null
                        : () async {
                            final ok = await controller.rejectRequest(
                              req,
                              reviewedBy: reviewer,
                            );
                            if (context.mounted && ok) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('${req.userName}님의 신청을 거절했습니다'),
                                  backgroundColor: AppColors.danger,
                                ),
                              );
                            }
                          },
                    child: const Text('거절',
                        style: TextStyle(color: AppColors.danger)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

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
                  fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
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
