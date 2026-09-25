import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import '../theme/app_theme.dart';

const _koLocale = Locale('ko', 'KR');

const _localizationDelegates = [
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

/// 6주 칸을 항상 그려 달마다 높이가 같아지게 한다. 어림 점프로 다른 달이 열리지 않게.
const kRounderMonthBlockExtent = 284.0;

/// 티오프 분 0–59. 8:36처럼 10분 단위가 아닌 시간도 그대로 넣는다.
int clampTeeMinute(int minute) => minute.clamp(0, 59);

/// 예약 문자 등에서 온 분을 그대로 둔다. 10분으로 올리지 않는다.
int snapTeeMinute(int minute) => clampTeeMinute(minute);

int hour12From24(int hour) {
  final h = hour % 12;
  return h == 0 ? 12 : h;
}

int hour24From12({required int hour12, required bool isPm}) {
  if (hour12 == 12) return isPm ? 12 : 0;
  return isPm ? hour12 + 12 : hour12;
}

bool isAfternoonHour(int hour) => hour >= 12;

String formatTeeTimeKo(int hour, int minute) {
  final period = isAfternoonHour(hour) ? '오후' : '오전';
  return '$period ${hour12From24(hour)}:${minute.toString().padLeft(2, '0')}';
}

/// 저장된 `07:30`을 홈 카드용 `오전 7:30`으로 바꾼다. 없으면 빈 문자열.
String formatStoredTeeTimeKo(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return '';
  final parts = t.split(':');
  if (parts.length < 2) return t;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return t;
  return formatTeeTimeKo(hour.clamp(0, 23), clampTeeMinute(minute));
}

double rounderMonthScrollOffset({
  required DateTime firstDate,
  required DateTime lastDate,
  required DateTime initialDate,
}) {
  final months = monthListForPicker(firstDate, lastDate);
  final target = DateTime(initialDate.year, initialDate.month);
  final index = months.indexWhere(
    (m) => m.year == target.year && m.month == target.month,
  );
  if (index <= 0) return 0;
  return index * kRounderMonthBlockExtent;
}

List<DateTime> monthListForPicker(DateTime first, DateTime last) {
  final out = <DateTime>[];
  var cursor = DateTime(first.year, first.month);
  final end = DateTime(last.year, last.month);
  while (!cursor.isAfter(end)) {
    out.add(cursor);
    cursor = DateTime(cursor.year, cursor.month + 1);
  }
  return out;
}

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
                  backgroundColor: AppColors.background,
                  surfaceTintColor: Colors.transparent,
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
  var _jumpTries = 0;

  @override
  void initState() {
    super.initState();
    _months = monthListForPicker(widget.firstDate, widget.lastDate);
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToInitial());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _jumpToInitial() {
    if (!mounted) return;
    if (!_scroll.hasClients) {
      if (_jumpTries++ < 8) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToInitial());
      }
      return;
    }
    final offset = rounderMonthScrollOffset(
      firstDate: widget.firstDate,
      lastDate: widget.lastDate,
      initialDate: widget.initialDate,
    );
    final target = offset.clamp(0.0, _scroll.position.maxScrollExtent);
    if (_scroll.offset != target) {
      _scroll.jumpTo(target);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: _scroll,
      itemExtent: kRounderMonthBlockExtent,
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

    return SizedBox(
      height: kRounderMonthBlockExtent,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 22,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${month.year}년 ${month.month}월',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 16,
              child: Row(
                children: [
                  for (final w in const ['일', '월', '화', '수', '목', '금', '토'])
                    Expanded(
                      child: Text(
                        w,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          height: 1,
                          fontWeight: FontWeight.w700,
                          color: w == '일'
                              ? AppColors.danger
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 42,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisExtent: 36,
              ),
              itemBuilder: (context, index) {
                if (index < lead || index >= lead + daysInMonth) {
                  return const SizedBox.shrink();
                }
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
                      color: isSelected
                          ? AppColors.charcoal
                          : Colors.transparent,
                      border: isToday && !isSelected
                          ? Border.all(color: AppColors.charcoal)
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$day',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected || isToday
                            ? FontWeight.w800
                            : FontWeight.w500,
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
      ),
    );
  }
}

/// 오전·오후를 나란히 펼친다. 분은 자리별로 고른다. 시계 다이얼·분 그리드 스크롤 금지.
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
      return Localizations(
        locale: _koLocale,
        delegates: _localizationDelegates,
        child: Material(
          type: MaterialType.transparency,
          child: Theme(
            data: _pickerThemeData(dialogContext),
            child: StatefulBuilder(
              builder: (context, setState) {
                final tens = minute ~/ 10;
                final ones = minute % 10;
                return Dialog(
                  backgroundColor: Colors.white,
                  surfaceTintColor: Colors.transparent,
                  insetPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 28,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                        child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            '티오프',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            formatTeeTimeKo(hour, minute),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.4,
                              color: AppColors.charcoal,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _HourColumn(
                                  title: '오전',
                                  isPm: false,
                                  selectedHour: hour,
                                  onSelect: (next) =>
                                      setState(() => hour = next),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _HourColumn(
                                  title: '오후',
                                  isPm: true,
                                  selectedHour: hour,
                                  onSelect: (next) =>
                                      setState(() => hour = next),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            '분',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _DigitRow(
                            label: '10분',
                            values: const [0, 1, 2, 3, 4, 5],
                            selected: tens,
                            keyPrefix: 'tee_min_tens',
                            onSelect: (v) => setState(
                              () => minute = v * 10 + ones,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _DigitRow(
                            label: '1분',
                            values: const [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
                            selected: ones,
                            keyPrefix: 'tee_min_ones',
                            onSelect: (v) => setState(
                              () => minute = tens * 10 + v,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Expanded(
                                child: TextButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.textSecondary,
                                    textStyle: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  child: const Text('취소'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: FilledButton(
                                  onPressed: () => Navigator.of(context).pop(
                                    TimeOfDay(hour: hour, minute: minute),
                                  ),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.charcoal,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    textStyle: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text('확인'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
    },
  );
}

const _kHour12s = [12, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11];

class _HourColumn extends StatelessWidget {
  final String title;
  final bool isPm;
  final int selectedHour;
  final ValueChanged<int> onSelect;

  const _HourColumn({
    required this.title,
    required this.isPm,
    required this.selectedHour,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          childAspectRatio: 1.35,
          children: [
            for (final h12 in _kHour12s)
              _PickCell(
                key: Key(isPm ? 'tee_hour_pm_$h12' : 'tee_hour_am_$h12'),
                label: '$h12',
                selected: selectedHour ==
                    hour24From12(hour12: h12, isPm: isPm),
                onTap: () => onSelect(
                  hour24From12(hour12: h12, isPm: isPm),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _DigitRow extends StatelessWidget {
  final String label;
  final List<int> values;
  final int selected;
  final String keyPrefix;
  final ValueChanged<int> onSelect;

  const _DigitRow({
    required this.label,
    required this.values,
    required this.selected,
    required this.keyPrefix,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 36,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textTertiary,
            ),
          ),
        ),
        Expanded(
          child: Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final v in values)
                _PickCell(
                  key: Key('${keyPrefix}_$v'),
                  label: '$v',
                  selected: selected == v,
                  compact: true,
                  onTap: () => onSelect(v),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PickCell extends StatelessWidget {
  final String label;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  const _PickCell({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(compact ? 8 : 10);
    return Material(
      color: selected ? AppColors.charcoal : const Color(0xFFF7F6F1),
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          width: compact ? 28 : null,
          height: compact ? 32 : null,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: selected ? AppColors.charcoal : const Color(0xFFE4E2D8),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: compact ? 13 : 14,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
