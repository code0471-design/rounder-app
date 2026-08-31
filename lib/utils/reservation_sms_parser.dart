import '../data/golf_courses_kr.dart';

/// 골프장 예약 문자에서 일정 등록에 쓸 값만 뽑는다.
class ReservationSmsParse {
  final DateTime? date;
  final int? hour;
  final int? minute;
  final String? courseName;
  final String? address;
  final String? titleHint;
  final int? teamCount;

  const ReservationSmsParse({
    this.date,
    this.hour,
    this.minute,
    this.courseName,
    this.address,
    this.titleHint,
    this.teamCount,
  });

  bool get hasAny =>
      date != null ||
      hour != null ||
      (courseName != null && courseName!.trim().isNotEmpty);
}

ReservationSmsParse parseReservationSms(
  String raw, {
  DateTime? now,
  List<GolfCourse> extras = const [],
}) {
  final text = raw.replaceAll('\r\n', '\n').trim();
  if (text.isEmpty) return const ReservationSmsParse();

  final today = now ?? DateTime.now();
  final date = _parseDate(text, today);
  final time = _parseTime(text);
  final course = _matchCourse(text, extras);
  final labeledCourse = _labeledCourse(text);
  final courseName = course?.name ?? labeledCourse;
  final address = course?.address;
  final people = _parsePeople(text);
  final teamCount = people == null ? null : ((people + 3) ~/ 4).clamp(1, 30);

  String? titleHint;
  if (date != null) {
    final monthTitle = '${date.month}월 라운딩';
    titleHint = courseName == null || courseName.isEmpty
        ? monthTitle
        : '${date.month}월 $courseName';
  } else if (courseName != null && courseName.isNotEmpty) {
    titleHint = courseName;
  }

  return ReservationSmsParse(
    date: date,
    hour: time?.$1,
    minute: time?.$2,
    courseName: courseName,
    address: address,
    titleHint: titleHint,
    teamCount: teamCount,
  );
}

DateTime? _parseDate(String text, DateTime today) {
  final ymdKo = RegExp(r'(\d{4})\s*년\s*(\d{1,2})\s*월\s*(\d{1,2})\s*일');
  var m = ymdKo.firstMatch(text);
  if (m != null) {
    return _ymd(int.parse(m.group(1)!), int.parse(m.group(2)!), int.parse(m.group(3)!));
  }

  final yyKo = RegExp(r'(\d{2})\s*년\s*(\d{1,2})\s*월\s*(\d{1,2})\s*일');
  m = yyKo.firstMatch(text);
  if (m != null) {
    return _ymd(2000 + int.parse(m.group(1)!), int.parse(m.group(2)!), int.parse(m.group(3)!));
  }

  final ymdNum = RegExp(r'(?<!\d)(\d{4})[.\-/](\d{1,2})[.\-/](\d{1,2})(?!\d)');
  m = ymdNum.firstMatch(text);
  if (m != null) {
    return _ymd(int.parse(m.group(1)!), int.parse(m.group(2)!), int.parse(m.group(3)!));
  }

  final yyNum = RegExp(r'(?<!\d)(\d{2})[.\-/](\d{1,2})[.\-/](\d{1,2})(?!\d)');
  m = yyNum.firstMatch(text);
  if (m != null) {
    final yy = int.parse(m.group(1)!);
    final month = int.parse(m.group(2)!);
    final day = int.parse(m.group(3)!);
    if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
      return _ymd(2000 + yy, month, day);
    }
  }

  final mdKo = RegExp(r'(?<!\d)(\d{1,2})\s*월\s*(\d{1,2})\s*일');
  m = mdKo.firstMatch(text);
  if (m != null) {
    return _mdAssumeYear(
      int.parse(m.group(1)!),
      int.parse(m.group(2)!),
      today,
    );
  }

  return null;
}

DateTime? _ymd(int year, int month, int day) {
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  try {
    return DateTime(year, month, day);
  } catch (_) {
    return null;
  }
}

DateTime? _mdAssumeYear(int month, int day, DateTime today) {
  final thisYear = _ymd(today.year, month, day);
  if (thisYear == null) return null;
  final yesterday = DateTime(today.year, today.month, today.day)
      .subtract(const Duration(days: 1));
  if (thisYear.isBefore(yesterday)) {
    return _ymd(today.year + 1, month, day);
  }
  return thisYear;
}

(int, int)? _parseTime(String text) {
  final labeled = RegExp(
    r'(?:티오프|티타임|티\s*타임|라운딩\s*일시|일시|시간|시각)\s*[:：]?\s*(오전|오후)?\s*(\d{1,2})\s*[:시]\s*(\d{0,2})',
  );
  var m = labeled.firstMatch(text);
  if (m != null) {
    return _clock(m.group(1), int.parse(m.group(2)!), int.tryParse(m.group(3) ?? '') ?? 0);
  }

  final ampm = RegExp(r'(오전|오후)\s*(\d{1,2})\s*[:시]\s*(\d{0,2})');
  m = ampm.firstMatch(text);
  if (m != null) {
    return _clock(m.group(1), int.parse(m.group(2)!), int.tryParse(m.group(3) ?? '') ?? 0);
  }

  final hm = RegExp(r'(?<!\d)([01]?\d|2[0-3]):([0-5]\d)(?!\d)');
  for (final match in hm.allMatches(text)) {
    final hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    if (hour >= 5 && hour <= 16) {
      return (hour, minute);
    }
  }
  return null;
}

(int, int)? _clock(String? ampm, int hour, int minute) {
  var h = hour;
  if (ampm == '오후' && h < 12) h += 12;
  if (ampm == '오전' && h == 12) h = 0;
  if (h < 0 || h > 23 || minute < 0 || minute > 59) return null;
  return (h, minute);
}

GolfCourse? _matchCourse(String text, List<GolfCourse> extras) {
  final compact = text.replaceAll(RegExp(r'\s+'), '').toLowerCase();
  GolfCourse? best;
  var bestLen = 0;

  void consider(GolfCourse course) {
    final name = course.name.replaceAll(' ', '').toLowerCase();
    if (name.length < 3) return;
    if (!compact.contains(name)) return;
    if (name.length > bestLen) {
      best = course;
      bestLen = name.length;
    }
  }

  for (final c in extras) {
    consider(c);
  }
  for (final c in kKoreanGolfCourses) {
    consider(c);
  }
  return best;
}

String? _labeledCourse(String text) {
  final re = RegExp(
    r'(?:골프장|클럽명|예약\s*클럽|장소)\s*[:：]\s*([^\n]+)',
  );
  final m = re.firstMatch(text);
  if (m == null) return null;
  var name = m.group(1)!.trim();
  name = name.replaceAll(RegExp(r'\s{2,}'), ' ');
  if (name.length < 2 || name.length > 40) return null;
  if (RegExp(r'^(동|서|남|북|레이크|마운틴|힐|밸리)?코스$').hasMatch(name)) {
    return null;
  }
  return name;
}

int? _parsePeople(String text) {
  final re = RegExp(r'(?:인원|예약인원|내장객)\s*[:：]?\s*(\d{1,2})\s*명?');
  final m = re.firstMatch(text);
  if (m == null) return null;
  final n = int.parse(m.group(1)!);
  if (n < 1 || n > 120) return null;
  return n;
}
