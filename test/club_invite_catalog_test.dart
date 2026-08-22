import 'package:flutter_test/flutter_test.dart';
import 'package:golf_rounder/screens/admin/admin_models.dart';
import 'package:golf_rounder/services/hq_alimtalk_catalog.dart';
import 'package:golf_rounder/services/hq_push_catalog.dart';

void main() {
  test('모임 초대는 푸시·알림톡 카탈로그에 모두 있다', () {
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
    expect(
      AdminCatalog.notificationPolicies
          .any((p) => p.event == '모임 초대' && p.channel.contains('푸시')),
      isTrue,
    );
  });
}
