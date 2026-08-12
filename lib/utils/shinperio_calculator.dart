import 'dart:math';
import '../services/score_ocr_service.dart' show kStandardPars;

// ════════════════════════════════════════════════════════════
//  ShinperioCalculator — 신페리오 핸디캡 계산 엔진
//
//  신페리오 방식:
//    1) 전체 18홀 중 무작위 12홀 선정
//       (전반 6홀 + 후반 6홀)
//    2) 선정된 12홀 타수 합산
//    3) 핸디캡 = (12홀 합계 × 1.5) - 72
//       최대 핸디캡: 36 (제한)
//    4) 넷스코어 = 그로스(18홀 합계) - 핸디캡
//    5) 넷스코어 기준 오름차순 순위
// ════════════════════════════════════════════════════════════

/// 한 선수의 신페리오 계산 결과
class ShinperioPlayerResult {
  final String memberId;
  final String memberName;

  /// 18홀 타수 (index 0~17, null = 미입력)
  final List<int?> holes;

  /// 신페리오 선정 12홀 인덱스 (0-based)
  final List<int> selectedHoleIndices;

  /// 선정 12홀 타수 합계
  final int selectedSum;

  /// 핸디캡 (소수점 포함, 최대 36)
  final double handicap;

  /// 그로스 (18홀 합계)
  final int grossScore;

  /// 넷스코어 (그로스 - 핸디캡, 반올림)
  final int netScore;

  /// 순위 (1-based, 동점 동순위)
  int rank;

  ShinperioPlayerResult({
    required this.memberId,
    required this.memberName,
    required this.holes,
    required this.selectedHoleIndices,
    required this.selectedSum,
    required this.handicap,
    required this.grossScore,
    required this.netScore,
    this.rank = 0,
  });

  /// 특정 홀이 신페리오 선정 홀인지
  bool isSelectedHole(int holeIndex) =>
      selectedHoleIndices.contains(holeIndex);

  /// 파 대비 상대 타수 문자열 (+1, -1, E)
  String relativeScoreStr(int holeIndex) {
    final score = holes[holeIndex];
    if (score == null) return '-';
    final par = kStandardPars[holeIndex];
    final diff = score - par;
    if (diff == 0) return 'E';
    if (diff > 0) return '+$diff';
    return '$diff';
  }

  /// 홀 스코어 표시용 색상 코드
  static const int colorEagle = 0xFFFFD700;  // 금색
  static const int colorBirdie = 0xFFEF5350; // 빨강
  static const int colorPar = 0xFF1E1B4B;    // 진청
  static const int colorBogey = 0xFF0C5B43;  // 딥 그린 민트
  static const int colorDouble = 0xFF0C5B43;  // 딥 그린 민트
  static const int colorTriple = 0xFF757575; // 회색
}

/// 신페리오 전체 계산 결과
class ShinperioResult {
  /// 선정된 12홀 (0-based 인덱스, 정렬됨)
  final List<int> selectedHoleIndices;

  /// 선수별 결과 (순위 오름차순 정렬)
  final List<ShinperioPlayerResult> players;

  /// 계산 시각
  final DateTime calculatedAt;

  ShinperioResult({
    required this.selectedHoleIndices,
    required this.players,
    DateTime? calculatedAt,
  }) : calculatedAt = calculatedAt ?? DateTime.now();

  /// 1위 선수
  ShinperioPlayerResult? get champion =>
      players.isNotEmpty ? players.first : null;
}

/// 계산 입력 데이터 (선수 1명)
class ShinperioInput {
  final String memberId;
  final String memberName;

  /// 18홀 **상대값** (index 0~17). 파=0, 보기=+1, 버디=-1 … null = 미입력
  final List<int?> holes;

  const ShinperioInput({
    required this.memberId,
    required this.memberName,
    required this.holes,
  });

  /// 홀 인덱스 i의 절대타수 반환 (null이면 해당 홀 파수 대체)
  int absoluteScore(int i) {
    final rel = holes[i];
    return kStandardPars[i] + (rel ?? 0);
  }
}

class ShinperioCalculator {
  // ── 핵심 계산 ──────────────────────────────────────────────
  /// 신페리오 계산 실행
  /// [inputs] 선수 목록 (18홀 타수 포함)
  /// [selectedHoles] 미리 선정된 12홀 인덱스 (null이면 랜덤 선정)
  static ShinperioResult calculate(
    List<ShinperioInput> inputs, {
    List<int>? selectedHoles,
    int? randomSeed,
  }) {
    // 12홀 선정
    final holes = selectedHoles ?? _selectHoles(seed: randomSeed);

    // 선수별 계산
    final results = <ShinperioPlayerResult>[];
    for (final input in inputs) {
      if (input.holes.length != 18) continue;

      // 그로스: 18홀 절대타수 합계 (상대값 → par+rel 변환)
      int gross = 0;
      for (int i = 0; i < 18; i++) {
        gross += input.absoluteScore(i);
      }

      // 12홀 합산 (절대타수)
      int selectedSum = 0;
      for (final idx in holes) {
        selectedSum += input.absoluteScore(idx);
      }

      // 핸디캡 = (12홀합 × 1.5) - 72, 최대 36, 최소 0
      double handicap = (selectedSum * 1.5) - 72;
      handicap = handicap.clamp(0, 36);

      // 넷스코어 = 그로스 - 핸디캡 (반올림)
      final net = (gross - handicap).round();

      results.add(ShinperioPlayerResult(
        memberId: input.memberId,
        memberName: input.memberName,
        holes: input.holes,          // 상대값 그대로 보존 (표시용)
        selectedHoleIndices: holes,
        selectedSum: selectedSum,    // 절대타수 합계
        handicap: handicap,
        grossScore: gross,           // 절대타수 합계
        netScore: net,
      ));
    }

    // 넷스코어 기준 오름차순 정렬 후 순위 부여
    results.sort((a, b) => a.netScore.compareTo(b.netScore));
    _assignRanks(results);

    return ShinperioResult(
      selectedHoleIndices: holes,
      players: results,
    );
  }

