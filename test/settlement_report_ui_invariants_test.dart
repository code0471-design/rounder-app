import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 결산보고 기간 이동은 화살표다. 연도 화살표가 눌리지 않던 회귀를 막는다.
void main() {
  late String src;

  setUpAll(() {
    src = File('lib/screens/finance/finance_screen.dart').readAsStringSync();
  });

  test('월 결산은 드롭다운이 아니라 화살표로 이동한다', () {
    final start = src.indexOf('class _MonthlyReport extends StatelessWidget');
    expect(start, greaterThan(0));
    final body = src.substring(start, start + 2000);
    expect(body.contains('_MonthSelector('), isTrue,
        reason: '수입/지출 탭과 같은 화살표 이동이어야 한다');
    expect(body.contains('_ReportPeriodSelector('), isFalse,
        reason: '드롭다운으로 되돌아감');
  });

  test('연도 화살표가 거래 있는 연도로 되돌려지지 않는다', () {
    expect(src.contains('if (!years.contains(_year)) _year = years.first;'),
        isFalse,
        reason: '이 줄이 있으면 화살표를 눌러도 곧바로 원래 연도로 돌아간다');
    expect(src.contains('void _setYear(int y)'), isTrue);
  });

  test('연 결산은 화살표 연도 선택기를 쓴다', () {
    final start = src.indexOf('class _YearlyReport extends StatelessWidget');
    expect(start, greaterThan(0));
    final body = src.substring(start, start + 1200);
    expect(body.contains('_YearSelector('), isTrue);
  });
}
