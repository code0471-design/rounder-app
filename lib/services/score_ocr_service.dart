import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// ════════════════════════════════════════════════════════════
//  ScoreOcrService — GPT-4o Vision으로 스마트스코어 스코어카드 인식
//  웹 / 앱 모두 지원 (Uint8List 기반)
// ════════════════════════════════════════════════════════════

// ── 기존: 총타수 기반 OCR 결과 ────────────────────────────────
class OcrPlayerScore {
  final String name;
  final int? totalScore;
  final bool uncertain;
  final String rawText;

  OcrPlayerScore({
    required this.name,
    this.totalScore,
    this.uncertain = false,
    this.rawText = '',
  });

  OcrPlayerScore copyWith({
    String? name,
    int? totalScore,
    bool? uncertain,
    String? rawText,
  }) {
    return OcrPlayerScore(
      name: name ?? this.name,
      totalScore: totalScore ?? this.totalScore,
      uncertain: uncertain ?? this.uncertain,
      rawText: rawText ?? this.rawText,
    );
  }
}

class ScoreOcrResult {
  final bool success;
  final List<OcrPlayerScore> players;
  final String? errorMessage;
  final String? rawGptResponse;

  ScoreOcrResult({
    required this.success,
    this.players = const [],
    this.errorMessage,
    this.rawGptResponse,
  });
}

// ── 신규: 홀별 타수 기반 OCR 결과 (신페리오용) ─────────────────
/// 한 선수의 홀별 타수 데이터 (전반 9홀 또는 후반 9홀)
class OcrPlayerHoleData {
  final String name;

  /// 9개 원소 (null = 미인식). **상대값** (파=0, 보기=+1, 버디=-1, 더블=+2 …)
  final List<int?> holes;

  /// 인식 불확실 여부
  final bool uncertain;

  OcrPlayerHoleData({
    required this.name,
    required this.holes,
    this.uncertain = false,
  }) : assert(holes.length == 9, 'holes must have exactly 9 elements');

  /// 9홀 합계 (null 홀 제외)
  int get subtotal => holes.whereType<int>().fold(0, (a, b) => a + b);

  /// null 없이 모두 인식됐는지
  bool get isComplete => holes.every((h) => h != null);

  OcrPlayerHoleData copyWith({
    String? name,
    List<int?>? holes,
    bool? uncertain,
  }) {
    return OcrPlayerHoleData(
      name: name ?? this.name,
      holes: holes ?? List.from(this.holes),
      uncertain: uncertain ?? this.uncertain,
    );
  }
}

/// 신페리오 OCR 결과 (전반 또는 후반 한 이미지 분석 결과)
class ShinperioOcrResult {
  final bool success;
  final List<OcrPlayerHoleData> players;
  final String? errorMessage;
  final String? rawGptResponse;

  /// 'front' | 'back'
  final String half;

  ShinperioOcrResult({
    required this.success,
    required this.half,
    this.players = const [],
    this.errorMessage,
    this.rawGptResponse,
  });
}

// ── 파수 테이블 (표준 18홀 파72) ──────────────────────────────
/// index 0~17 → 홀1~홀18 파수
/// 파3 4개, 파4 10개, 파5 4개 = 총 72
const List<int> kStandardPars = [
  4, 4, 3, 4, 5, 4, 3, 4, 5, // 전반 1~9 (합 36)
  4, 3, 4, 5, 4, 4, 3, 5, 4, // 후반 10~18 (합 36)
];

class ScoreOcrService {
  /// Set via `--dart-define=OPENAI_API_KEY=...` (never commit real keys).
  static const String _apiKey = String.fromEnvironment('OPENAI_API_KEY');

  static const String _endpoint =
      'https://api.openai.com/v1/chat/completions';

  // ════════════════════════════════════════════════════════
  //  기존 메서드 — 총타수 추출 (ScoreOcrScreen에서 사용)
  // ════════════════════════════════════════════════════════
  static Future<ScoreOcrResult> analyzeScorecardBytes(
    Uint8List imageBytes, {
    String mimeType = 'image/jpeg',
  }) async {
    try {
      final base64Image = base64Encode(imageBytes);

      final requestBody = {
        'model': 'gpt-4o',
        'max_tokens': 1000,
        'messages': [
          {
            'role': 'user',
            'content': [
              {
                'type': 'text',
                'text': '''이 이미지는 스마트스코어(SmartScore) 골프 앱의 스코어카드 화면입니다.

⚠️ 중요 주의사항:
- 이미지가 90도 또는 180도 회전되어 있을 수 있습니다. 어떤 방향이든 올바르게 읽어주세요.
- 한글 이름이 세로로 쓰여 있거나 옆으로 누워있을 수 있습니다. 한글 자모를 정확히 조합해서 읽어주세요.
- 스마트스코어 화면에서 이름은 보통 상단 또는 좌측 열에 표시됩니다.
- 합계 타수는 보통 70~130 사이의 숫자입니다. 이 범위를 벗어난 숫자는 합계가 아닐 가능성이 높습니다.
- 핸디캡 적용 점수(-1, 0, 1 같은 작은 숫자)와 실제 합계 타수를 혼동하지 마세요.

각 플레이어의 이름과 최종 총 타수(18홀 합계)를 추출해주세요.

반드시 아래 JSON 형식으로만 응답하세요. 다른 설명 없이 JSON만 출력하세요:
{
  "players": [
    {
      "name": "홍길동",
      "total_score": 92,
      "uncertain": false
    }
  ]
}

규칙:
- name: 스코어카드에 적힌 한글 이름 (2~3글자, 정확히 읽기)
- total_score: 18홀 최종 합계 타수 (70~130 범위의 숫자)
- uncertain: 이름이나 숫자가 불명확하면 true
- 합계 행이 여러 개면 가장 큰 숫자(최종 18홀 합산)를 사용
- 이름을 도저히 읽을 수 없으면 "선수1", "선수2" 등으로 표기
- 스코어카드가 아닌 경우 players를 빈 배열로 반환''',
              },
              {
                'type': 'image_url',
                'image_url': {
                  'url': 'data:$mimeType;base64,$base64Image',
                  'detail': 'high',
                },
              },
            ],
          },
        ],
      };

      final response = await http
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_apiKey',
            },
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        final errBody = jsonDecode(response.body);
        final errMsg = errBody['error']?['message'] ?? response.body;
        return ScoreOcrResult(
          success: false,
          errorMessage: 'API 오류 (${response.statusCode}): $errMsg',
        );
      }

