import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/golf_courses_kr.dart';
import '../theme/app_theme.dart';
import '../utils/reservation_sms_parser.dart';

/// 일정 등록 상단 — 예약 문자를 붙여 날짜·시간·골프장을 채운다.
class ReservationSmsFillBanner extends StatelessWidget {
  final List<GolfCourse> extras;
  final void Function(ReservationSmsParse parsed) onFilled;

  const ReservationSmsFillBanner({
    super.key,
    required this.extras,
    required this.onFilled,
  });

  Future<void> _open(BuildContext context) async {
    final clip = await Clipboard.getData(Clipboard.kTextPlain);
    final initial = clip?.text?.trim() ?? '';
    if (!context.mounted) return;

    final result = await showModalBottomSheet<ReservationSmsParse>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _ReservationSmsSheet(
        initialText: initial,
        extras: extras,
      ),
    );
    if (result == null || !result.hasAny) return;
    onFilled(result);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: OutlinedButton.icon(
        onPressed: () => _open(context),
        icon: const Icon(Icons.content_paste_go_outlined, size: 18),
        label: const Text('예약 문자 붙여넣기'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          minimumSize: const Size(double.infinity, 44),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }
}

class _ReservationSmsSheet extends StatefulWidget {
  final String initialText;
  final List<GolfCourse> extras;

  const _ReservationSmsSheet({
    required this.initialText,
    required this.extras,
  });

  @override
  State<_ReservationSmsSheet> createState() => _ReservationSmsSheetState();
}

class _ReservationSmsSheetState extends State<_ReservationSmsSheet> {
  late final TextEditingController _ctrl;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _apply() {
    final parsed = parseReservationSms(
      _ctrl.text,
      extras: widget.extras,
    );
    if (!parsed.hasAny) {
      setState(() {
        _error = '날짜·시간·골프장 중 읽을 수 있는 값이 없습니다. 문자를 다시 붙여 주세요.';
      });
      return;
    }
    Navigator.pop(context, parsed);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '예약 문자 붙여넣기',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            '골프장 예약 문자를 넣으면 날짜, 티오프, 골프장을 채웁니다.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _ctrl,
            maxLines: 8,
            autofocus: true,
            decoration: InputDecoration(
              hintText: '예: 레이크사이드CC 2026년 9월 12일 07:28',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(color: AppColors.danger, fontSize: 12),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _apply,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('일정에 채우기'),
            ),
          ),
        ],
      ),
    );
  }
}
