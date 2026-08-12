import "dart:convert";
import "dart:io";

void main() {
  final f = File("lib/screens/schedule/schedule_screen.dart");
  var t = f.readAsStringSync(encoding: utf8);

  // Fix illegal const AppColors.*.withValues(...)
  final patterns = [
    RegExp(r"const AppColors\.primary\s*\n\s*\.withValues"),
    RegExp(r"const AppColors\.primary\.withValues"),
    RegExp(r"const AppColors\.primaryLight\s*\n\s*\.withValues"),
    RegExp(r"const AppColors\.primaryLight\.withValues"),
  ];
  var n = 0;
  t = t.replaceAllMapped(RegExp(r"const (AppColors\.(primary|primaryLight)(\s*\n\s*)?\.withValues)"), (m) {
    n++;
    return m.group(0)!.replaceFirst("const ", "");
  });
  // Also: backgroundColor: const AppColors.primary,  -> remove const is OK actually AppColors.primary IS const
  // Error was "Couldn't find constructor AppColors.primary" when written as const AppColors.primary with trailing comma in wrong place?
  // Looking at errors: `const AppColors.primary,` should be valid... unless indentation broke the token.
  // Actually in Dart 3, `const AppColors.primary` as a value is fine. The error "Expected '(' after this" suggests parser thinks AppColors.primary is a constructor call context.
  // Wait - maybe we have `const AppColors.primary.withValues` split across lines incorrectly leaving `const AppColors.primary` alone in a const context that's fine...
  // Error at 4173: backgroundColor: const AppColors.primary,
  // That SHOULD work. Unless AppColors is not imported / primary is a getter not const?
  // Checking app_theme - primary is static const - fine.
  // Perhaps the issue is nested const Column with non-const child?
  // For backgroundColor: const AppColors.primary - if surrounding widget is const constructor requiring const args, fine.
  // "Couldn't find constructor 'AppColors.primary'" happens when you write `const AppColors.primary(...)` or the parser misreads `.withValues` as starting a constructor.
  
  // Fix multiline const AppColors.primary\n.withValues remnants
  t = t.replaceAllMapped(
    RegExp(r"const AppColors\.primary\s*\r?\n\s*\.withValues\(alpha: ([0-9.]+)\)"),
    (m) {
      n++;
      return "AppColors.primary.withValues(alpha: ${m.group(1)})";
    },
  );
  t = t.replaceAllMapped(
    RegExp(r"const AppColors\.primary\.withValues\(alpha: ([0-9.]+)\)"),
    (m) {
      n++;
      return "AppColors.primary.withValues(alpha: ${m.group(1)})";
    },
  );
  t = t.replaceAllMapped(
    RegExp(r"const AppColors\.primaryLight\.withValues\(alpha: ([0-9.]+)\)"),
    (m) {
      n++;
      return "AppColors.primaryLight.withValues(alpha: ${m.group(1)})";
    },
  );

  // backgroundColor: const AppColors.primary - if still errors, remove const
  // Actually for ElevatedButton styleFrom, const AppColors.primary is valid.
  // Re-read error - maybe it's `const AppColors.primary,` inside a const list that got broken.

  f.writeAsStringSync(t, encoding: utf8);
  print("fixed const-withValues n=$n");
  print("remain const AppColors.primary.withValues=${t.contains('const AppColors.primary.withValues')}");
  print("remain const AppColors.primary\\n=${RegExp(r'const AppColors\\.primary\\s*\\n').hasMatch(t)}");
}
