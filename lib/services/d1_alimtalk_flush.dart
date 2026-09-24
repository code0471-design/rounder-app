import 'package:flutter/foundation.dart';

import '../utils/d1_enqueue_policy.dart';
import '../utils/d1_send_window.dart';
import 'hq_alimtalk_catalog.dart';
import 'push_notification_service.dart';
import 'solapi_service.dart';

/// D-1 알림톡.
/// 참석 확정·앱 오픈 때 솔라피에 10시 예약을 넣는다.
/// Functions는 10시에는 푸시만 보내고, 예약이 안 된 건 10시 10분 이후 보조 발송.
abstract final class D1AlimtalkFlush {
  static bool _running = false;

  static Future<void> run({
    bool Function(String clubId, String typeId)? clubEnabled,
    String? Function(String userId, String clubId)? resolvePhone,
  }) async {
    if (_running) return;
    _running = true;
    try {
      await _runBody(
        clubEnabled: clubEnabled,
        resolvePhone: resolvePhone,
      );
    } finally {
      _running = false;
    }
  }

  static Future<void> _runBody({
    bool Function(String clubId, String typeId)? clubEnabled,
    String? Function(String userId, String clubId)? resolvePhone,
  }) async {
    final solapi = SolapiService.instance;
    if (!solapi.isConfigured || !solapi.hasKakaoChannel) return;
    final plan = await PushNotificationService.d1AlimtalkFlushPlan();
    final docs = plan.openDocs;
    if (docs.isEmpty) return;
    final utc = DateTime.now().toUtc();
    final now = utc.add(const Duration(hours: 9));
    final claimed = {...plan.claimedKeys};

    for (final doc in docs) {
      final d = doc.data();
      final isDues = d['kind'] == 'dues';
      final hqTypeId = isDues
          ? HqAlimtalkCatalog.duesRequestId
          : HqAlimtalkCatalog.d1ReminderId;
      final clubId = '${d['clubId'] ?? ''}';
      if (D1EnqueuePolicy.isBlockedRecipient(
        name: '${d['memberName'] ?? ''}',
        userId: '${d['userId'] ?? ''}',
        clubId: clubId,
      )) {
        await PushNotificationService.markD1AlimtalkSent(doc.id);
        continue;
      }
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
      final dedupKey = D1EnqueuePolicy.sendDedupKey(
        scheduleId: '${d['scheduleId'] ?? ''}',
        sendOn: '${d['sendOn'] ?? ''}',
        phone: phone,
        kind: isDues ? 'dues' : '',
        clubId: clubId,
      );
      if (!claimed.add(dedupKey)) {
        await PushNotificationService.markD1AlimtalkSent(
          doc.id,
          scheduled: true,
        );
        continue;
      }

      final templateId =
          SolapiService.templateIdForHqType(hqTypeId)?.trim() ?? '';
      if (templateId.isEmpty) continue;

      final sendOn = _parseYmd('${d['sendOn'] ?? ''}');
      if (sendOn == null) continue;
      final today = DateTime(now.year, now.month, now.day);
      if (sendOn.isAfter(today.add(const Duration(days: 1)))) {
        continue;
      }
      if (D1SendWindow.shouldSkipAsMissed(now, sendOn)) {
        await PushNotificationService.markD1AlimtalkSent(doc.id);
        continue;
      }
      final dueAt10 = DateTime(sendOn.year, sendOn.month, sendOn.day, 10);
      final sendNow = D1SendWindow.shouldSendNow(now, sendOn);
      final reserve = D1SendWindow.shouldReserve(now, sendOn);
      if (!sendNow && !reserve) continue;
      if (!await PushNotificationService.claimD1Alimtalk(doc.id)) {
        continue;
      }

      final name = '${d['memberName'] ?? '회원'}';
      final result = await solapi.sendManyRaw(
        [
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
        ],
        scheduledAtKst: sendNow ? null : dueAt10,
      );
      if (result.success ||
          (result.errorMessage ?? '').contains('꺼져 있습니다') ||
          (result.errorMessage ?? '').contains('사용중지')) {
        await PushNotificationService.markD1AlimtalkSent(
          doc.id,
          scheduled: !sendNow,
        );
      } else {
        await PushNotificationService.releaseD1AlimtalkClaim(doc.id);
      }
    }
  }

  static DateTime? _parseYmd(String raw) {
    final p = raw.split('-');
    if (p.length != 3) return null;
    final y = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    final d = int.tryParse(p[2]);
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m, d);
  }
}
