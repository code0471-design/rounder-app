import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/club_model.dart';
import '../../providers/club_provider.dart';
import '../../theme/app_theme.dart';

// ════════════════════════════════════════════════════════════
//  ThankYouFeedScreen — 후원사 감사인사 피드
//  · 회원들이 보낸 감사인사를 댓글처럼 모아보기
//  · 후원사별 필터, 작성 기능
// ════════════════════════════════════════════════════════════
class ThankYouFeedScreen extends StatefulWidget {
  const ThankYouFeedScreen({super.key});

  @override
  State<ThankYouFeedScreen> createState() => _ThankYouFeedScreenState();
}

class _ThankYouFeedScreenState extends State<ThankYouFeedScreen> {
  String? _filterSponsor;

  @override
  Widget build(BuildContext context) {
    return Consumer<ClubProvider>(
      builder: (context, provider, _) {
        final messages = _filterSponsor == null
            ? provider.thankYouMessages
            : provider.thankYouMessages
                .where((m) => m.sponsorName == _filterSponsor)
                .toList();

        // 후원사 목록 추출
        final sponsors = provider.thankYouMessages
            .map((m) => m.sponsorName)
            .toSet()
            .toList();

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.primaryDark,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new,
                  color: Colors.white, size: 18),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '감사인사 피드',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold),
                ),
                Text(
                  '회원들의 후원사 감사 메시지',
                  style: TextStyle(color: Colors.white60, fontSize: 11),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined,
                    color: Colors.white, size: 20),
                onPressed: () => _showWriteDialog(context, provider),
                tooltip: '감사인사 작성',
              ),
            ],
          ),
          body: Column(
            children: [
              // ── 요약 배너 ──
              Container(
                width: double.infinity,
                color: AppColors.primaryDark,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Text('💌',
                              style: TextStyle(fontSize: 14)),
                          const SizedBox(width: 6),
                          Text(
                            '총 ${provider.thankYouMessages.length}개 감사인사',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: () => _showWriteDialog(context, provider),
                      icon: const Icon(Icons.favorite_outline,
                          size: 14, color: Color(0xFFE91E8C)),
                      label: const Text(
                        '감사인사 보내기',
                        style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFFE91E8C),
                            fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                      ),
                    ),
                  ],
                ),
              ),

              // ── 후원사 필터 탭 ──
              if (sponsors.isNotEmpty)
                Container(
                  height: 44,
                  color: Colors.white,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    children: [
                      _FilterChip(
                        label: '전체',
                        selected: _filterSponsor == null,
                        onTap: () =>
                            setState(() => _filterSponsor = null),
                      ),
                      ...sponsors.map((s) => _FilterChip(
                            label: s,
                            selected: _filterSponsor == s,
                            onTap: () =>
                                setState(() => _filterSponsor = s),
                          )),
                    ],
                  ),
                ),

              const Divider(height: 1),

              // ── 메시지 목록 ──
              Expanded(
                child: messages.isEmpty
                    ? _buildEmpty(context, provider)
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        itemCount: messages.length,
                        itemBuilder: (_, i) =>
                            _ThankYouCard(message: messages[i]),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmpty(BuildContext context, ClubProvider provider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('💌', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 16),
          const Text(
            '아직 감사인사가 없습니다',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          const Text(
            '후원사에 첫 번째 감사인사를 보내보세요!',
            style:
                TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showWriteDialog(context, provider),
            icon: const Icon(Icons.favorite_outline, size: 16),
            label: const Text('감사인사 작성하기'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE91E8C),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  void _showWriteDialog(BuildContext context, ClubProvider provider) {
    final msgCtrl = TextEditingController();
    String selectedSponsor =
        provider.thankYouMessages.isNotEmpty
            ? provider.thankYouMessages.first.sponsorName
            : '골프존마켓';

    // 이용 가능한 후원사 목록 (mock)
    final availableSponsors = [
      '골프존마켓',
      '스카이72골프장',
      '카카오뱅크',
      '골프존카운티',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 핸들
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
              const Text(
                '💌 감사인사 보내기',
                style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                '작성한 메시지는 모든 회원이 볼 수 있습니다',
                style: TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),

              // 후원사 선택
              const Text(
                '후원사 선택',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: availableSponsors
                    .map((s) => GestureDetector(
                          onTap: () => setS(() => selectedSponsor = s),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: selectedSponsor == s
                                  ? const Color(0xFFE91E8C)
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              s,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: selectedSponsor == s
                                    ? Colors.white
                                    : AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 16),

              // 메시지 입력
              const Text(
                '감사 메시지',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: msgCtrl,
                maxLength: 150,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText:
                      '후원사에 전하고 싶은 감사의 말을 적어주세요...',
                  hintStyle: TextStyle(
                      fontSize: 13, color: Colors.grey.shade400),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: Colors.grey.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: Color(0xFFE91E8C), width: 1.5),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: Colors.grey.shade200),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final msg = msgCtrl.text.trim();
                    if (msg.isEmpty) return;
                    provider.addThankYouMessage(
                      senderId: provider.currentUserId,
                      senderName: '홍길동',
                      sponsorName: selectedSponsor,
                      message: msg,
                    );
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Row(
                          children: [
                            Icon(Icons.favorite,
                                color: Colors.white, size: 16),
                            SizedBox(width: 8),
                            Text('감사인사를 전달했습니다! (+2 멤버십 포인트)'),
                          ],
                        ),
                        backgroundColor: const Color(0xFFE91E8C),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                  },
                  icon: const Icon(Icons.favorite_outline, size: 16),
                  label: const Text('감사인사 전송',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE91E8C),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding:
                        const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  감사인사 카드
// ─────────────────────────────────────────────────────────────
class _ThankYouCard extends StatelessWidget {
  final ThankYouMessage message;
  const _ThankYouCard({required this.message});

  @override
  Widget build(BuildContext context) {
    final diff = DateTime.now().difference(message.createdAt);
    final timeStr = diff.inMinutes < 60
        ? '${diff.inMinutes}분 전'
        : diff.inHours < 24
            ? '${diff.inHours}시간 전'
            : '${diff.inDays}일 전';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 후원사 태그
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFE91E8C).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('💌', style: TextStyle(fontSize: 10)),
                const SizedBox(width: 4),
                Text(
                  message.sponsorName,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFE91E8C),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // 메시지 본문
          Text(
            message.message,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textPrimary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          // 보낸 사람 + 시간
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                child: Text(
                  message.senderName[0],
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                message.senderName,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '·  $timeStr',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  필터 칩
// ─────────────────────────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFE91E8C)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
