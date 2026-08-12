import "dart:convert";
import "dart:io";

void main() {
  final t = File("lib/screens/schedule/schedule_screen.dart").readAsStringSync(encoding: utf8);
  print("참석=${t.contains('참석')} 조편성 보기=${t.contains('조편성 보기')} 스코어 입력=${t.contains('스코어 입력')}");
  print("len=${t.length}");

  // find remaining problematic const AppColors
  final re = RegExp(r"const AppColors\.primary[^\n,]{0,40}");
  for (final m in re.allMatches(t)) {
    final line = t.substring(0, m.start).split("\n").length;
    print("L$line: ${m.group(0)}");
  }

  // find withValues after AppColors.primary that might still be const-wrapped via parent
  final re2 = RegExp(r"const ([^\n]{0,60}AppColors\.primary[^\n]{0,80})");
  var c = 0;
  for (final m in re2.allMatches(t)) {
    c++;
    if (c <= 20) {
      final line = t.substring(0, m.start).split("\n").length;
      print("CTX L$line: ${m.group(1)}");
    }
  }
  print("const contexts=$c");
}
