/**
 * Schedule list UI → OneClub (date tile + gold tab/FAB).
 * UTF-8 Node patch — do not StrReplace schedule_screen.dart.
 */
const fs = require('fs');
const path = require('path');

const file = path.join(__dirname, '..', 'lib', 'screens', 'schedule', 'schedule_screen.dart');
const fragment = path.join(__dirname, 'fragments', 'schedule_card_oneclub.dart');
let src = fs.readFileSync(file, 'utf8');
const nl = src.includes('\r\n') ? '\r\n' : '\n';
let card = fs.readFileSync(fragment, 'utf8');
if (nl === '\r\n') card = card.replace(/\n/g, '\r\n');
if (!card.endsWith(nl)) card += nl;

function mustReplace(oldStr, newStr, label) {
  oldStr = oldStr.replace(/\n/g, nl);
  newStr = newStr.replace(/\n/g, nl);
  if (!src.includes(oldStr)) {
    console.error('anchor not found: ' + label);
    process.exit(1);
  }
  src = src.replace(oldStr, newStr);
}

if (src.includes('class _ScheduleDateTile')) {
  console.log('already patched');
  process.exit(0);
}

mustReplace(
  `                  labelColor: AppColors.sageDeep,
                  unselectedLabelColor: AppColors.inkSoft,
                  indicatorColor: AppColors.sageDeep,
                  indicatorWeight: 2,
                  indicatorSize: TabBarIndicatorSize.label,
                  dividerColor: Colors.transparent,
                  labelStyle: const TextStyle(
                      fontFamily: 'NanumGothic', fontSize: 15,
                      fontWeight: FontWeight.w700),
                  unselectedLabelStyle: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w500),`,
  `                  labelColor: const Color(0xFF111827),
                  unselectedLabelColor: AppColors.inkSoft,
                  indicatorColor: AppColors.accent,
                  indicatorWeight: 3,
                  indicatorSize: TabBarIndicatorSize.label,
                  dividerColor: Colors.transparent,
                  labelStyle: const TextStyle(
                      fontFamily: 'NanumGothic', fontSize: 15,
                      fontWeight: FontWeight.w800),
                  unselectedLabelStyle: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w500),`,
  'tab bar',
);

mustReplace(
  `                  backgroundColor: AppColors.sageDeep,
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.add),
                  label: const Text('일정 등록',
                      style: TextStyle(fontWeight: FontWeight.w600)),`,
  `                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text('일정 등록',
                      style: TextStyle(
                          fontWeight: FontWeight.w800, color: Colors.white)),`,
  'fab',
);

mustReplace(
  `                  color: AppColors.sageDeep,`,
  `                  color: AppColors.accent,`,
  'past more color',
);

const cardStart = src.indexOf('class _ScheduleCard extends StatelessWidget {');
const chipStart = src.indexOf('// chip 2 (디자인 사양: go=sage, maybe=amber, no=rose)');
if (cardStart < 0 || chipStart < 0 || chipStart <= cardStart) {
  console.error('schedule card block not found');
  process.exit(1);
}
src = src.slice(0, cardStart) + card + src.slice(chipStart);

mustReplace(
  `class _AttChip2 extends StatelessWidget {
  final String label;
  final int count;
  final bool isMaybe;
  final bool isNo;
  const _AttChip2(this.label, this.count, this.isMaybe, this.isNo);

  @override
  Widget build(BuildContext context) {
    Color bg, fg;
    if (isNo) {
      bg = AppColors.roseSoft; fg = const Color(0xFF8F5555);
    } else if (isMaybe) {
      bg = AppColors.amberSoft; fg = const Color(0xFF7A5A35);
    } else {
      bg = AppColors.sageDeep.withValues(alpha: 0.15); fg = AppColors.sageDeep;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text('\$label \$count',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: fg)),
    );
  }
}`,
  `class _AttChip2 extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _AttChip2(this.label, this.count, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Text(
        '\$label \$count',
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}`,
  'att chip',
);

mustReplace(
  `    final responded = currentResponse != null;
    final color = responded
        ? (currentResponse == '참석'
            ? AppColors.success
            : currentResponse == '불참'
                ? AppColors.danger
                : AppColors.warning)
        : AppColors.sageDeep;

    return GestureDetector(
      onTap: () => _showResponseSheet(context),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: responded ? 14 : 12, vertical: 7),
        decoration: BoxDecoration(
          color: responded ? color.withValues(alpha: 0.13) : AppColors.sageDeep,
          borderRadius: BorderRadius.circular(20),
          border: responded ? Border.all(color: color, width: 1.5) : null,
          boxShadow: responded ? [
            BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 4, offset: const Offset(0, 1))
          ] : null,
        ),
        child: Text(
          responded ? currentResponse! : '응답하기',
          style: TextStyle(
            fontSize: responded ? 18 : 12,
            fontWeight: FontWeight.w700,
            color: responded ? color : Colors.white,
            letterSpacing: responded ? 0.3 : 0,
          ),
        ),
      ),
    );`,
  `    final responded = currentResponse != null;
    final isAttend = currentResponse == '참석';
    final isDecline = currentResponse == '불참';
    final label = responded ? currentResponse! : '미답변';

    return GestureDetector(
      onTap: () => _showResponseSheet(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isAttend ? const Color(0xFF111827) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: isAttend
              ? null
              : Border.all(
                  color: isDecline
                      ? const Color(0xFFE53935)
                      : const Color(0xFF9CA3AF),
                ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: isAttend
                ? Colors.white
                : isDecline
                    ? const Color(0xFFE53935)
                    : const Color(0xFF6B7280),
          ),
        ),
      ),
    );`,
  'attend button',
);

fs.writeFileSync(file, src);
console.log('patched schedule list to OneClub UI');
