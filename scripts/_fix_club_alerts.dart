import "dart:convert";
import "dart:io";

void main() {
  final f = File("lib/screens/club_room/club_room_screen.dart");
  var t = f.readAsStringSync(encoding: utf8);
  final crlf = t.contains("\r\n");
  t = t.replaceAll("\r\n", "\n");

  // Fix showDialog with builder: (_) => AlertDialog
  var n = 0;
  t = t.replaceAllMapped(
    RegExp(
      r"showDialog\(\s*context:\s*context,\s*(?:useRootNavigator:\s*true,\s*)?builder:\s*_\s*=>\s*AlertDialog\(",
      multiLine: true,
    ),
    (m) {
      n++;
      return "showDialog(\n      context: context,\n      useRootNavigator: true,\n      builder: (dialogCtx) => AlertDialog(";
    },
  );
  print("club_room dialogs hardened=$n");

  // Within those dialogs, common pattern onPressed: () => Navigator.pop(context)
  // Too broad to replace all. Fix pattern near AlertDialog actions that still pop(context)
  // Safer approach: replace Navigator.pop(context) only when immediately after dialogCtx builder
  // and before next showDialog/class — hard.
  // Instead replace in AlertDialog action buttons that say 확인/닫기/취소 with dialogCtx when
  // the surrounding 80 chars include dialogCtx.

  // Replace obvious broken: builder (dialogCtx) blocks still calling Navigator.pop(context)
  // Do a multi-pass: for each "builder: (dialogCtx) => AlertDialog" find until matching actions end
  final parts = <String>[];
  var i = 0;
  var fixedPops = 0;
  while (true) {
    final start = t.indexOf("builder: (dialogCtx) => AlertDialog(", i);
    if (start < 0) break;
    // find a reasonable end window (next showDialog or 2500 chars)
    var end = t.indexOf("showDialog(", start + 10);
    if (end < 0 || end - start > 3000) end = (start + 3000).clamp(0, t.length);
    var chunk = t.substring(start, end);
    final before = chunk;
    chunk = chunk.replaceAll(
      "onPressed: () => Navigator.pop(context)",
      "onPressed: () => Navigator.of(dialogCtx, rootNavigator: true).pop()",
    );
    chunk = chunk.replaceAll(
      "Navigator.pop(context);",
      "Navigator.of(dialogCtx, rootNavigator: true).pop();",
    );
    if (chunk != before) {
      fixedPops++;
      t = t.substring(0, start) + chunk + t.substring(end);
      i = start + chunk.length;
    } else {
      i = start + 40;
    }
  }
  print("club_room dialog pops fixed blocks=$fixedPops");

  if (crlf) t = t.replaceAll("\n", "\r\n");
  f.writeAsStringSync(t, encoding: utf8);
  print("korean still=${t.contains('참석')}");
}