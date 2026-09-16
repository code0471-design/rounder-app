import 'package:flutter/foundation.dart';

import 'hq_alimtalk_catalog.dart';
import 'push_notification_service.dart';
import 'solapi_service.dart';

/// D-1 알림톡. 푸시는 Functions 10시고, 알림톡도 서버가 보내는 게 기본이다.
/// 앱 경로는 서버 키가 없을 때·이미 온 푸시를 받은 기기의 보조 발송이다.
abstract final class D1AlimtalkFlush {
  static Future<void> run({
    bool Function(String clubId, String typeId)? clubEnabled,
    String? Function(String userId, String clubId)? resolvePhone,
  }) async {
    final solapi = SolapiService.instance;
    if (!solapi.isConfigured || !solapi.hasKakaoChannel) return;
    if (DateTime.now().hour < 10) return;
    final docs = await PushNotificationService.dueD1AlimtalkDocs();
    if (docs.isEmpty) return;

    for (final doc in docs) {
      final d = doc.data();
      final isDues = d['kind'] == 'dues';
      final hqTypeId = isDues
          ? HqAlimtalkCatalog.duesRequestId
          : HqAlimtalkCatalog.d1ReminderId;
      final clubId = '${d['clubId'] ?? ''}';
      if (clubId.isNotEmpty &&
          clubEnabled != null &&
          !clubEnabled(clubId, hqTypeId)) {
        await PushNotificationService.markD1AlimtalkSent(doc.id);
        continue;
      }
      if (!await HqAlimtalkCatalog.isGloballyEnabled(hqTypeId)) {
        await PushNotificationService.markD1AlimtalkSent(doc.id);
        continue;
      }

      var phone = SolapiService.normalizePhone('${d['phone'] ?? ''}');
      if (phone.length < 10) {
        phone = SolapiService.normalizePhone(
          resolvePhone?.call('${d['userId'] ?? ''}', clubId) ?? '',
        );
      }
      if (phone.length < 10) {
        debugPrint('[Alimtalk] d1 skip no phone ${doc.id}');
        continue;
      }

      final templateId =
          SolapiService.templateIdForHqType(hqTypeId)?.trim() ?? '';
      if (templateId.isEmpty) continue;

      final name = '${d['memberName'] ?? '회원'}';
      final result = await solapi.sendManyRaw([
        solapi.buildAlimtalkMessage(
          to: phone,
          templateId: templateId,
          variables: isDues
              ? {
                  '#{이름}': name,
                  '#{모임명}': '${d['clubName'] ?? ''}',
                  '#{금액}': '${d['amount'] ?? ''}',
                  '#{기한}': '${d['dueText'] ?? '-'}',
                }
              : {
                  '#{이름}': name,
                  '#{모임명}': '${d['clubName'] ?? ''}',
                  '#{일정명}': '${d['scheduleTitle'] ?? ''}',
                  '#{일시}': '${d['whenText'] ?? ''}',
                  '#{장소}': '${d['place'] ?? '장소 미정'}',
                },
        ),
      ]);
      if (result.success ||
          (result.errorMessage ?? '').contains('꺼져 있습니다') ||
          (result.errorMessage ?? '').contains('사용중지')) {
        await PushNotificationService.markD1AlimtalkSent(doc.id);
      }
    }
  }
}
