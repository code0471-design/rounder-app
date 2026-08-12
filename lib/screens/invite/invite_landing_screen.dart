import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/club_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/rounder_logo.dart';
import '../auth/signup_screen.dart';

// ════════════════════════════════════════════════════════════
//  InviteLandingScreen — 초대 링크 클릭 후 진입 화면
//
//  분기:
//  A. 기존 회원 (로그인 됨)  → "A모임에 가입하시겠습니까?" 다이얼로그
//  B. 기존 회원 (미로그인)  → 로그인 → 가입 신청
//  C. 신규 사용자           → 회원가입 → 가입 신청
// ════════════════════════════════════════════════════════════
class InviteLandingScreen extends StatefulWidget {
  final String clubId;
  final String clubName;
  final String inviterName;
  final String token;

  const InviteLandingScreen({
    super.key,
    required this.clubId,
    required this.clubName,
    required this.inviterName,
    required this.token,
  });

  @override
  State<InviteLandingScreen> createState() => _InviteLandingScreenState();
}

class _InviteLandingScreenState extends State<InviteLandingScreen> {
  bool _joining = false;
  bool _joined = false;

  @override
  void initState() {
    super.initState();
    // 로그인된 사용자라면 바로 가입 다이얼로그 표시
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (auth.isLoggedIn) {
        _showJoinDialog();
      }
    });
  }

  // ── 기존 회원: 가입 다이얼로그 ──────────────────────────────
  void _showJoinDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Text('⛳', style: TextStyle(fontSize: 24)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${widget.clubName}에\n가입하시겠습니까?',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.inviterName}님이 초대했습니다.',
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F4FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '가입 신청 후 총무의 승인이 완료되면\n정식 회원으로 등록됩니다.',
                style: TextStyle(fontSize: 12, color: AppColors.primary),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _submitJoinRequest();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('가입 신청'),
          ),
        ],
      ),
    );
  }

  // ── 가입 신청 처리 ────────────────────────────────────────
  Future<void> _submitJoinRequest() async {
    setState(() => _joining = true);
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    final auth = context.read<AuthProvider>();
    final clubProvider = context.read<ClubProvider>();
    final user = auth.currentUser!;

    // 가입 신청 등록 (총무 계정으로 공유될 때까지 await)
    await clubProvider.submitJoinRequest(
      clubId: widget.clubId,
      userId: user.id,
      userName: user.name,
      message: '초대 링크를 통해 가입 신청합니다.',
      handicap: user.handicap,
    );

    // 토큰 사용 처리
    auth.markTokenUsed(widget.token);

    setState(() {
      _joining = false;
      _joined = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _joined
            ? _SuccessView(
                clubName: widget.clubName,
                onGoHome: () => Navigator.of(context)
                    .pushNamedAndRemoveUntil('/main', (_) => false),
              )
            : _LandingView(
                clubName: widget.clubName,
                inviterName: widget.inviterName,
                isLoggedIn: auth.isLoggedIn,
                isJoining: _joining,
                onJoinAsExisting: _showJoinDialog,
                onSignup: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SignupScreen(
                      inviteClubId: widget.clubId,
                      inviteClubName: widget.clubName,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
//  랜딩 뷰 (비로그인 / 처리 중)
// ────────────────────────────────────────────────────────────
class _LandingView extends StatelessWidget {
  final String clubName;
  final String inviterName;
  final bool isLoggedIn;
  final bool isJoining;
  final VoidCallback onJoinAsExisting;
  final VoidCallback onSignup;

  const _LandingView({
    required this.clubName,
    required this.inviterName,
    required this.isLoggedIn,
    required this.isJoining,
    required this.onJoinAsExisting,
    required this.onSignup,
  });

  @override
  Widget build(BuildContext context) {
    if (isJoining) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 16),
            Text('가입 신청 중...', style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          const SizedBox(height: 48),

          // ── 로고 ──
          const RounderLogo(height: 44),
          const SizedBox(height: 36),

          // ── 초대 카드 ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.08),
                  AppColors.primaryLight.withValues(alpha: 0.06),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: Column(
              children: [
                const Text('⛳', style: TextStyle(fontSize: 52)),
                const SizedBox(height: 12),
                Text(
                  '$inviterName님이',
                  style: const TextStyle(
                      fontSize: 14, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  clubName,
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                const Text(
                  '골프 모임에 초대했습니다!',
                  style: TextStyle(
                      fontSize: 14, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          if (isLoggedIn) ...[
            // ── 기존 회원: 바로 가입 신청 ──
            const Text(
              '이미 ROUNDER 회원이시군요!',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            const Text(
              '바로 가입 신청을 진행할 수 있습니다',
              style: TextStyle(
                  fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: onJoinAsExisting,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: const Text('가입 신청하기',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ] else ...[
            // ── 신규 사용자 ──
            const Text(
              'ROUNDER에서 골프 모임을\n함께 관리하세요!',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: onSignup,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: const Text('회원가입 후 가입',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: () =>
                    Navigator.of(context).pushNamed('/login'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(
                      color: AppColors.primary, width: 1.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('이미 회원이에요 — 로그인',
                    style: TextStyle(fontSize: 14)),
              ),
            ),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
//  가입 신청 완료 뷰
// ────────────────────────────────────────────────────────────
class _SuccessView extends StatelessWidget {
  final String clubName;
  final VoidCallback onGoHome;

  const _SuccessView({required this.clubName, required this.onGoHome});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_outline,
                  color: AppColors.primary, size: 60),
            ),
            const SizedBox(height: 24),
            const Text(
              '가입 신청 완료!',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary),
            ),
            const SizedBox(height: 12),
            Text(
              '$clubName 모임의 총무가\n가입 신청을 검토 후 승인하면\n정식 회원으로 등록됩니다.',
              style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.7),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 36),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: onGoHome,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: const Text('홈으로 돌아가기',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
