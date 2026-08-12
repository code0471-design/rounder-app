import "dart:convert";
import "dart:io";
void main() {
  final bytes = File("build/web/main.dart.js").readAsBytesSync();
  final t = utf8.decode(bytes, allowMalformed: true);
  // search code units for 라
  final needle = "라운딩 장소";
  print("utf8 contains=${t.contains(needle)}");
  // maybe minified as separate chars with + 
  print("contains 라운딩=${t.contains("라운딩")}");
  print("contains 장소=${t.contains("장소")}");
  print("contains 티오프=${t.contains("티오프")}");
  // \u escapes
  final esc = "\\uB77C"; // 라
  print("has unicode escape sample=${t.contains(r"\uB77C") || t.contains(r"\ub77c")}");
  // find RoundHero nearby context
  final i = t.indexOf("_RoundHeroCard");
  print("RoundHero idx=$i");
  if (i >= 0) print(t.substring(i, i + 200).replaceAll("\n", " "));
}