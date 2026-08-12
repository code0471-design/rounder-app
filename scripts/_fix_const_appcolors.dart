import 'dart:convert';
import 'dart:io';

void main() {
  final f = File('lib/screens/schedule/schedule_screen.dart');
  var t = f.readAsStringSync(encoding: utf8);

  // Invalid: const AppColors.xxx.withValues(...)
  final re = RegExp(r'const AppColors\.(primary(?:Dark|Light)?)\s*\n?\s*\.withValues');
  t = t.replaceAllMapped(re, (m) => 'AppColors.${m[1]}.withValues');

  // Also single-line
  t = t.replaceAllMapped(
    RegExp(r'const AppColors\.(primary(?:Dark|Light)?)\.withValues'),
    (m) => 'AppColors.${m[1]}.withValues',
  );

  f.writeAsStringSync(t, encoding: utf8);
  final still = RegExp(r'const AppColors\.primary').hasMatch(t);
  print('stillConstAppColorsPrimary=$still hangul=${t.contains('조편성')}');
}
