import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/club_provider.dart';
import '../../services/deep_link_service.dart';
import '../../services/pending_invite_store.dart';
import '../../theme/app_theme.dart';
import '../../widgets/rounder_logo.dart';
import '../auth/signup_screen.dart';
import '../club_room/club_room_screen.dart';

// ════════════════════════════════════════════════════════════
//  InviteLandingScreen — 초대 링크 클릭 후 진입 화면
//
//  초대 = 즉시 가입 (승인 없음, 밴드형)
//  A. 로그인됨 → 확인 없이 바로 모임 멤버
//  B. 미로그인 → 로그인/회원가입 후 즉시 가입
// ════════════════════════════════════════════════════════════
class InviteLandingScreen extends StatefulWidget {
  final String clubId;
  final String clubName;
  final String inviterName;
  final String token;
  final InviteMemberType inviteType;
  final String? referrerId;
  final String? referrerName;
  final String? guestName;

  const InviteLandingScreen({
    super.key,
    required this.clubId,
    required this.clubName,
    required this.inviterName,
    required this.token,
    this.inviteType = InviteMemberType.regular,
    this.referrerId,
    this.referrerName,
    this.guestName,
  });

  @override
  State<InviteLandingScreen> createState() => _InviteLandingScreenState();
}

class _InviteLandingScreenState extends State<InviteLandingScreen> {
  bool _joining = false;
  bool _joined = false;

  bool get _asGuest => widget.inviteType == InviteMemberType.guest;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (auth.isLoggedIn) {
        _acceptInvite();
      }
    });
  }

  Future<void> _acceptInvite() async {
    if (_joining || _joined) return;
    setState(() => _joining = true);

    final auth = context.read<AuthProvider>();
    final clubProvider = context.read<ClubProvider>();
    final user = auth.currentUser;
    if (user == null) {
      setState(() => _joining = false);
      return;
    }

    final ok = await clubProvider.joinViaInvite(
      clubId: widget.clubId,
      clubName: widget.clubName,
      asGuest: _asGuest,
      referrerId: widget.referrerId,
      referrerName: widget.referrerName,
      displayName: _asGuest && (widget.guestName?.trim().isNotEmpty ?? false)
          ? widget.guestName!.trim()
          : user.name,
    );

    if (widget.token.isNotEmpty && widget.token != 'link') {
      auth.markTokenUsed(widget.token);
    }

    if (!mounted) return;
    setState(() {
      _joining = false;
      _joined = ok;
    });

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('가입에 실패했습니다. 초대 링크를 다시 확인해 주세요.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      await PendingInviteStore.clear();
    }
  }

  void _openClubRoom() {
    final clubs = context.read<ClubProvider>();
    clubs.selectClubById(widget.clubId);
    final club = clubs.myClubs.where((c) => c.id == widget.clubId).firstOrNull;
    if (club == null) {
      Navigator.of(context).pushNamedAndRemoveUntil('/main', (_) => false);
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => ClubRoomScreen(club: club)),
      (route) => route.settings.name == '/main' || route.isFirst,
    );
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
                asGuest: _asGuest,
                onOpenClub: _openClubRoom,
                onGoHome: () => Navigator.of(context)
                    .pushNamedAndRemoveUntil('/main', (_) => false),
              )
            : _LandingView(
                clubName: widget.clubName,
                inviterName: widget.inviterName,
                asGuest: _asGuest,
                isLoggedIn: auth.isLoggedIn,
                isJoining: _joining,
                onJoinAsExisting: _acceptInvite,
                onLogin: () {
                  final uri = Uri(
                    scheme: 'rounder',
                    host: 'invite',
                    queryParameters: {
                      'token': widget.token,
                      'club': widget.clubId,
                      'name': widget.clubName,
                      'inviter': widget.inviterName,
                      'type': _asGuest ? 'guest' : 'regular',
                      if (widget.referrerId != null)
                        'referrer': widget.referrerId!,
                      if (widget.referrerName != null)
                        'referrerName': widget.referrerName!,
                      if (widget.guestName != null) 'guest': widget.guestName!,
                    },
                  );
                  DeepLinkService.instance.queue(uri);
                  Navigator.of(context).pushNamed('/login');
                },
                onSignup: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SignupScreen(
                      inviteClubId: widget.clubId,
                      inviteClubName: widget.clubName,
                      inviteInviterName: widget.inviterName,
                      inviteToken: widget.token,
                      inviteAsGuest: _asGuest,
                      inviteReferrerId: widget.referrerId,
                      inviteReferrerName: widget.referrerName,
                      inviteGuestName: widget.guestName,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _LandingView extends StatelessWidget {
  final String clubName;
  final String inviterName;
  final bool asGuest;
  final bool isLoggedIn;
  final bool isJoining;
  final VoidCallback onJoinAsExisting;
  final VoidCallback onSignup;
  final VoidCallback onLogin;

  const _LandingView({
    required this.clubName,
    required this.inviterName,
    required this.asGuest,
    required this.isLoggedIn,
    required this.isJoining,
    required this.onJoinAsExisting,
    required this.onSignup,
    required this.onLogin,
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
            Text('가입 중...', style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          const SizedBox(height: 48),
          const RounderLogo(height: 44),
          const SizedBox(height: 36),
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
                Text(
                  asGuest ? '게스트로 초대했습니다!' : '골프 모임에 초대했습니다!',
                  style: const TextStyle(
                      fontSize: 14, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          if (isLoggedIn) ...[
            const Text(
              '이미 ROUNDER 회원이시군요!',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            const Text(
              '확인하면 바로 모임에 가입됩니다',
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
                child: const Text('바로 가입하기',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ] else ...[
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
                child: const Text('회원가입 후 바로 가입',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: onLogin,
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

class _SuccessView extends StatelessWidget {
  final String clubName;
  final bool asGuest;
  final VoidCallback onOpenClub;
  final VoidCallback onGoHome;

  const _SuccessView({
    required this.clubName,
    required this.asGuest,
    required this.onOpenClub,
    required this.onGoHome,
  });

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
              '가입 완료!',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary),
            ),
            const SizedBox(height: 12),
            Text(
              asGuest
                  ? '$clubName 모임에\n게스트로 가입되었습니다.'
                  : '$clubName 모임에\n바로 가입되었습니다.',
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
                onPressed: onOpenClub,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: const Text('모임으로 이동',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: onGoHome,
              child: const Text('홈으로',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
          ],
        ),
      ),
    );
  }
}
