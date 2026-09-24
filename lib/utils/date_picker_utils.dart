import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import '../theme/app_theme.dart';

const _koLocale = Locale('ko', 'KR');

const _localizationDelegates = [
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

/// 티오프 분 0–59. 8:36처럼 10분 단위가 아닌 시간도 그대로 넣는다.
int clampTeeMinute(int minute) => minute.clamp(0, 59);

/// 예약 문자 등에서 온 분을 그대로 둔다. 10분으로 올리지 않는다.
int snapTeeMinute(int minute) => clampTeeMinute(minute);

ThemeData _pickerThemeData(BuildContext context) {
  return Theme.of(context).copyWith(
    colorScheme: const ColorScheme.light(
      primary: AppColors.charcoal,
      onPrimary: Colors.white,
      onSurface: AppColors.textPrimary,
    ),
  );
}

/// 세로로 달을 넘기는 달력. 가로로 밀어서 넘기는 달력은 쓰지 않는다.
Future<DateTime?> showRounderDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  String? helpText,
  bool useRootNavigator = false,
}) {
  var selected = DateTime(initialDate.year, initialDate.month, initialDate.day);

  return showDialog<DateTime>(
    context: context,
    useRootNavigator: useRootNavigator,
    builder: (dialogContext) {
      return Localizations(
        locale: _koLocale,
        delegates: _localizationDelegates,
        child: Material(
          type: MaterialType.transparency,
          child: Theme(
            data: _pickerThemeData(dialogContext),
            child: StatefulBuilder(
              builder: (context, setState) {
                return AlertDialog(
                  title: Text(helpText ?? '날짜 선택'),
                  content: SizedBox(
                    width: 320,
                    height: 420,
                    child: _VerticalMonthCalendar(
                      initialDate: selected,
                      firstDate: firstDate,
                      lastDate: lastDate,
                      selected: selected,
                      onDateChanged: (date) => setState(() => selected = date),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('취소'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(selected),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.charcoal,
                      ),
                      child: const Text('확인'),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );
    },
  );
}

class _VerticalMonthCalendar extends StatefulWidget {
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final DateTime selected;
  final ValueChanged<DateTime> onDateChanged;

  const _VerticalMonthCalendar({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.selected,
    required this.onDateChanged,
  });

  @override
  State<_VerticalMonthCalendar> createState() => _VerticalMonthCalendarState();
}

class _VerticalMonthCalendarState extends State<_VerticalMonthCalendar> {
  final _scroll = ScrollController();
  late final List<DateTime> _months;

  @override
  void initState() {
    super.initState();
    _months = _monthList(widget.firstDate, widget.lastDate);
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToInitial());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _jumpToInitial() {
    if (!_scroll.hasClients) return;
    final target = DateTime(widget.initialDate.year, widget.initialDate.month);
    final index = _months.indexWhere(
      (m) => m.year == target.year && m.month == target.month,
    );
    if (index <= 0) return;
    final offset = (index * 318.0).clamp(0, _scroll.position.maxScrollExtent);
    _scroll.jumpTo(offset.toDouble());
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: _scroll,
      itemCount: _months.length,
      itemBuilder: (context, index) => _MonthBlock(
        month: _months[index],
        firstDate: widget.firstDate,
        lastDate: widget.lastDate,
        selected: widget.selected,
        onDateChanged: widget.onDateChanged,
      ),
    );
  }
}

List<DateTime> _monthList(DateTime first, DateTime last) {
  final out = <DateTime>[];
  var cursor = DateTime(first.year, first.month);
  final end = DateTime(last.year, last.month);
  while (!cursor.isAfter(end)) {
    out.add(cursor);
    cursor = DateTime(cursor.year, cursor.month + 1);
  }
  return out;
}

class _MonthBlock extends StatelessWidget {
  final DateTime month;
  final DateTime firstDate;
  final DateTime lastDate;
  final DateTime selected;
  final ValueChanged<DateTime> onDateChanged;

  const _MonthBlock({
    required this.month,
    required this.firstDate,
    required this.lastDate,
    required this.selected,
    required this.onDateChanged,
  });

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final lead = DateTime(month.year, month.month, 1).weekday % 7;
    final today = DateTime.now();
    final todayDay = DateTime(today.year, today.month, today.day);

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${month.year}년 ${month.month}월',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final w in const ['일', '월', '화', '수', '목', '금', '토'])
                Expanded(
                  child: Text(
                    w,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: w == '일'
                          ? AppColors.danger
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: lead + daysInMonth,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisExtent: 36,
            ),
            itemBuilder: (context, index) {
              if (index < lead) return const SizedBox.shrink();
              final day = index - lead + 1;
              final date = DateTime(month.year, month.month, day);
              final enabled = !date.isBefore(DateTime(
                    firstDate.year,
                    firstDate.month,
                    firstDate.day,
                  )) &&
                  !date.isAfter(DateTime(
                    lastDate.year,
                    lastDate.month,
                    lastDate.day,
                  ));
              final isSelected = date.year == selected.year &&
                  date.month == selected.month &&
                  date.day == selected.day;
              final isToday = date == todayDay;
              return InkWell(
                onTap: enabled ? () => onDateChanged(date) : null,
                customBorder: const CircleBorder(),
                child: Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? AppColors.charcoal : Colors.transparent,
                    border: isToday && !isSelected
                        ? Border.all(color: AppColors.charcoal)
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$day',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          isSelected || isToday ? FontWeight.w800 : FontWeight.w500,
                      color: !enabled
                          ? AppColors.textSecondary.withValues(alpha: 0.35)
                          : isSelected
                              ? Colors.white
                              : AppColors.textPrimary,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// 시 0–23, 분 00–59. 시계 다이얼 금지.
Future<TimeOfDay?> showRounderTimePicker({
  required BuildContext context,
  required TimeOfDay initialTime,
  bool useRootNavigator = false,
}) {
  var hour = initialTime.hour.clamp(0, 23);
  var minute = clampTeeMinute(initialTime.minute);

  return showDialog<TimeOfDay>(
    context: context,
    useRootNavigator: useRootNavigator,
    builder: (dialogContext) {
      return Theme(
        data: _pickerThemeData(dialogContext),
        child: StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('티오프 시간'),
              content: SizedBox(
                width: 320,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        '시',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (var h = 0; h <= 23; h++)
                            _TimeChip(
                              label: h.toString().padLeft(2, '0'),
                              selected: hour == h,
                              onTap: () => setState(() => hour = h),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '분',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (var m = 0; m <= 59; m++)
                            _TimeChip(
                              label: m.toString().padLeft(2, '0'),
                              selected: minute == m,
                              onTap: () => setState(() => minute = m),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('취소'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(
                    TimeOfDay(hour: hour, minute: minute),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.charcoal,
                  ),
                  child: const Text('확인'),
                ),
              ],
            );
          },
        ),
      );
    },
  );
}

class _TimeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TimeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.charcoal : const Color(0xFFF4F2EC),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 44,
          height: 36,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: selected ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
