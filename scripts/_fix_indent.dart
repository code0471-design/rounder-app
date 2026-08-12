import "dart:convert";
import "dart:io";
void main() {
  final f = File("lib/screens/schedule/schedule_screen.dart");
  var t = f.readAsStringSync(encoding: utf8);
  t = t.replaceFirst(
    "    static const List<Color> _groupColors = [",
    "  static const List<Color> _groupColors = [",
  );
  f.writeAsStringSync(t, encoding: utf8);
  print("indent fixed");
}
