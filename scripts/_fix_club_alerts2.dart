import "dart:convert";
import "dart:io";

void main() {
  final f = File("lib/screens/club_room/club_room_screen.dart");
  var t = f.readAsStringSync(encoding: utf8);
  final crlf = t.contains("\r\n");
  t = t.replaceAll("\r\n", "\n");

  // Simple replacements for known broken dialogs
  final pairs = <List<String>>[
    [
      '''showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.lock_outline, color: AppColors.danger, size: 20),
            SizedBox(width: 8),
            Text('접근 제한',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: const Text('게스트 회원은 권한이 없습니다.',
            style: TextStyle(fontSize: 14, height: 1.6)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인',
                style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );''',
      '''showDialog(
      context: context,
      useRootNavigator: true,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.lock_outline, color: AppColors.danger, size: 20),
            SizedBox(width: 8),
            Text('접근 제한',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: const Text('게스트 회원은 권한이 없습니다.',
            style: TextStyle(fontSize: 14, height: 1.6)),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(dialogCtx, rootNavigator: true).pop(),
            child: const Text('확인',
                style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );''',
    ],
  ];

  // Broader mechanical fix:
  // 1) builder: (_) => AlertDialog(  -> builder: (dialogCtx) => AlertDialog(
  // 2) after each such change, in a window, replace Navigator.pop(context) used for 확인 buttons
  var count = "builder: (_) => AlertDialog(".allMatches(t).length;
  t = t.replaceAll("builder: (_) => AlertDialog(", "builder: (dialogCtx) => AlertDialog(");
  print("replaced builder=_ count=$count");

  // Ensure useRootNavigator before those builders when missing
  t = t.replaceAllMapped(
    RegExp(
      r"showDialog\(\n(\s*)context: context,\n(\s*)builder: \(dialogCtx\) => AlertDialog\(",
    ),
    (m) =>
        "showDialog(\n${m.group(1)}context: context,\n${m.group(1)}useRootNavigator: true,\n${m.group(2)}builder: (dialogCtx) => AlertDialog(",
  );

  // Fix pops inside dialogCtx AlertDialogs - replace Navigator.pop(context) with dialogCtx pop
  // but ONLY in chunks that have dialogCtx builder. Use iterative window.
  var i = 0;
  var fixed = 0;
  while (true) {
    final start = t.indexOf("builder: (dialogCtx) => AlertDialog(", i);
    if (start < 0) break;
    var end = start + 1800;
    if (end > t.length) end = t.length;
    // stop earlier at next showDialog if closer
    final next = t.indexOf("\n  void ", start + 50);
    if (next > start && next < end) end = next;
    var chunk = t.substring(start, end);
    final before = chunk;
    chunk = chunk.replaceAll(
      "onPressed: () => Navigator.pop(context)",
      "onPressed: () => Navigator.of(dialogCtx, rootNavigator: true).pop()",
    );
    // Don't blindly replace all Navigator.pop(context); — may close screens intentionally after dialog
    // Only replace single-pop confirmations: onPressed bodies that ONLY pop
    if (chunk != before) {
      fixed++;
      t = t.substring(0, start) + chunk + t.substring(end);
      i = start + chunk.length;
    } else {
      i = start + 40;
    }
  }
  print("fixed onPressed pops in chunks=$fixed");

  if (crlf) t = t.replaceAll("\n", "\r\n");
  f.writeAsStringSync(t, encoding: utf8);
  print("remain builder=_=${t.contains('builder: (_) => AlertDialog(')}");
  print("has dialogCtx pop=${t.contains('Navigator.of(dialogCtx, rootNavigator: true).pop()')}");
}