import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/club_model.dart';
import '../providers/club_provider.dart';
import '../theme/app_theme.dart';

// ════════════════════════════════════════════════════════════
//  광고 배너 공용 위젯 — 제휴 광고 우선 / 샘플 광고 폴백
//  · AdBannerType.feed   — 피드형 (홈 화면용)
//  · AdBannerType.banner — 배너형 (슬림 배너)
//  · AdBannerType.native — 네이티브형 (일정/회원 탭 리스트 삽입)
//
//  [표시 우선순위]
//    1. clubId + slotType 조합의 active 제휴 광고 (AdApplication)
//    2. 샘플 플랫폼 광고 (_sampleAds 풀에서 adIndex 기준)
// ════════════════════════════════════════════════════════════

enum AdBannerType { feed, banner, native }

// ── 슬롯 타입 ↔ 배너 타입 매핑 ──
// AdSlotType.home     → AdBannerType.banner (홈 탭 배너형)
// AdSlotType.schedule → AdBannerType.native (일정 탭 네이티브형)
// AdSlotType.member   → AdBannerType.native (회원 탭 네이티브형)

// ────────────────────────────────────────────────────────────
//  샘플 광고 데이터 (제휴 광고 없을 때 폴백)
// ────────────────────────────────────────────────────────────
class _AdData {
  final String tag;
  final String headline;
  final String body;
  final String cta;
  final IconData icon;
  final List<Color> gradient;

  const _AdData({
    required this.tag,
    required this.headline,
    required this.body,
    required this.cta,
    required this.icon,
    required this.gradient,
  });

  Color get accentColor => gradient.first;
}

const List<_AdData> _sampleAds = [
  _AdData(
    tag: 'AD',
    headline: '스카이72 골프 & 리조트',
    body: '인천 영종도 36홀 · 지금 예약 시 그린피 15% 할인',
    cta: '예약하기',
    icon: Icons.golf_course,
    gradient: [Color(0xFF1A237E), Color(0xFF3949AB)],
  ),
  _AdData(
    tag: 'AD',
    headline: 'TITLEIST Pro V1x 한정 특가',
    body: '시즌 12구 + 마커 세트 · 오늘만 무료배송',
    cta: '구매하기',
    icon: Icons.sports_golf,
    gradient: [Color(0xFF7C4DFF), Color(0xFFE040FB)],
  ),
  _AdData(
    tag: 'AD',
    headline: '스윙분석 AI — GolfEye',
    body: '스마트폰으로 내 스윙 분석 · 7일 무료 체험',
    cta: '무료 시작',
    icon: Icons.videocam_rounded,
    gradient: [Color(0xFF0091EA), Color(0xFF00BCD4)],
  ),
  _AdData(
    tag: 'AD',
    headline: '카카오페이 홀인원 보험',
    body: '월 2,900원 · 최대 1억 보장 · 간편 가입',
    cta: '가입하기',
    icon: Icons.shield_rounded,
    gradient: [Color(0xFFFF6D00), Color(0xFFFF8F00)],
  ),
  _AdData(
    tag: 'AD',
    headline: '파인리즈 골프클럽 평일 특가',
    body: '경기도 용인 · 부킹 앱 최저가 보장',
    cta: '그린피 확인',
    icon: Icons.flag_rounded,
    gradient: [Color(0xFFE53935), Color(0xFFFF7043)],
  ),
];

_AdData _pickAd(int seed) => _sampleAds[seed % _sampleAds.length];

// ────────────────────────────────────────────────────────────
//  제휴 광고 → _AdData 변환 헬퍼
// ────────────────────────────────────────────────────────────
_AdData _fromApplication(AdApplication ad) {
  // 배너 이미지가 있으면 아이콘 대신 이미지를 쓰고 싶지만,
  // 현재 단계에서는 텍스트 기반으로 렌더링
  return _AdData(
    tag: '제휴',
    headline: ad.title,
    body: ad.description,
    cta: '자세히 보기',
    icon: Icons.campaign_outlined,
    gradient: const [Color(0xFF1B6B3A), Color(0xFF2E9E5B)], // 모임 테마 그린
  );
}

