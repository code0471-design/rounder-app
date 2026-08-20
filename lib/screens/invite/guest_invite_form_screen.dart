import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/club_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/club_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/kakao_talk_launcher.dart';

// ════════════════════════════════════════════════════════════
//  GuestInviteFormScreen — 총무가 게스트를 초대할 때
//  · 게스트 이름 / 추천인(소개자) 선택 입력 (연락처 입력 없음 — 카톡으로만 초대)
//  · 추천인 정보가 담긴 초대 알림톡 링크를 발급/공유
// ════════════════════════════════════════════════════════════
class GuestInviteFormScreen extends StatefulWidget {
  final Club club;
  const GuestInviteFormScreen({super.key, required this.club});

  @override
  State<GuestInviteFormScreen> createState() => _GuestInviteFormScreenState();
}

class _GuestInviteFormScreenState extends State<GuestInviteFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  Member? _referrer;
  InviteToken? _token;
  bool _sent = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _generateAndShare() async {
    if (!_formKey.currentState!.validate()) return;
    if (_referrer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('추천인(소개자)을 선택해 주세요')),
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    final token = auth.createInviteToken(
      clubId: widget.club.id,
      clubName: widget.club.name,
      inviteType: InviteMemberType.guest,
      guestName: _nameCtrl.text.trim(),
      referrerId: _referrer!.id,
      referrerName: _referrer!.name,
    );

    setState(() => _token = token);

    final msg = token.kakaoMessage(widget.club.name);
    await Clipboard.setData(ClipboardData(text: msg));
    if (!mounted) return;

    setState(() => _sent = true);
    _showKakaoSheet(msg);
  }

  Future<void> _openKakaoTalk() async {
    final ok = await openKakaoTalkApp();
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('카카오톡을 열 수 없습니다. 설치 여부를 확인해 주세요'),
          backgroundColor: Color(0xFF3A1C00),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showKakaoSheet(String message) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 32,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE500),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: Text('K', style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w900,
                      color: Color(0xFF3A1C00),
                    )),
                  ),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('게스트 초대 알림톡 미리보기',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary)),
                    Text('아래 메시지가 발송됩니다',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE500).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFFFEE500).withValues(alpha: 0.5)),
              ),
              child: Text(
                message,
                style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                    height: 1.6),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '* 메시지가 클립보드에 복사되었습니다. 카카오톡에서 붙여넣기하세요.',
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(context);
                  await _openKakaoTalk();
                },
                icon: const Text('K',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF3A1C00))),
                label: const Text('카카오톡 열기',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF3A1C00))),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFEE500),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
          Text('게스트 초대 링크가 클립보드에 복사되었습니다'),
        ]),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final regularMembers = context.watch<ClubProvider>().regularMembers;

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
          '게스트 초대하기',
          style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.bold),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 게스트는 재무 정보를 볼 수 없다는 안심 안내 (총무·회원 대상)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.success.withValues(alpha: 0.25)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.shield_outlined, size: 16, color: AppColors.success),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        '게스트는 우리 모임의 재무 및 회비 잔액을 볼 수 없으니 안심하고 초대하세요!',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.success,
                            fontWeight: FontWeight.w600,
                            height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${widget.club.name}에 게스트를 초대합니다. 추천인을 지정하면 '
                        '조편성 시 추천인과 같은 조로 자동 배정될 수 있습니다.',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              const Text('게스트 이름 *',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameCtrl,
                decoration: _deco('예: 김게스트'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? '이름을 입력하세요' : null,
              ),
              const SizedBox(height: 20),

              const Text('추천인(소개자) *',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              const Text('이 게스트를 데려온 정회원을 선택해 주세요',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              DropdownButtonFormField<Member>(
                value: _referrer,
                decoration: _deco('추천인을 선택하세요'),
                dropdownColor: Colors.white,
                items: regularMembers
                    .map((m) => DropdownMenuItem(
                          value: m,
                          child: Text('${m.name} (${m.role})',
                              style: const TextStyle(fontSize: 14)),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _referrer = v),
                validator: (v) => v == null ? '추천인을 선택하세요' : null,
              ),
              const SizedBox(height: 28),

              if (_sent) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle, color: AppColors.primary, size: 16),
                      SizedBox(width: 8),
                      Text('게스트 초대 알림톡 메시지가 클립보드에 복사되었습니다',
                          style: TextStyle(fontSize: 12, color: AppColors.primary)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _generateAndShare,
                  icon: const Text('K',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF3A1C00))),
                  label: Text(
                    _sent ? '다시 보내기' : '게스트 초대 알림톡 보내기',
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
              if (_token != null) ...[
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
              ],
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
                      Text('게스트 초대 안내',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFF59E0B))),
                    ]),
                    SizedBox(height: 6),
                    Text(
                      '• 초대 링크는 발급 후 7일간 유효합니다\n'
                      '• 링크로 가입 신청 시 게스트 등급으로 자동 접수됩니다\n'
                      '• 추천인 정보가 저장되어 조편성 시 함께 배정될 수 있습니다\n'
                      '• 가입 신청 후 총무 승인이 필요합니다',
                      style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF92400E),
                          height: 1.7),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _deco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 13, color: AppColors.textTertiary),
        filled: true,
        fillColor: AppColors.background,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      );
}