  // ── 12홀 랜덤 선정 ─────────────────────────────────────────
  /// 전반(0~8) 6홀 + 후반(9~17) 6홀 랜덤 선정 (public)
  static List<int> selectHoles({int? seed}) {
    return _selectHoles(seed: seed);
  }

  /// internal
  static List<int> _selectHoles({int? seed}) {
    final rng = seed != null ? Random(seed) : Random();

    final frontIndices = List.generate(9, (i) => i)..shuffle(rng);
    final backIndices = List.generate(9, (i) => i + 9)..shuffle(rng);

    final selected = [
      ...frontIndices.take(6),
      ...backIndices.take(6),
    ];
    selected.sort();
    return selected;
  }

  // ── 순위 부여 (동점 동순위) ────────────────────────────────
  static void _assignRanks(List<ShinperioPlayerResult> sorted) {
    if (sorted.isEmpty) return;
    int currentRank = 1;
    sorted[0].rank = currentRank;

    for (int i = 1; i < sorted.length; i++) {
      if (sorted[i].netScore == sorted[i - 1].netScore) {
        sorted[i].rank = currentRank;
      } else {
        currentRank = i + 1;
        sorted[i].rank = currentRank;
      }
    }
  }

  // ── 핸디캡 계산 단독 (UI 미리보기용) ─────────────────────
  /// 12홀 타수 합계로 핸디캡만 계산
  static double calcHandicap(int selectedSum) {
    return ((selectedSum * 1.5) - 72).clamp(0, 36).toDouble();
  }

  /// 넷스코어 계산
  static int calcNetScore(int gross, double handicap) {
    return (gross - handicap).round();
  }

  // ── 홀별 색상 ─────────────────────────────────────────────
  /// [relScore] 는 **상대값** (파=0, 보기=+1, 버디=-1 …)
  /// par 파라미터는 더 이상 사용하지 않지만 하위 호환성 유지
  static HoleScoreStyle getHoleStyle(int? relScore, [int par = 0]) {
    if (relScore == null) return HoleScoreStyle.empty;
    if (relScore <= -2) return HoleScoreStyle.eagle;
    if (relScore == -1) return HoleScoreStyle.birdie;
    if (relScore ==  0) return HoleScoreStyle.par;
    if (relScore ==  1) return HoleScoreStyle.bogey;
    if (relScore ==  2) return HoleScoreStyle.double_;
    return HoleScoreStyle.triple;
  }

  // ── 파수 가져오기 ────────────────────────────────────────
  static int getPar(int holeIndex) => kStandardPars[holeIndex];

  // ── 홀 이름 (1-based) ─────────────────────────────────────
  static String holeName(int index) => '${index + 1}번';

  // ── 전반/후반 판별 ───────────────────────────────────────
  static bool isFrontNine(int holeIndex) => holeIndex < 9;
  static bool isBackNine(int holeIndex) => holeIndex >= 9;
}

// ── 홀 스코어 스타일 열거형 ──────────────────────────────────
enum HoleScoreStyle {
  empty,   // 미입력
  eagle,   // 이글 이하
  birdie,  // 버디
  par,     // 파
  bogey,   // 보기
  double_, // 더블보기
  triple,  // 트리플 이상
}

extension HoleScoreStyleExt on HoleScoreStyle {
  bool get hasCircle => this == HoleScoreStyle.birdie || this == HoleScoreStyle.eagle;
  bool get hasSquare => this == HoleScoreStyle.bogey || this == HoleScoreStyle.double_ || this == HoleScoreStyle.triple;

  int get bgColor {
    switch (this) {
      case HoleScoreStyle.eagle:
        return 0xFFFFD700;
      case HoleScoreStyle.birdie:
        return 0xFFEF5350;
      case HoleScoreStyle.par:
        return 0xFFFFFFFF;
      case HoleScoreStyle.bogey:
        return 0xFFE8F5E9;
      case HoleScoreStyle.double_:
        return 0xFFE3F2FD;
      case HoleScoreStyle.triple:
        return 0xFFF5F5F5;
      case HoleScoreStyle.empty:
        return 0xFFF5F5F5;
    }
  }

  int get textColor {
    switch (this) {
      case HoleScoreStyle.eagle:
        return 0xFF5D4037;
      case HoleScoreStyle.birdie:
        return 0xFFFFFFFF;
      case HoleScoreStyle.par:
        return 0xFF1E1B4B;
      case HoleScoreStyle.bogey:
        return 0xFF0C5B43;
      case HoleScoreStyle.double_:
        return 0xFF084533;  // primaryDark
      case HoleScoreStyle.triple:
        return 0xFF757575;
      case HoleScoreStyle.empty:
        return 0xFFBBBBBB;
    }
  }
}
