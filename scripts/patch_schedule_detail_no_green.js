// 일정 상세 화면에서 그린을 걷어낸다.
//
// 그린(AppColors.primary 계열)은 상단 로고 헤더와 하단 탭바 전용으로 두고,
// 본문 강조는 크림 + 웜 차콜(AppColors.charcoal) + 딥골드(AppColors.goldDeep)로
// 통일한다. 파스텔 톤(베이지 그라데이션)도 같이 정리한다.
//
// schedule_screen.dart 는 CRLF/UTF-8 이라 Cursor 치환 대신 이 스크립트로 고친다.
//   node scripts/patch_schedule_detail_no_green.js

const fs = require('fs');
const path = require('path');

const FILE = path.join('lib', 'screens', 'schedule', 'schedule_screen.dart');
let src = fs.readFileSync(FILE, 'utf8');

const eol = src.includes('\r\n') ? '\r\n' : '\n';
const nl = (s) => s.replace(/\r?\n/g, eol);

let applied = 0;
const failed = [];

/** 정확히 1회만 나타나는 블록을 바꾼다. 개수가 다르면 실패로 남긴다. */
function replaceOnce(label, from, to) {
  const a = nl(from);
  const b = nl(to);
  const parts = src.split(a);
  if (parts.length !== 2) {
    failed.push(`${label} (matches=${parts.length - 1})`);
    return;
  }
  src = parts.join(b);
  applied++;
}

/** 여러 번 나오는 짧은 토큰을 전부 바꾼다. 기대 개수를 명시한다. */
function replaceAll(label, from, to, expected) {
  const a = nl(from);
  const count = src.split(a).length - 1;
  if (count !== expected) {
    failed.push(`${label} (matches=${count}, expected=${expected})`);
    return;
  }
  src = src.split(a).join(nl(to));
  applied++;
}

// ────────────────────────────────────────────────────────────
// 1. 상단 배너 — 딥그린 → 웜 차콜, 아이콘은 골드
// ────────────────────────────────────────────────────────────
replaceOnce(
  '배너 그라데이션',
  `                    gradient: const LinearGradient(
                      colors: [AppColors.primaryDark, AppColors.primary],`,
  `                    gradient: const LinearGradient(
                      // 그린은 로고 헤더·하단 탭바 전용. 화면 안은 웜 차콜.
                      colors: [AppColors.charcoalDeep, AppColors.charcoal],`,
);

replaceOnce(
  '배너 그림자',
  `                        color: AppColors.primaryDark.withValues(alpha: 0.28),`,
  `                        color: AppColors.charcoalDeep.withValues(alpha: 0.28),`,
);

for (const [label, icon] of [
  ['배너 장소 아이콘', 'Icons.place_rounded'],
  ['배너 시간 아이콘', 'Icons.schedule_rounded'],
]) {
  replaceOnce(
    label,
    `                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(7),
                                    ),
                                    child: const Icon(${icon},
                                        color: Colors.white, size: 14),`,
    `                                    decoration: BoxDecoration(
                                      color: AppColors.accent
                                          .withValues(alpha: 0.20),
                                      borderRadius: BorderRadius.circular(7),
                                    ),
                                    child: const Icon(${icon},
                                        color: AppColors.accent, size: 14),`,
  );
}

// ────────────────────────────────────────────────────────────
// 2. 내 응답 — 참석 강조를 그린 → 차콜, 상태색은 딥골드
// ────────────────────────────────────────────────────────────
replaceOnce(
  '내 응답 상태색',
  `    final statusColor = !responded
        ? AppColors.success
        : currentResponse == '참석'
            ? AppColors.success
            : currentResponse == '불참'
                ? AppColors.danger
                : AppColors.warning;`,
  `    final statusColor = !responded
        ? AppColors.textTertiary
        : currentResponse == '참석'
            ? AppColors.goldDeep
            : currentResponse == '불참'
                ? AppColors.danger
                : AppColors.textTertiary;`,
);

replaceOnce(
  '내 응답 버튼색',
  `              final btnColor =
                  label == '참석' ? AppColors.primary : AppColors.danger;`,
  `              final btnColor =
                  label == '참석' ? AppColors.charcoal : AppColors.danger;`,
);

replaceOnce(
  '참석 확정 스낵바',
  `                              content: const Text('참석이 확정되었습니다'),
                              backgroundColor: AppColors.success,`,
  `                              content: const Text('참석이 확정되었습니다'),
                              backgroundColor: AppColors.charcoal,`,
);