      final responseJson = jsonDecode(response.body);
      final content =
          responseJson['choices'][0]['message']['content'] as String;

      String jsonStr = content.trim();
      if (jsonStr.startsWith('```')) {
        jsonStr = jsonStr
            .replaceAll(RegExp(r'```json\n?'), '')
            .replaceAll(RegExp(r'```\n?'), '')
            .trim();
      }

      final parsed = jsonDecode(jsonStr);
      final playersList = parsed['players'] as List<dynamic>;

      if (playersList.isEmpty) {
        return ScoreOcrResult(
          success: false,
          errorMessage: '스코어카드를 인식하지 못했습니다.\n스코어카드 사진인지 확인해주세요.',
        );
      }

      final players = playersList.map((p) {
        return OcrPlayerScore(
          name: p['name']?.toString() ?? '이름 미상',
          totalScore: p['total_score'] != null
              ? int.tryParse(p['total_score'].toString())
              : null,
          uncertain: p['uncertain'] == true,
          rawText: jsonStr,
        );
      }).toList();

      return ScoreOcrResult(
        success: true,
        players: players,
        rawGptResponse: content,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('OCR error: $e');
      return ScoreOcrResult(
        success: false,
        errorMessage: '분석 중 오류가 발생했습니다.\n인터넷 연결을 확인해주세요.\n($e)',
      );
    }
  }

  // ════════════════════════════════════════════════════════
  //  신규 메서드 — 홀별 타수 추출 (신페리오용)
  //
  //  스마트스코어 입력 방식:
  //    파=0, 버디=-1, 이글=-2, 보기=+1, 더블보기=+2, 트리플+=+3
  //  → 실제 타수 = 해당 홀 파수 + 상대값
  // ════════════════════════════════════════════════════════
  static Future<ShinperioOcrResult> analyzeHoleScores(
    Uint8List imageBytes, {
    required String half, // 'front' | 'back'
    String mimeType = 'image/jpeg',
  }) async {
    assert(half == 'front' || half == 'back');

    final isFront = half == 'front';
    final halfLabel = isFront ? '전반(1~9홀)' : '후반(10~18홀)';

    try {
      final base64Image = base64Encode(imageBytes);

      final requestBody = {
        'model': 'gpt-4o',
        'max_tokens': 2000,
        'messages': [
          {
            'role': 'user',
            'content': [
              {
                'type': 'text',
                'text': '''이 이미지는 스마트스코어(SmartScore) 골프 앱의 $halfLabel 스코어카드입니다.

━━━ 스마트스코어 표시 방식 ━━━
스마트스코어는 파 기준 상대값(±숫자)을 표시합니다:
  화면에 "0" → 파(par) → 0을 반환
  화면에 "1" → 보기(bogey) → 1을 반환  
  화면에 "2" → 더블보기 → 2를 반환
  화면에 "-1" 또는 빨간 동그라미 → 버디 → -1을 반환
  화면에 "-2" 또는 이중 동그라미 → 이글 → -2를 반환
  빈 칸 또는 "E" → 파 → 0을 반환
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🚨 가장 중요한 규칙: 화면에 보이는 숫자를 그대로 읽으세요!

❌ 절대 하지 말 것: 타수로 변환하지 마세요!
예시 — 파4 홀에서 보기(화면에 1 표시)일 때:
  ❌ 잘못된 답: 5  (파4 + 보기1 = 5타로 변환한 것)
  ✅ 올바른 답: 1  (화면에 보이는 숫자 그대로)

파3 홀에서 보기(화면에 1 표시):
  ❌ 잘못된 답: 4
  ✅ 올바른 답: 1

파5 홀에서 더블보기(화면에 2 표시):
  ❌ 잘못된 답: 7
  ✅ 올바른 답: 2

⚠️ 기타 주의사항:
- 이미지가 회전되어 있어도 올바르게 읽어주세요
- 이름 행과 스코어 행을 정확히 매칭하세요
- 합계(SUM/합) 열은 제외하고 홀별 값만 추출하세요
- 홀 순서: ${isFront ? '1번~9번 (9개)' : '10번~18번 (9개)'}

반드시 아래 JSON 형식으로만 응답하세요 (JSON만, 설명 없이):
{
  "players": [
    {
      "name": "홍길동",
      "relative_holes": [1, 0, 2, 1, 0, 0, -1, 1, 0],
      "uncertain": false
    }
  ]
}

규칙:
- name: 한글 이름 (2~3글자)
- relative_holes: 9개 배열 — 화면에 보이는 숫자 그대로 (파=0, 보기=1, 더블=2, 버디=-1, 이글=-2, 인식불가=null)
- uncertain: 불확실하면 true
- 스코어카드가 아니면 players를 빈 배열로 반환''',
              },
              {
                'type': 'image_url',
                'image_url': {
                  'url': 'data:$mimeType;base64,$base64Image',
                  'detail': 'high',
                },
              },
            ],
          },
        ],
      };

      final response = await http
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_apiKey',
            },
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 45));

      if (response.statusCode != 200) {
        final errBody = jsonDecode(response.body);
        final errMsg = errBody['error']?['message'] ?? response.body;
        return ShinperioOcrResult(
          success: false,
          half: half,
          errorMessage: 'API 오류 (${response.statusCode}): $errMsg',
        );
      }

      final responseJson = jsonDecode(response.body);
      final content =
          responseJson['choices'][0]['message']['content'] as String;

      // JSON 추출 (마크다운 코드블록 제거)
      String jsonStr = content.trim();
      if (jsonStr.startsWith('```')) {
        jsonStr = jsonStr
            .replaceAll(RegExp(r'```json\n?'), '')
            .replaceAll(RegExp(r'```\n?'), '')
            .trim();
      }

      final parsed = jsonDecode(jsonStr);
      final playersList = parsed['players'] as List<dynamic>;

      if (playersList.isEmpty) {
        return ShinperioOcrResult(
          success: false,
          half: half,
          errorMessage: '스코어카드를 인식하지 못했습니다.\n$halfLabel 스코어카드 사진인지 확인해주세요.',
        );
      }

      final players = <OcrPlayerHoleData>[];
      for (final p in playersList) {
        // GPT가 relative_holes 또는 holes 키로 반환할 수 있음
        final rawHoles = (p['relative_holes'] ?? p['holes']) as List<dynamic>?;
        if (rawHoles == null) continue;

        // 상대값 그대로 저장 (-3 ~ +5 범위만 허용, 나머지 null)
        final relHoles = <int?>[];
        for (int i = 0; i < 9; i++) {
          if (i >= rawHoles.length) { relHoles.add(null); continue; }
          final val = rawHoles[i];
          if (val == null) { relHoles.add(null); continue; }
          final rel = int.tryParse(val.toString());
          // 유효 상대값 범위: -3(앨바트로스) ~ +6(최악)
          if (rel != null && rel >= -3 && rel <= 6) {
            relHoles.add(rel);
          } else {
            relHoles.add(null);
          }
        }

        players.add(OcrPlayerHoleData(
          name: p['name']?.toString() ?? '이름 미상',
          holes: relHoles,
          uncertain: p['uncertain'] == true,
        ));
      }

      return ShinperioOcrResult(
        success: true,
        half: half,
        players: players,
        rawGptResponse: content,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Shinperio OCR error: $e');
      return ShinperioOcrResult(
        success: false,
        half: half,
        errorMessage: '분석 중 오류가 발생했습니다.\n인터넷 연결을 확인해주세요.\n($e)',
      );
    }
  }

  // ════════════════════════════════════════════════════════
  //  유틸: 상대값 → 실제 타수 변환 (스마트스코어 포맷)
  //  파=0, 버디=-1, 이글=-2, 보기=+1, 더블=+2
  // ════════════════════════════════════════════════════════
  static int relativeToActual(int relativeScore, int par) {
    return par + relativeScore;
  }

  // ════════════════════════════════════════════════════════
  //  유틸: 18홀 중 신페리오용 12홀 랜덤 선정
  //  규칙: 전반(1~9) 6홀 + 후반(10~18) 6홀
  //       각 반에서 파3 2개, 파4 3개, 파5 1개 (표준)
  //       → 단순화: 각 반 랜덤 6홀
  // ════════════════════════════════════════════════════════
  static List<int> selectShinperioHoles({int? seed}) {
    final rng = seed != null ? Random(seed) : Random();

    // 전반 9홀(0~8) 중 6홀
    final frontIndices = List.generate(9, (i) => i)..shuffle(rng);
    final selected = [...frontIndices.take(6)];

    // 후반 9홀(9~17) 중 6홀
    final backIndices = List.generate(9, (i) => i + 9)..shuffle(rng);
    selected.addAll(backIndices.take(6));

    selected.sort();
    return selected; // 0-based 인덱스 12개
  }
}
