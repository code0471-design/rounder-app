import 'package:flutter_test/flutter_test.dart';
import 'package:golf_rounder/utils/reservation_sms_parser.dart';

void main() {
  final now = DateTime(2026, 8, 31);

  test('한글 일시와 카탈로그 골프장을 읽는다', () {
    const sms = '''
[골프존카운티] 예약확정 안내
골프장: 레이크사이드CC
일시: 2026년 9월 12일 (토) 07:28
인원: 4명
''';
    final p = parseReservationSms(sms, now: now);
    expect(p.date, DateTime(2026, 9, 12));
    expect(p.hour, 7);
    expect(p.minute, 28);
    expect(p.courseName, '레이크사이드CC');
    expect(p.address, contains('용인'));
    expect(p.teamCount, 1);
    expect(p.titleHint, contains('9월'));
  });

  test('점 구분 날짜와 오후 시간을 읽는다', () {
    const sms = '남서울CC 26.10.03 오후 1:10 예약완료';
    final p = parseReservationSms(sms, now: now);
    expect(p.date, DateTime(2026, 10, 3));
    expect(p.hour, 13);
    expect(p.minute, 10);
    expect(p.courseName, '남서울CC');
  });

  test('연도 없는 월일은 지난 날이면 내년으로 본다', () {
    const sms = '3월 2일 06:50 스카이72 오션';
    final p = parseReservationSms(sms, now: now);
    expect(p.date, DateTime(2027, 3, 2));
    expect(p.hour, 6);
    expect(p.minute, 50);
    expect(p.courseName, '스카이72 오션');
  });

  test('빈 글자는 값을 만들지 않는다', () {
    final p = parseReservationSms('   ', now: now);
    expect(p.hasAny, isFalse);
  });
}
