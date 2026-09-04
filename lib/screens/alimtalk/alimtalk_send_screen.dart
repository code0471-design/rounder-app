import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/club_model.dart';
import '../../providers/club_provider.dart';
import '../../services/hq_alimtalk_catalog.dart';
import '../../theme/app_theme.dart';

enum AlimtalkSendKind { attendance, groupAssignment, scheduleChanged }

/// 알림톡 발송 확인 화면 — 수신자 명수 확인 후 발송
class AlimtalkSendScreen extends StatefulWidget {
  final AlimtalkSendKind kind;
  final RoundSchedule schedule;
  final String clubName;
  final List<String> recipientNames;

  const AlimtalkSendScreen({
    super.key,
    required this.kind,
    required this.schedule,
    required this.clubName,
    required this.recipientNames,
  });

  @override
  State<AlimtalkSendScreen> createState() => _AlimtalkSendScreenState();
}

class _AlimtalkSendScreenState extends State<AlimtalkSendScreen> {
  bool _sending = false;

  String get _title => switch (widget.kind) {
        AlimtalkSendKind.attendance => '참석여부 알림톡',
        AlimtalkSendKind.groupAssignment => '조편성 알림톡',
        AlimtalkSendKind.scheduleChanged => '일정 변경 안내 알림톡',
      };

  String get _audienceNote => switch (widget.kind) {
        AlimtalkSendKind.attendance => '정회원 전원 (등록자 본인 포함, 게스트 제외)',
        AlimtalkSendKind.groupAssignment => '참석 회원 (정회원·게스트)',
        AlimtalkSendKind.scheduleChanged => '전체 정회원 + 참석 게스트',
      };

  String get _message {
    final s = widget.schedule;
    final date =
        '${s.roundDate.month}월 ${s.roundDate.day}일 ${s.teeTime}';
    return switch (widget.kind) {
      AlimtalkSendKind.attendance =>
        '[ROUNDER] ${widget.clubName}\n새 라운딩 일정이 등록되었습니다.\n\n'
            '${s.displayTitle}\n${s.courseName} · $date\n\n'
            '참석 여부를 알려주세요.',
      AlimtalkSendKind.groupAssignment =>
        '[ROUNDER] ${widget.clubName}\n조편성이 확정되었습니다.\n\n'
            '${s.displayTitle}\n${s.courseName} · $date\n\n'
            '앱에서 조편성을 확인해 주세요.',
      AlimtalkSendKind.scheduleChanged =>
        '[ROUNDER] ${widget.clubName}\n일정이 변경되었습니다.\n\n'
            '${s.displayTitle}\n${s.courseName} · $date\n\n'
            '변경된 일정을 확인하시고 참석 여부를 다시 신청해 주세요.',
    };
  }

  String get _hqTypeId => switch (widget.kind) {
        AlimtalkSendKind.attendance => HqAlimtalkCatalog.scheduleUploadId,
        AlimtalkSendKind.groupAssignment => HqAlimtalkCatalog.groupFinalizeId,
        AlimtalkSendKind.scheduleChanged => HqAlimtalkCatalog.scheduleChangeId,
      };

  Future<void> _send() async {
    if (_sending || widget.recipientNames.isEmpty) return;
    setState(() => _sending = true);
    final provider = context.read<ClubProvider>();
    final s = widget.schedule;
    final dateStr = '${s.roundDate.month}월 ${s.roundDate.day}일 ${s.teeTime}'.trim();
    final place =
        s.courseName.trim().isEmpty ? '장소 미정' : s.courseName.trim();
    final members = switch (widget.kind) {
      AlimtalkSendKind.attendance => provider.attendanceAlimtalkRecipients(),
      AlimtalkSendKind.groupAssignment =>
        provider.groupAlimtalkRecipientMembers(s.id),
      AlimtalkSendKind.scheduleChanged =>
        provider.scheduleChangeAlimtalkRecipients(s.id),
    };
    final result = await provider.sendClubAlimtalk(
      hqTypeId: _hqTypeId,
      members: members,
      variablesFor: (m) => {
        '#{이름}': m.name.trim().isEmpty ? '회원' : m.name.trim(),
        '#{모임명}': widget.clubName,
        '#{일정명}': s.displayTitle,
        '#{일시}': dateStr,
        '#{장소}': place,
      },
    );
    if (!mounted) return;
    setState(() => _sending = false);
    final ok = result.success;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? '${result.requestedCount}명에게 $_title을 발송했습니다.'
              : (result.errorMessage ?? '알림톡 발송에 실패했습니다.'),
        ),
        backgroundColor: ok ? AppColors.primary : AppColors.danger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
    if (ok) {
      Navigator.of(context, rootNavigator: true).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.recipientNames.length;
    final namesPreview = widget.recipientNames.take(6).join(', ');
    final extra = count > 6 ? ' 외 ${count - 6}명' : '';

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.ink),
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
        ),
        title: Text(_title,
            style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.ink)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.divider, height: 1),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // 카카오 미리보기
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE500),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: Text('K',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF3A1C00))),
                ),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('카카오 알림톡 미리보기',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary)),
                  Text('아래 메시지가 발송됩니다',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFEE500).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: const Color(0xFFFEE500).withValues(alpha: 0.5)),
            ),
            child: Text(_message,
                style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                    height: 1.6)),
          ),
          const SizedBox(height: 20),
          // 발송 대상
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.people_outline,
                        size: 18, color: AppColors.sageDeep),
                    const SizedBox(width: 8),
                    Text('발송 대상 $count명',
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(_audienceNote,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
                if (count > 0) ...[
                  const SizedBox(height: 10),
                  Text('$namesPreview$extra',
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textPrimary)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: count == 0 || _sending ? null : _send,
              icon: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded, size: 18),
              label: Text(
                count == 0 ? '발송 대상 없음' : '$count명에게 발송하기',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.divider,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