// ────────────────────────────────────────────────────────────
// 3. 조편성 카드 — 베이지 그라데이션·골드 테두리 → 다른 카드와 같은 톤
// ────────────────────────────────────────────────────────────
replaceOnce(
  '조편성 팔레트 상수',
  `  // 조편성 미리보기 팔레트 (브랜드 골드 — 딥그린/주황 대신)
  static const Color _orange = Color(0xFFC9A227);
  static const Color _orangeDeep = Color(0xFF8F7318);
  static const List<Color> _groupColors = [
    AppColors.primary,
    Color(0xFF00897B),
    Color(0xFFE65100),
    Color(0xFF5A8F7B),
    Color(0xFFEF6C00),
    Color(0xFF2F5C4C),
  ];`,
  `  // 조편성 팔레트 — 크림·골드·차콜 컨셉. 그린과 파스텔은 쓰지 않는다.
  static const Color _gold = AppColors.accent;
  static const Color _goldDeep = AppColors.goldDeep;
  // 조 배지는 같은 웜 계열의 명도 차이로만 구분한다.
  static const List<Color> _groupColors = [
    AppColors.goldDeep,
    AppColors.charcoal,
    Color(0xFFB08A2E),
    Color(0xFF6B6459),
    Color(0xFF8C6239),
    Color(0xFF3F3B33),
  ];`,
);

replaceOnce(
  '조편성 카드 테두리·그림자',
  `          border: Border.all(
            color: isFinalized
                ? _orange.withValues(alpha: 0.55)
                : _orange.withValues(alpha: 0.28),
            width: isFinalized ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isFinalized
                  ? _orange.withValues(alpha: 0.22)
                  : _orange.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],`,
  `          // 다른 카드와 같은 테두리·그림자. 조편성만 튀지 않게 한다.
          border: Border.all(
            color: isFinalized ? AppColors.goldDeep : AppColors.divider,
            width: isFinalized ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],`,
);

replaceOnce(
  '조편성 헤더 배경',
  `                gradient: isFinalized
                    ? const LinearGradient(
                        colors: [_orange, Color(0xFFE0C35A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : const LinearGradient(
                        colors: [Color(0xFFFBF6E4), Color(0xFFF8F1D6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                color: null,`,
  `                // 확정: 차콜 + 골드 아이콘 / 미확정: 조용한 크림
                gradient: isFinalized
                    ? const LinearGradient(
                        colors: [AppColors.charcoal, AppColors.charcoalDeep],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isFinalized ? null : AppColors.cream2,`,
);

// 확정 시 흰색이던 요소 중 아이콘만 골드로. 나머지 흰색 텍스트는 차콜 위라 그대로 둔다.
replaceOnce(
  '조편성 아이콘',
  `                      color: isFinalized
                          ? Colors.white.withValues(alpha: 0.25)
                          : _orange.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.groups_rounded,
                      color: isFinalized
                          ? Colors.white
                          : _orangeDeep,`,
  `                      color: isFinalized
                          ? AppColors.accent.withValues(alpha: 0.22)
                          : AppColors.sand,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.groups_rounded,
                      color: isFinalized
                          ? AppColors.accent
                          : AppColors.goldDeep,`,
);

replaceOnce(
  '조편성 제목',
  `                            color: isFinalized
                                ? Colors.white
                                : _orangeDeep,
                          ),
                        ),
                        const SizedBox(height: 2),`,
  `                            color: isFinalized
                                ? Colors.white
                                : AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 2),`,
);

replaceOnce(
  '조편성 부제',
  `                            color: isFinalized
                                ? Colors.white.withValues(alpha: 0.9)
                                : _orangeDeep.withValues(alpha: 0.85),`,
  `                            color: isFinalized
                                ? Colors.white.withValues(alpha: 0.9)
                                : AppColors.textTertiary,`,
);

replaceOnce(
  '조편성 상태 뱃지',
  `                      color: isFinalized
                          ? Colors.white.withValues(alpha: 0.28)
                          : _orange.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(20),`,
  `                      color: isFinalized
                          ? AppColors.accent.withValues(alpha: 0.28)
                          : AppColors.sand,
                      borderRadius: BorderRadius.circular(20),`,
);

replaceOnce(
  '조편성 상태 뱃지 글자',
  `                        color: isFinalized
                            ? Colors.white
                            : _orangeDeep,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),`,
  `                        color: isFinalized
                            ? AppColors.accent
                            : AppColors.inkSoft,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),`,
);

replaceOnce(
  '조편성 편집 칩',
  `                          color: isFinalized
                              ? Colors.white.withValues(alpha: 0.28)
                              : _orange.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(8),`,
  `                          color: isFinalized
                              ? AppColors.accent.withValues(alpha: 0.28)
                              : AppColors.sand,
                          borderRadius: BorderRadius.circular(8),`,
);

replaceOnce(
  '조편성 편집 아이콘',
  `                              Icons.edit_rounded,
                              size: 13,
                              color: isFinalized
                                  ? Colors.white
                                  : _orangeDeep,`,
  `                              Icons.edit_rounded,
                              size: 13,
                              color: isFinalized
                                  ? AppColors.accent
                                  : AppColors.goldDeep,`,
);

replaceOnce(
  '조편성 편집 글자',
  `                                fontWeight: FontWeight.w700,
                                color: isFinalized
                                    ? Colors.white
                                    : _orangeDeep,`,
  `                                fontWeight: FontWeight.w700,
                                color: isFinalized
                                    ? AppColors.accent
                                    : AppColors.goldDeep,`,
);

