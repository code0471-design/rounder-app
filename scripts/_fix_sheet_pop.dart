import "dart:convert";
import "dart:io";

void main() {
  final f = File("lib/screens/schedule/schedule_screen.dart");
  var t = f.readAsStringSync(encoding: utf8);
  final crlf = t.contains("\r\n");
  t = t.replaceAll("\r\n", "\n");

  // Revert bottom-sheet photo upload pop (must NOT use rootNavigator)
  const bad = '''                    provider.addPhoto(
                      scheduleId: schedule.id,
                      caption: captionController.text,
                    );
                    Navigator.of(ctx, rootNavigator: true).pop();''';
  const good = '''                    provider.addPhoto(
                      scheduleId: schedule.id,
                      caption: captionController.text,
                    );
                    Navigator.pop(ctx);''';
  if (t.contains(bad)) {
    t = t.replaceFirst(bad, good);
    print("OK photo sheet pop reverted");
  } else {
    print("WARN photo sheet pattern miss");
  }

  // Ensure waiting dialogs use rootNavigator: true
  t = t.replaceAll(
    '''void _showWaitingDialog(
      BuildContext context, ClubProvider provider, RoundSchedule schedule) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(''',
    '''void _showWaitingDialog(
      BuildContext context, ClubProvider provider, RoundSchedule schedule) {
    showDialog(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(''',
  );

  // Second waiting dialog (card variant)
  t = t.replaceAllMapped(
    RegExp(
      r"(void _showAttendFullDialogCard\([\s\S]*?showDialog\(\s*context: context,\s*)builder:",
    ),
    (m) {
      if (m.group(1)!.contains("useRootNavigator")) return m.group(0)!;
      return "${m.group(1)}useRootNavigator: true,\n      builder:";
    },
  );

  // Generic: any showDialog( context: context, builder: (ctx) without useRootNavigator
  t = t.replaceAllMapped(
    RegExp(
      r"showDialog\(\s*context:\s*context,\s*builder:\s*\(ctx\)\s*=>\s*AlertDialog",
      multiLine: true,
    ),
    (m) =>
        "showDialog(\n      context: context,\n      useRootNavigator: true,\n      builder: (ctx) => AlertDialog",
  );
  print("OK dialogs useRootNavigator");

  // Verify waiting list Text title
  final waitPlain = t.contains("Text('대기 명단',");
  final waitOld = RegExp(r"Text\('대기 명단 \(정원").hasMatch(t);
  print("waitPlain=$waitPlain waitOldText=$waitOld");

  if (crlf) t = t.replaceAll("\n", "\r\n");
  f.writeAsStringSync(t, encoding: utf8);
  print("DONE");
}