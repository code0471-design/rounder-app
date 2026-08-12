import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import '../theme/app_theme.dart';

const _koLocale = Locale('ko', 'KR');

const _localizationDelegates = [
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

ThemeData _pickerThemeData(BuildContext context) {
  return Theme.of(context).copyWith(
    colorScheme: const ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      onSurface: AppColors.textPrimary,
    ),
  );
}

/// showDatePicker 대신 자체 다이얼로그 — MaterialLocalizations 오류 방지
Future<DateTime?> showRounderDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  String? helpText,
  bool useRootNavigator = false,
}) {
  var selected = initialDate;

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
                    height: 320,
                    child: CalendarDatePicker(
                      initialDate: initialDate,
                      firstDate: firstDate,
                      lastDate: lastDate,
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
                        backgroundColor: AppColors.primary,
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

/// showTimePicker 대신 자체 다이얼로그
Future<TimeOfDay?> showRounderTimePicker({
  required BuildContext context,
  required TimeOfDay initialTime,
  bool useRootNavigator = false,
}) {
  var hour = initialTime.hour;
  var minute = initialTime.minute;

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
              content: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  DropdownButton<int>(
                    value: hour,
                    items: List.generate(
                      24,
                      (i) => DropdownMenuItem(
                        value: i,
                        child: Text(i.toString().padLeft(2, '0')),
                      ),
                    ),
                    onChanged: (v) {
                      if (v != null) setState(() => hour = v);
                    },
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text(':', style: TextStyle(fontSize: 20)),
                  ),
                  DropdownButton<int>(
                    value: minute,
                    items: List.generate(
                      60,
                      (i) => DropdownMenuItem(
                        value: i,
                        child: Text(i.toString().padLeft(2, '0')),
                      ),
                    ),
                    onChanged: (v) {
                      if (v != null) setState(() => minute = v);
                    },
                  ),
                ],
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
                    backgroundColor: AppColors.primary,
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
