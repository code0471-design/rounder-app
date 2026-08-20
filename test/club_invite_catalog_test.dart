import 'package:flutter_test/flutter_test.dart';
import 'package:golf_rounder/screens/admin/admin_models.dart';
import 'package:golf_rounder/services/hq_alimtalk_catalog.dart';
import 'package:golf_rounder/services/hq_push_catalog.dart';

void main() {
  test('어드민 푸시·알림톡 카탈로그에 모임 초대가 있어야 한다', () {
    expect(
      AdminCatalog.hqPushTypes.any((t) => t.id == HqPushCatalog.clubInvite),
      isTrue,
    );
    expect(
      AdminCatalog.hqAlimtalkTypes
          .any((t) => t.id == HqAlimtalkCatalog.clubInviteId),
      isTrue,
    );
    expect(
      AdminCatalog.templates.any((t) => t.id == 'T007' && t.name == '모임 초대'),
      isTrue,
    );
  });
}
