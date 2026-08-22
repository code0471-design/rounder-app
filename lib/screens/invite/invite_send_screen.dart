import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/club_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/kakao_talk_launcher.dart';

// ════════════════════════════════════════════════════════════
//  InviteSendScreen — 초대장 보내기
//  · 「초대장 보내기」→ OS 텍스트 공유 시트 (밴드와 동일 UX)
// ════════════════════════════════════════════════════════════
class InviteSendScreen extends StatefulWidget {
  final Club club;
  const InviteSendScreen({super.key, required this.club});

  @override
  State<InviteSendScreen> createState() => _InviteSendScreenState();
}

class _InviteSendScreenState extends State<InviteSendScreen> {
  InviteToken? _token;
  bool _generating = true;
  bool _sent = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _generateToken();
    });
  }

  Future<void> _generateToken() async {
    if (!mounted) return;
    setState(() => _generating = true);
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    final auth = context.read<AuthProvider>();
    final token = auth.createInviteToken(
      clubId: widget.club.id,
      clubName: widget.club.name,
    );
    setState(() {
      _token = token;
      _generating = false;
    });
  }

  /// 밴드처럼 시스템 공유 시트 오픈 → 카톡 등에서 대상 선택
  Future<void> _sendInvitation() async {
    if (_token == null) return;
    final msg = _token!.kakaoMessage(widget.club.name);
    await Clipboard.setData(ClipboardData(text: msg));
    if (!mounted) return;
    setState(() => _sent = true);
    final ok = await shareInviteText(
      message: msg,
      subject: '${widget.club.name} 초대장',
    );
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('공유 화면을 열 수 없습니다'),
          backgroundColor: Color(0xFF3A1C00),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _copyLink() async {
    if (_token == null) return;
    await Clipboard.setData(ClipboardData(text: _token!.webUrl));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(children: [
          Icon(Icons.check_circle, color: Colors.white, size: 16),
          SizedBox(width: 8),
          Text('초대 링크가 클립보드에 복사되었습니다'),
        ]),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              size: 18, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '초대장 보내기',
          style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.bold),
        ),
      ),
      body: _generating ? _buildLoadingView() : _buildMainView(),
    );
  }

  Widget _buildLoadingView() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppColors.primary),
          SizedBox(height: 16),
          Text('초대장 준비 중...',
              style: TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildMainView() {
    if (_token == null) return const SizedBox.shrink();
    final expiryDate =
        '${_token!.expiresAt.month}월 ${_token!.expiresAt.day}일';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ClubInfoCard(club: widget.club),
          const SizedBox(height: 28),
          const Text(
            '초대장 보내기',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            '공유 화면에서 카카오톡 등을 고른 뒤 친구에게 보내세요.\n'
            '초대장은 $expiryDate까지 유효합니다.',
            style: const TextStyle(
                fontSize: 13, color: AppColors.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFEE500).withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: const Color(0xFFFEE500).withValues(alpha: 0.6)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE500),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Center(
                        child: Icon(Icons.ios_share,
                            size: 16, color: Color(0xFF3A1C00)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('초대장 메시지',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF92400E))),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _token!.kakaoMessage(widget.club.name),
                  style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textPrimary,
                      height: 1.6),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (_sent) ...[
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle,
                      color: AppColors.primary, size: 16),
                  SizedBox(width: 8),
                  Text('초대장이 준비되었습니다. 공유 앱을 선택하세요',
                      style:
                          TextStyle(fontSize: 12, color: AppColors.primary)),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: _sendInvitation,
              icon: const Icon(Icons.ios_share,
                  size: 20, color: Color(0xFF3A1C00)),
              label: Text(
                _sent ? '다시 보내기' : '초대장 보내기',
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF3A1C00)),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFEE500),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _copyLink,
              icon: const Icon(Icons.copy_outlined, size: 16),
              label: const Text('초대 링크만 복사'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                side: const BorderSide(color: Color(0xFFD1D5DB)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFFE082)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.info_outline,
                      size: 14, color: Color(0xFFF59E0B)),
                  SizedBox(width: 6),
                  Text('초대 링크 안내',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFF59E0B))),
                ]),
                SizedBox(height: 6),
                Text(
                  '• 초대장 보내기를 누르면 카카오톡·문자 등 공유 앱을 고를 수 있습니다\n'
                  '• 초대 링크는 발급 후 7일간 유효합니다\n'
                  '• 가입 신청 시 총무에게 승인 알림이 발송됩니다',
                  style: TextStyle(
                      fontSize: 11, color: Color(0xFF92400E), height: 1.7),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _ClubInfoCard extends StatelessWidget {
  final Club club;
  const _ClubInfoCard({required this.club});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.08),
            AppColors.primaryLight.withValues(alpha: 0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Center(
              child: Text('⛳', style: TextStyle(fontSize: 26)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(club.name,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Text(
                  '${club.region} · ${club.memberCount}명',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('초대 가능',
                style: TextStyle(
                    fontSize: 11,
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
