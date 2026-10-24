import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:golf_rounder/services/club_ops_sync.dart';

void main() {
  test('어드민 모임 이름이 폰에 남은 옛 이름보다 우선한다', () {
    expect(
      ClubOpsSync.newerCatalogName(
        localName: '알라딘 정기월례회',
        catalogName: '7080 골프모임',
      ),
      '7080 골프모임',
    );
    expect(
      ClubOpsSync.newerCatalogName(
        localName: '7080 골프모임',
        catalogName: '7080 골프모임',
      ),
      isNull,
    );
    expect(
      ClubOpsSync.newerCatalogName(
        localName: '알라딘',
        catalogName: '  ',
      ),
      isNull,
    );
  });

  test('회비 알림톡은 앱이 솔라피로 보내지 않는다', () {
    final src = File('lib/services/d1_alimtalk_flush.dart').readAsStringSync();
    final skip = src.indexOf("d['kind'] == 'dues'");
    final send = src.indexOf('sendManyRaw');
    expect(skip, greaterThan(0));
    expect(send, greaterThan(skip));
    expect(src.contains('if (isDues)'), isTrue);
  });
}