// 미확정 안내 다이얼로그 (비총무가 탭했을 때)
replaceOnce(
  '조편성 안내 다이얼로그 아이콘',
  `                      color: AppColors.sageLighter,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.groups_rounded,
                        color: AppColors.primary, size: 22),`,
  `                      color: AppColors.cream2,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.groups_rounded,
                        color: AppColors.goldDeep, size: 22),`,
);

replaceOnce(
  '조편성 안내 다이얼로그 본문',
  `                      color: AppColors.sageLighter,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.schedule_rounded,
                            size: 18, color: AppColors.primary),`,
  `                      color: AppColors.cream2,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.schedule_rounded,
                            size: 18, color: AppColors.goldDeep),`,
);

replaceOnce(
  '조편성 안내 다이얼로그 확인 버튼',
  `                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('확인'),`,
  `                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.charcoal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('확인'),`,
);

// 남은 _orange / _orangeDeep 참조 정리
replaceAll('_orange 잔여', '_orange.', '_gold.', 0);
replaceAll('_orangeDeep 잔여', '_orangeDeep', '_goldDeep', 0);

// ────────────────────────────────────────────────────────────
// 4. 참석 현황 — 그린 강조를 딥골드로
// ────────────────────────────────────────────────────────────
replaceOnce(
  '참석 현황 제목 바',
  `                      width: 4, height: 16,
                      decoration: BoxDecoration(
                        color: AppColors.success,`,
  `                      width: 4, height: 16,
                      decoration: BoxDecoration(
                        color: AppColors.accent,`,
);

replaceOnce(
  '참석 통계',
  `                    _StatItem(count: confirmed.length, label: '참석', color: AppColors.success),`,
  `                    _StatItem(count: confirmed.length, label: '참석', color: AppColors.goldDeep),`,
);

replaceOnce(
  '참석 명단 섹션',
  `                _MemberListSection(label: '참석', color: AppColors.success, members: confirmed),`,
  `                _MemberListSection(label: '참석', color: AppColors.goldDeep, members: confirmed),`,
);

// ────────────────────────────────────────────────────────────
// 5. 대기 명단 — 수락 버튼 그린 제거
// ────────────────────────────────────────────────────────────
replaceOnce(
  '대기 수락 스낵바·버튼',
  `                                        _snack('참석이 확정되었습니다 ✅', AppColors.success),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.success,`,
  `                                        _snack('참석이 확정되었습니다 ✅', AppColors.charcoal),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.charcoal,`,
);

replaceOnce(
  '대기 상태색',
  `      case WaitingStatus.accepted:  return AppColors.success;`,
  `      case WaitingStatus.accepted:  return AppColors.goldDeep;`,
);

// ────────────────────────────────────────────────────────────
// 6. 스코어 & 시상 — 그린 전면 교체
// ────────────────────────────────────────────────────────────
replaceOnce(
  '스코어 트로피 아이콘',
  `                const Icon(Icons.emoji_events_rounded,
                    color: AppColors.primary, size: 18),`,
  `                const Icon(Icons.emoji_events_rounded,
                    color: AppColors.goldDeep, size: 18),`,
);

replaceOnce(
  '스코어 조별 입력 칩',
  `                      color: AppColors.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('조별로 입력',
                        style: TextStyle(
                            color: AppColors.primary,`,
  `                      color: AppColors.accent.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('조별로 입력',
                        style: TextStyle(
                            color: AppColors.goldDeep,`,
);

replaceOnce(
  '스코어 입력 버튼',
  `                        color: AppColors.primary.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.25)),
                      ),
                      child: const Column(
                        children: [
                          Text('📊', style: TextStyle(fontSize: 24)),
                          SizedBox(height: 6),
                          Text(
                            '스코어 입력',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryDark,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            '조 선택 후 입력',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.primary,
                            ),`,
  `                        color: AppColors.cream2,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.sand),
                      ),
                      child: const Column(
                        children: [
                          Text('📊', style: TextStyle(fontSize: 24)),
                          SizedBox(height: 6),
                          Text(
                            '스코어 입력',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            '조 선택 후 입력',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.goldDeep,
                            ),`,
);

replaceOnce(
  '시상 내역 버튼',
  `                        color: AppColors.primary.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.25)),
                      ),
                      child: const Column(
                        children: [
                          Text('🏆', style: TextStyle(fontSize: 24)),
                          SizedBox(height: 6),
                          Text(
                            '시상 내역',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryDark,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            '수상자 보기/등록',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.primary,
                            ),`,
  `                        color: AppColors.cream2,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.sand),
                      ),
                      child: const Column(
                        children: [
                          Text('🏆', style: TextStyle(fontSize: 24)),
                          SizedBox(height: 6),
                          Text(
                            '시상 내역',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            '수상자 보기/등록',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.goldDeep,
                            ),`,
);

// ────────────────────────────────────────────────────────────

if (failed.length) {
  console.error('실패한 패치:');
  for (const f of failed) console.error('  - ' + f);
  process.exit(1);
}

fs.writeFileSync(FILE, src, 'utf8');
console.log(`적용 ${applied}건 · ${FILE}`);
