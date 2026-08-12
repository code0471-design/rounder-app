import 'dart:convert';
import 'dart:io';

void main() {
  final f = File('lib/providers/club_provider.dart');
  var t = f.readAsStringSync(encoding: utf8);
  final start = t.indexOf('    if (!adminSynced) {\n      throw StateError(');
  if (start < 0) {
    stderr.writeln('MISS throw');
    exit(1);
  }
  final end = t.indexOf('\n  }\n\n  /// 내 모임', start);
  if (end < 0) {
    stderr.writeln('MISS end');
    exit(1);
  }
  const neu = '''    if (!adminSynced && syncError != null) {
      debugPrint('[ClubProvider] createClub local-only (admin sync failed)');
    }
    return adminSynced;
  }''';
  t = t.substring(0, start) + neu + t.substring(end);
  f.writeAsStringSync(t, encoding: utf8);
  stdout.writeln('OK hangul=${t.contains('총무')} return=${t.contains('return adminSynced')}');
}
