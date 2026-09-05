import 'package:flutter/material.dart';
import '../models/club_model.dart';
import '../navigation/app_navigator.dart';
import '../providers/club_provider.dart';
import '../screens/alimtalk/alimtalk_send_screen.dart';
import '../screens/alimtalk/alimtalk_settings_screen.dart';
import '../services/hq_alimtalk_catalog.dart';
import '../theme/app_theme.dart';

/// 카카오 알림톡 발송 플로우 (mock)
class AlimtalkUtils {
  /// 본사(전 모임) 사용중 AND 해당 모임 로컬 사용중일 때만 true
  static Future<bool> shouldPrompt({
    required ClubProvider provider,
    required String hqTypeId,
    required bool Function(ClubAlimtalkSettings s) clubFlag,
  }) async {
    final clubId = provider.selectedClub.id;
    if (!provider.isClubAlimtalkTypeEnabled(clubId, hqTypeId)) return false;
    final settings = provider.alimtalkSettingsOf(clubId);
    if (!clubFlag(settings)) return false;
    return HqAlimtalkCatalog.isGloballyEnabled(hqTypeId);
  }

  static Future<bool?> promptScheduleUpload() {
    final ctx = AppNavigator.context;
    if (ctx == null) return Future.value(false);

    return showDialog<bool>(
      context: ctx,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('알림톡 발송',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
        content: const Text(
          '새로운 라운딩 일정이 업로드 되었습니다.\n회원들에게 참석여부 알림톡을 발송할까요?',
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('나중에'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('발송하기'),
          ),
        ],
      ),
    );
  }

  static Future<bool?> promptScheduleChange() {
    final ctx = AppNavigator.context;
    if (ctx == null) return Future.value(false);

    return showDialog<bool>(
      context: ctx,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('알림톡 발송',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
        content: const Text(
          '라운딩 일정이 변경되었습니다.\n기존 신청자에게 재참석 신청 안내 알림톡을 발송할까요?',
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('나중에'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('발송하기'),
          ),
        ],
      ),
    );
  }

  static Future<bool?> promptGroupFinalize() {
    final ctx = AppNavigator.context;
    if (ctx == null) return Future.value(false);

    return showDialog<bool>(
      context: ctx,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('알림톡 발송',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
        content: const Text(
          '이번 라운딩 조편성이 확정되었습니다.\n참석 회원들에게 알림톡을 발송할까요?',
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('나중에'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('발송하기'),
          ),
        ],
      ),
    );
  }

  static Future<bool?> _pushSendScreen({
    required AlimtalkSendKind kind,
    required RoundSchedule schedule,
    required String clubName,
    required List<String> recipientNames,
  }) async {
    final nav = AppNavigator.state;
    if (nav == null) return false;

    // 얼럿 닫힌 직후 프레임 대기
    await Future<void>.delayed(const Duration(milliseconds: 100));

    if (!nav.mounted) return false;

    return nav.push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => AlimtalkSendScreen(
          kind: kind,
          schedule: schedule,
          clubName: clubName,
          recipientNames: recipientNames,
        ),
      ),
    );
  }

  /// 일정 등록 — 알림톡은 ClubProvider.addSchedule 이 바로 보낸다.
  /// 발송 화면을 또 열면 같은 템플릿이 두 번 나간다.
  static Future<bool?> runAttendanceFlow({
    required ClubProvider provider,
    required RoundSchedule schedule,
  }) async {
    return false;
  }

  /// 일정 변경 — ClubProvider.updateSchedule 이 바로 보낸다.
  static Future<bool?> runScheduleChangeFlow({
    required ClubProvider provider,
    required RoundSchedule schedule,
    List<String>? recipientNames,
  }) async {
    return false;
  }

  /// 조편성 확정 — ClubProvider.finalizeAssignment 이 바로 보낸다.
  static Future<bool?> runGroupFlow({
    required ClubProvider provider,
    required RoundSchedule schedule,
  }) async {
    return false;
  }
}

/// 하위 호환: 바텀시트 대신 전체 화면 [AlimtalkSettingsScreen]으로 이동
class AlimtalkSettingsSheet {
  AlimtalkSettingsSheet._();

  static void show(BuildContext context, ClubProvider provider) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AlimtalkSettingsScreen()),
    );
  }
}
