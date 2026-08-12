import "dart:convert";
import "dart:io";

void main() {
  final f = File("lib/screens/schedule/schedule_screen.dart");
  var t = f.readAsStringSync(encoding: utf8);
  final a = "const AppColors.primary".allMatches(t).length;
  final b = "const AppColors.primaryLight".allMatches(t).length;
  t = t.replaceAll("const AppColors.primaryLight", "AppColors.primaryLight");
  t = t.replaceAll("const AppColors.primary", "AppColors.primary");
  f.writeAsStringSync(t, encoding: utf8);
  print("removed const from AppColors.primary x$a, primaryLight x$b");
  print("remain const AppColors.primary=${t.contains('const AppColors.primary')}");
}