// ════════════════════════════════════════════════════════════
//  메인 위젯 — 제휴 광고 우선, 폴백 샘플
// ════════════════════════════════════════════════════════════
class AdBanner extends StatelessWidget {
  final AdBannerType type;
  final int adIndex;
  // 특정 클럽의 슬롯 광고를 표시할 때 사용
  final String? clubId;
  final AdSlotType? slotType;

  const AdBanner({
    super.key,
    this.type = AdBannerType.feed,
    this.adIndex = 0,
    this.clubId,
    this.slotType,
  });

  @override
  Widget build(BuildContext context) {
    // clubId + slotType 이 있으면 제휴 광고 확인
    if (clubId != null && slotType != null) {
      return Consumer<ClubProvider>(
        builder: (context, provider, _) {
          final active = provider.activeAdForSlot(clubId!, slotType!);
          final ad = active != null ? _fromApplication(active) : _pickAd(adIndex);
          final isPartner = active != null;
          return _buildBanner(context, ad, isPartner: isPartner);
        },
      );
    }
    // 클럽 미지정 → 샘플 광고
    return _buildBanner(context, _pickAd(adIndex), isPartner: false);
  }

  Widget _buildBanner(BuildContext context, _AdData ad, {required bool isPartner}) {
    switch (type) {
      case AdBannerType.feed:
        return _FeedAd(ad: ad, isPartner: isPartner);
      case AdBannerType.banner:
        return _BannerAd(ad: ad, isPartner: isPartner);
      case AdBannerType.native:
        return _NativeAd(ad: ad, isPartner: isPartner);
    }
  }
}

// ════════════════════════════════════════════════════════════
//  피드형 — 홈 화면용 그라디언트 카드
// ════════════════════════════════════════════════════════════
class _FeedAd extends StatelessWidget {
  final _AdData ad;
  final bool isPartner;
  const _FeedAd({required this.ad, this.isPartner = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: ad.gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: ad.accentColor.withValues(alpha: 0.40),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Row(
          children: [
            // 아이콘 영역
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                shape: BoxShape.circle,
              ),
              child: Icon(ad.icon, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 13),
            // 텍스트 영역
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _AdTag(dark: false, label: ad.tag),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          ad.headline,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    ad.body,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.85),
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // CTA 버튼
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                ad.cta,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: ad.accentColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  배너형 — 슬림 배너 (홈 탭 하단)
// ════════════════════════════════════════════════════════════
class _BannerAd extends StatelessWidget {
  final _AdData ad;
  final bool isPartner;
  const _BannerAd({required this.ad, this.isPartner = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 87,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: ad.gradient,
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: ad.accentColor.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(ad.icon, color: Colors.white, size: 17),
            ),
            const SizedBox(width: 10),
            _AdTag(dark: false, small: true, label: ad.tag),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                ad.headline,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                ad.cta,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: ad.accentColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  네이티브형 — 리스트 삽입형 (일정/회원 탭)
// ════════════════════════════════════════════════════════════
class _NativeAd extends StatelessWidget {
  final _AdData ad;
  final bool isPartner;
  const _NativeAd({required this.ad, this.isPartner = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: ad.accentColor.withValues(alpha: 0.25),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: ad.accentColor.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // 왼쪽 컬러 사이드바
          Container(
            width: 5,
            height: 108,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: ad.gradient,
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                bottomLeft: Radius.circular(14),
              ),
            ),
          ),
          const SizedBox(width: 11),
          // 그라디언트 아이콘
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: ad.gradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(ad.icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          // 텍스트
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    _AdTag(dark: true, small: true, label: ad.tag),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        ad.headline,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  ad.body,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // CTA 버튼
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: ad.gradient),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: ad.accentColor.withValues(alpha: 0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              ad.cta,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 'AD' / '제휴' 태그 뱃지 ──
class _AdTag extends StatelessWidget {
  final bool small;
  final bool dark;
  final String label;

  const _AdTag({
    this.small = false,
    this.dark = false,
    this.label = 'AD',
  });

  @override
  Widget build(BuildContext context) {
    final isPartner = label == '제휴';
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: small ? 4 : 5,
          vertical: small ? 1 : 2),
      decoration: BoxDecoration(
        color: isPartner
            ? const Color(0xFFFF6D00).withValues(alpha: 0.85)
            : dark
                ? Colors.white.withValues(alpha: 0.25)
                : Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: small ? 8 : 9,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
