import "dart:convert";
import "dart:io";

void main() {
  final f = File("lib/screens/schedule/schedule_screen.dart");
  var t = f.readAsStringSync(encoding: utf8);
  final crlf = t.contains("\r\n");
  t = t.replaceAll("\r\n", "\n");

  const oldBlock = '''
                    children: [
                      // ── ① 내 응답 상태 카드 (최상단) ──
                      if (!isPast) _buildMyResponseCard(context, provider, current, myRes),

                      if (!isPast) const SizedBox(height: 16),

                      // ── ② 홀인원보험 배너 (비활성 — 필요 시 아래 2줄 주석 해제) ──
                      // if (!isPast) _InsuranceBannerCard(schedule: current),
                      // if (!isPast) const SizedBox(height: 16),

                      // ── ③ 조편성 보기 ──
                      _GroupViewBannerCard(
                        schedule: current,
                        provider: provider,
                        isAdmin: isAdmin,
                      ),

                      const SizedBox(height: 16),

                      // ── ④ 스코어/시상 카드 ──
                      _ScoreAwardBannerCard(schedule: current, isPast: isPast),

                      const SizedBox(height: 16),

                      // ── 일정 정보 카드 ──
                      _InfoCard(schedule: current),

                      const SizedBox(height: 16),

                      // ── 사진 섹션 (항상 업로드 가능) ──
                      _PhotoSection(schedule: current),

                      const SizedBox(height: 16),

                      // ── 라운딩 후기/메모 ──
                      _ReviewMemoCard(schedule: current),

                      const SizedBox(height: 16),

                      // ── 참석 현황 카드 ──
                      _AttendanceCard(schedule: current, isAdmin: isAdmin),

                      const SizedBox(height: 16),

                      // ── RSVP 마감 + 대기 명단 ──
                      _RsvpWaitingCard(schedule: current, isAdmin: isAdmin),

                      const SizedBox(height: 80),
                    ],
''';

  const newBlock = '''
                    children: [
                      // ── ① 내 응답 상태 카드 (최상단) ──
                      if (!isPast) _buildMyResponseCard(context, provider, current, myRes),

                      if (!isPast) const SizedBox(height: 16),

                      // ── ② 홀인원보험 배너 ──
                      if (!isPast) _InsuranceBannerCard(schedule: current),
                      if (!isPast) const SizedBox(height: 16),

                      // ── ③ 참석 현황 (신규 UI — 상단 노출) ──
                      _AttendanceCard(schedule: current, isAdmin: isAdmin),

                      const SizedBox(height: 16),

                      // ── ④ RSVP 마감 + 대기 명단 ──
                      _RsvpWaitingCard(schedule: current, isAdmin: isAdmin),

                      const SizedBox(height: 16),

                      // ── ⑤ 조편성 보기 ──
                      _GroupViewBannerCard(
                        schedule: current,
                        provider: provider,
                        isAdmin: isAdmin,
                      ),

                      const SizedBox(height: 16),

                      // ── ⑥ 스코어/시상 카드 ──
                      _ScoreAwardBannerCard(schedule: current, isPast: isPast),

                      const SizedBox(height: 16),

                      // ── ⑦ 일정 정보 카드 ──
                      _InfoCard(schedule: current),

                      const SizedBox(height: 16),

                      // ── ⑧ 사진 섹션 ──
                      _PhotoSection(schedule: current),

                      const SizedBox(height: 16),

                      // ── ⑨ 라운딩 후기/메모 ──
                      _ReviewMemoCard(schedule: current),

                      const SizedBox(height: 80),
                    ],
''';

  if (!t.contains(oldBlock)) {
    stderr.writeln("OLD BLOCK NOT FOUND");
    // debug nearby
    final i = t.indexOf("_buildMyResponseCard(context, provider, current, myRes)");
    stderr.writeln("idx=$i");
    if (i >= 0) stderr.writeln(t.substring(i - 80, i + 900));
    exit(2);
  }
  t = t.replaceFirst(oldBlock, newBlock);
  if (crlf) t = t.replaceAll("\n", "\r\n");
  f.writeAsStringSync(t, encoding: utf8);
  stdout.writeln("OK patched detail order + insurance");
}
