class PastAwardDraft {
  final String awardName;
  final String awardIcon;
  final List<String> winnerIds;

  const PastAwardDraft({
    required this.awardName,
    required this.awardIcon,
    required this.winnerIds,
  });
}

/// 기억나는 날짜가 없을 때 지난 일정 탭에 넣을 날짜.
class PastScheduleImport {
  static int? monthFromTitle(String title) {
    final m = RegExp(r'(\d+)\s*월').firstMatch(title.trim());
    if (m == null) return null;
    final n = int.tryParse(m.group(1)!);
    if (n == null || n < 1 || n > 12) return null;
    return n;
  }

  static DateTime resolveRoundDate({
    required String title,
    DateTime? roundDate,
    int? monthHint,
    DateTime? now,
  }) {
    final n = now ?? DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    if (roundDate != null) {
      final d = DateTime(roundDate.year, roundDate.month, roundDate.day);
      if (d.isBefore(today)) return d;
    }
    final month = monthHint ?? monthFromTitle(title) ?? (n.month == 1 ? 12 : n.month - 1);
    var d = DateTime(n.year, month, 15);
    if (!d.isBefore(today)) d = DateTime(n.year, month, 1);
    if (!d.isBefore(today)) d = DateTime(n.year - 1, month, 15);
    return d;
  }
}
