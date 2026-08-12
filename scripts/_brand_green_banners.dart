import "dart:convert";
import "dart:io";

void main() {
  final f = File("lib/screens/schedule/schedule_screen.dart");
  var t = f.readAsStringSync(encoding: utf8);
  final crlf = t.contains("\r\n");
  t = t.replaceAll("\r\n", "\n");

  // Patch _GroupViewBannerCard._groupColors (first occurrence near class)
  const greenColors = """  static const List<Color> _groupColors = [
    AppColors.primary,
    AppColors.primaryLight,
    Color(0xFF3D6B5A),
    Color(0xFF5A8F7B),
    Color(0xFF2F5C4C),
    Color(0xFF4A7A68),
  ];""";

  final orangeColors = RegExp(
    r"static const List<Color> _groupColors = \[\s*"
    r"AppColors\.primary,\s*AppColors\.primaryLight,\s*"
    r"Color\(0xFFE65100\),\s*"
    r"Color\(0xFF6A1B9A\),\s*"
    r"Color\(0xFF00838F\),\s*"
    r"Color\(0xFFC62828\),\s*"
    r"\];",
  );
  var n = 0;
  t = t.replaceAllMapped(orangeColors, (m) {
    n++;
    return greenColors;
  });
  print("groupColors patches=$n");

  // Replace orange palette inside GroupViewBannerCard region only
  final gvStart = t.indexOf("class _GroupViewBannerCard");
  final gvEnd = t.indexOf("class _GroupRow");
  if (gvStart < 0 || gvEnd < 0) {
    stderr.writeln("GroupView markers missing");
    exit(2);
  }
  var gv = t.substring(gvStart, gvEnd);
  final gvBefore = gv;

  // Border / shadow / gradients / text oranges → brand
  final map = <String, String>{
    "const Color(0xFFFF8F00).withValues(alpha: 0.5)":
        "AppColors.primary.withValues(alpha: 0.45)",
    "const Color(0xFFFFB300).withValues(alpha: 0.3)": "AppColors.divider",
    "const Color(0xFFFF8F00).withValues(alpha: 0.15)":
        "AppColors.primary.withValues(alpha: 0.08)",
    "const Color(0xFFFFB300).withValues(alpha: 0.08)":
        "AppColors.primary.withValues(alpha: 0.08)",
    """gradient: isFinalized
                    ? const LinearGradient(
                        colors: [Color(0xFFFF8F00), Color(0xFFFFB300)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : const LinearGradient(
                        colors: [Color(0xFFFFF8E1), Color(0xFFFFFDE7)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                color: null,""":
        """color: isFinalized
                    ? AppColors.primary
                    : AppColors.sageLighter,""",
    "const Color(0xFFFFB300).withValues(alpha: 0.2)":
        "AppColors.primary.withValues(alpha: 0.12)",
    "const Color(0xFFFF8F00)": "AppColors.primary",
    "const Color(0xFFE65100)": "AppColors.textPrimary",
    "const Color(0xFFBF360C).withValues(alpha: 0.7)": "AppColors.textSecondary",
    "Colors.white.withValues(alpha: 0.25)": "Colors.white.withValues(alpha: 0.2)",
  };

  for (final e in map.entries) {
    if (gv.contains(e.key)) {
      gv = gv.replaceAll(e.key, e.value);
      print("GV replaced: ${e.key.substring(0, e.key.length > 40 ? 40 : e.key.length)}...");
    } else {
      print("GV miss: ${e.key.substring(0, e.key.length > 50 ? 50 : e.key.length)}");
    }
  }

  // Remaining FFFF8F00 / FFFFB300 / E65100 in GV
  gv = gv.replaceAll("Color(0xFFFF8F00)", "AppColors.primary");
  gv = gv.replaceAll("Color(0xFFFFB300)", "AppColors.primaryLight");
  gv = gv.replaceAll("Color(0xFFE65100)", "AppColors.primary");
  gv = gv.replaceAll("Color(0xFFBF360C)", "AppColors.textSecondary");

  if (gv == gvBefore) {
    print("WARNING: GroupView unchanged");
  } else {
    t = t.substring(0, gvStart) + gv + t.substring(gvEnd);
    print("GroupView patched lenDelta=${gv.length - gvBefore.length}");
  }

  // ScoreAward banner region
  final saStart = t.indexOf("class _ScoreAwardBannerCard");
  final saEnd = t.indexOf("class _GroupSelectSheet");
  if (saStart < 0 || saEnd < 0) {
    stderr.writeln("ScoreAward markers missing");
    exit(3);
  }
  var sa = t.substring(saStart, saEnd);
  final saBefore = sa;

  // Rebuild the build() method of ScoreAward with brand colors, keep Korean via surgical color/icon swaps
  sa = sa.replaceAll("color: const Color(0xFFEEEEEE)", "color: AppColors.divider");
  sa = sa.replaceAll(
      "color: Colors.black.withValues(alpha: 0.06)",
      "color: AppColors.primary.withValues(alpha: 0.06)");
  sa = sa.replaceAll(
      "const Icon(Icons.emoji_events_outlined,\n                    color: Color(0xFF999999), size: 15)",
      "const Icon(Icons.emoji_events_outlined,\n                    color: AppColors.primary, size: 18)");
  sa = sa.replaceAll(
      """style: const TextStyle(
                    color: Color(0xFF999999),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),""",
      """style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),""");
  sa = sa.replaceAll(
      "color: const Color(0xFFF97316).withValues(alpha: 0.10)",
      "color: AppColors.sageLighter");
  sa = sa.replaceAll(
      """child: const Text('조별로 입력',
                        style: TextStyle(
                            color: Color(0xFFF97316),
                            fontSize: 10,
                            fontWeight: FontWeight.w600)),""",
      """child: const Text('조별로 입력',
                        style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),""");
  sa = sa.replaceAll(
      """style: const TextStyle(
                color: Color(0xFF222222),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),""",
      """style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),""");
  sa = sa.replaceAll(
      """style: const TextStyle(
                color: Color(0xFF999999),
                fontSize: 12,
              ),""",
      """style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),""");

  // Score button (orange → green)
  sa = sa.replaceAll(
      """decoration: BoxDecoration(
                        color: const Color(0xFFF97316).withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: const Color(0xFFF97316).withValues(alpha: 0.25)),
                      ),
                      child: const Column(
                        children: [
                          Text('📊', style: TextStyle(fontSize: 24)),
                          SizedBox(height: 6),
                          Text(
                            '스코어 입력',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFEA580C),
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            '조 선택 후 입력',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFFF97316),
                            ),
                          ),
                        ],
                      ),""",
      """decoration: BoxDecoration(
                        color: AppColors.sageLighter,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.22)),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.bar_chart_rounded,
                              size: 26, color: AppColors.primary),
                          SizedBox(height: 8),
                          Text(
                            '스코어 입력',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            '조 선택 후 입력',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),""");

  // Award button (purple → muted green/surface)
  sa = sa.replaceAll(
      """decoration: BoxDecoration(
                        color: const Color(0xFF7C3AED).withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: const Color(0xFF7C3AED).withValues(alpha: 0.25)),
                      ),
                      child: const Column(
                        children: [
                          Text('🏆', style: TextStyle(fontSize: 24)),
                          SizedBox(height: 6),
                          Text(
                            '시상 내역',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF6D28D9),
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            '수상자 보기/등록',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF7C3AED),
                            ),
                          ),
                        ],
                      ),""",
      """decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.emoji_events_rounded,
                              size: 26, color: AppColors.primary),
                          SizedBox(height: 8),
                          Text(
                            '시상 내역',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            '수상자 보기/등록',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),""");

  // Sweep leftovers in SA
  sa = sa.replaceAll("Color(0xFFF97316)", "AppColors.primary");
  sa = sa.replaceAll("Color(0xFFEA580C)", "AppColors.primary");
  sa = sa.replaceAll("Color(0xFF7C3AED)", "AppColors.primary");
  sa = sa.replaceAll("Color(0xFF6D28D9)", "AppColors.primary");

  if (sa == saBefore) {
    print("WARNING: ScoreAward unchanged");
  } else {
    t = t.substring(0, saStart) + sa + t.substring(saEnd);
    print("ScoreAward patched lenDelta=${sa.length - saBefore.length}");
  }

  print("remain FFFF8F00=${t.contains('0xFFFF8F00')} F97316=${t.contains('0xFFF97316')} 7C3AED=${t.contains('0xFF7C3AED')} E65100=${t.contains('0xFFE65100')}");
  print("korean 조편성 보기=${t.contains('조편성 보기')} 스코어 입력=${t.contains('스코어 입력')} 시상 내역=${t.contains('시상 내역')}");

  if (crlf) t = t.replaceAll("\n", "\r\n");
  f.writeAsStringSync(t, encoding: utf8);
  print("WROTE OK");
}
