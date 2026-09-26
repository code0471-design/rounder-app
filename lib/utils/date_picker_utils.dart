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

/// 휠 아래 확정 문구. 예: 오후 1시 13분
String formatTeeTimeConfirmKo(int hour, int minute) {
  final period = isAfternoonHour(hour) ? '오후' : '오전';
  return '$period ${hour12From24(hour)}시 ${clampTeeMinute(minute)}분';
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

/// 갤럭시 알람처럼 오전·시·분을 세로 휠로 고른다. 시계 다이얼·분 그리드 금지.
const kRounderAlarmWheelExtent = 56.0;

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
                final isPm = isAfternoonHour(hour);
                final hour12 = hour12From24(hour);
                return Dialog(
                  backgroundColor: const Color(0xFFF7F7F7),
                  surfaceTintColor: Colors.transparent,
                  insetPadding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 28,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 20, 8, 14),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            '티오프',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: kRounderAlarmWheelExtent * 3,
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 4,
                                  child: _AlarmWheel(
                                    key: const Key('tee_period_wheel'),
                                    labels: const ['오전', '오후'],
                                    selectedIndex: isPm ? 1 : 0,
                                    looping: false,
                                    itemKeys: const [
                                      Key('tee_period_am'),
                                      Key('tee_period_pm'),
                                    ],
                                    onSelected: (i) => setState(() {
                                      hour = hour24From12(
                                        hour12: hour12From24(hour),
                                        isPm: i == 1,
                                      );
                                    }),
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: _AlarmWheel(
                                    key: const Key('tee_hour_wheel'),
                                    labels: [
                                      for (var h = 1; h <= 12; h++) '$h',
                                    ],
                                    selectedIndex: hour12 == 12 ? 11 : hour12 - 1,
                                    onSelected: (i) => setState(() {
                                      final next12 = i + 1;
                                      hour = hour24From12(
                                        hour12: next12,
                                        isPm: isAfternoonHour(hour),
                                      );
                                    }),
                                  ),
                                ),
                                const SizedBox(
                                  width: 10,
                                  child: Text(
                                    ':',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 34,
                                      fontWeight: FontWeight.w700,
                                      height: 1,
                                      color: Color(0xFF111111),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: _AlarmWheel(
                                    key: const Key('tee_min_wheel'),
                                    labels: [
                                      for (var m = 0; m <= 59; m++) '$m',
                                    ],
                                    selectedIndex: minute,
                                    onSelected: (i) =>
                                        setState(() => minute = i),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: () => Navigator.of(context).pop(
                                TimeOfDay(hour: hour, minute: minute),
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.charcoal,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                '${formatTeeTimeConfirmKo(hour, minute)} 확인',
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.textSecondary,
                              textStyle: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            child: const Text('취소'),
                          ),
                        ],
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

class _AlarmWheel extends StatefulWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final bool looping;
  final List<Key>? itemKeys;

  const _AlarmWheel({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
    this.looping = true,
    this.itemKeys,
  });

  @override
  State<_AlarmWheel> createState() => _AlarmWheelState();
}

class _AlarmWheelState extends State<_AlarmWheel> {
  static const _loops = 40;
  late final FixedExtentScrollController _ctrl;
  late int _index;

  int get _count => widget.labels.length;

  int _base() => widget.looping ? (_loops ~/ 2) * _count : 0;

  @override
  void initState() {
    super.initState();
    _index = widget.selectedIndex.clamp(0, _count - 1);
    _ctrl = FixedExtentScrollController(initialItem: _base() + _index);
  }

  @override
  void didUpdateWidget(covariant _AlarmWheel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _index = widget.selectedIndex.clamp(0, _count - 1);
      final target = _base() + _index;
      if (_ctrl.hasClients && _ctrl.selectedItem % _count != _index) {
        _ctrl.jumpToItem(target);
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final itemCount = widget.looping ? _count * _loops : _count;
    return ListWheelScrollView.useDelegate(
      controller: _ctrl,
      itemExtent: kRounderAlarmWheelExtent,
      perspective: 0.002,
      diameterRatio: 8,
      physics: const FixedExtentScrollPhysics(),
      onSelectedItemChanged: (i) {
        final next = i % _count;
        if (next == _index) return;
        setState(() => _index = next);
        widget.onSelected(next);
      },
      childDelegate: ListWheelChildBuilderDelegate(
        childCount: itemCount,
        builder: (context, i) {
          final value = i % _count;
          final selected = value == _index;
          final label = widget.labels[value];
          final itemKey = widget.itemKeys != null && i < _count
              ? widget.itemKeys![value]
              : null;
          return GestureDetector(
            key: itemKey,
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (value == _index) return;
              _ctrl.animateToItem(
                widget.looping ? _base() + value : value,
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
              );
            },
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: selected ? 34 : 26,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  height: 1,
                  color: selected
                      ? const Color(0xFF111111)
                      : const Color(0xFFC4C4C4),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
