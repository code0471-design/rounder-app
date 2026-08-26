import 'package:flutter_test/flutter_test.dart';
import 'package:golf_rounder/screens/admin/admin_models.dart';
import 'package:golf_rounder/services/hq_alimtalk_catalog.dart';

void main() {
  test('모임 초대는 알림톡·푸시·정책 카탈로그에 없다', () {
    expect(
      AdminCatalog.hqPushTypes.any((t) => t.id == 'push_club_invite'),
      isFalse,
    );
    expect(
      AdminCatalog.hqAlimtalkTypes
          .any((t) => t.id == HqAlimtalkCatalog.clubInviteId),
      isFalse,
    );
    expect(
      AdminCatalog.templates.any((t) => t.id == 'T007' || t.name == '모임 초대'),
      isFalse,
    );
    expect(
      AdminCatalog.notificationPolicies.any((r) => r.event == '모임 초대'),
      isFalse,
    );
  });
}
