import "dart:convert";
import "dart:io";
void main() {
  final t = File("build/web/main.dart.js").readAsStringSync(encoding: utf8);
  for (final s in ["라운딩 장소", "라운딩 시간", "1일 홀인원보험", "조별로 입력", "레이크사이드", "_RoundHeroCard", "부가 정보"]) {
    print("${t.contains(s) ? "IN" : "NO"} $s");
  }
  // tree-shake may remove unused InsuranceBanner widget strings if never referenced
  final src = File("lib/screens/schedule/schedule_screen.dart").readAsStringSync(encoding: utf8);
  final live = RegExp(r'^\s*if \(!isPast\) _InsuranceBannerCard', multiLine: true).hasMatch(src);
  print("src live insurance call=$live");
  print("src commented=${src.contains('// if (!isPast) _InsuranceBannerCard')}");
}