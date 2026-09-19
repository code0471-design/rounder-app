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

  test('기존잔액은 등록 후 버튼 한 줄만 남고 총무만 본다', () {
    expect(src.indexOf('class _OpeningBalanceSettingCard'), greaterThan(0));
    expect(src.contains("'기존잔액 등록완료'"), isTrue);
    expect(src.contains('if (isRegistered) return _doneButton(context, tx);'),
        isTrue,
        reason: '등록 후에도 큰 카드가 계속 뜨면 안 된다');
    expect(src.contains('_openSheet(context, isEdit: true)'), isTrue,
        reason: '버튼을 누르면 수정 모달이 떠야 한다');
    // 노출은 총무(isAdmin)일 때만
    expect(
      RegExp(r'if \(isAdmin\) \.\.\.\[\s*_OpeningBalanceSettingCard')
          .hasMatch(src),
      isTrue,
      reason: '총무가 아닌 회원에게 노출되면 안 된다',
    );
  });

  test('연 결산은 화살표 연도 선택기를 쓴다', () {
    final start = src.indexOf('class _YearlyReport extends StatelessWidget');
    expect(start, greaterThan(0));
    final body = src.substring(start, start + 1200);
    expect(body.contains('_YearSelector('), isTrue);
  });
}
