const fs = require('fs');
const path = require('path');

const file = path.join(
  __dirname,
  '..',
  'lib',
  'screens',
  'group_assignment',
  'group_assignment_screen.dart',
);

let src = fs.readFileSync(file, 'utf8');

const from = `class _SlotRow extends StatelessWidget {
  final GroupSlot slot;
  final int slotIndex;
  final Color groupColor;
  final bool isFinalized;
  final VoidCallback? onTap;
  final ValueChanged<GroupSlot> onDrop;
  final VoidCallback onClear;
  final VoidCallback? onDragStarted;
  final VoidCallback onDragEnded;

  const _SlotRow({
    required this.slot,
    required this.slotIndex,
    required this.groupColor,
    required this.isFinalized,
    required this.onTap,
    required this.onDrop,
    required this.onClear,
    required this.onDragStarted,
    required this.onDragEnded,
  });

  @override
  Widget build(BuildContext context) {
    if (slot.isEmpty) {
      // ── 빈 슬롯 ──
      return DragTarget<GroupSlot>(
        onWillAcceptWithDetails: (d) => d.data.isFilled && !isFinalized,
        onAcceptWithDetails: (d) => onDrop(d.data),
        builder: (_, candidateData, __) {
          final hovering = candidateData.isNotEmpty;
          return GestureDetector(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 62,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: hovering
                    ? groupColor.withValues(alpha: 0.06)
                    : Colors.transparent,
              ),
              child: Row(
                children: [
                  // 슬롯 번호
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: hovering
                          ? groupColor.withValues(alpha: 0.15)
                          : const Color(0xFFF5F5F5),
                      shape: BoxShape.circle,
                      border: hovering
                          ? Border.all(
                              color: groupColor.withValues(alpha: 0.4))
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        '\${slotIndex + 1}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: hovering
                              ? groupColor
                              : const Color(0xFFBDBDBD),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      hovering ? '여기에 놓기 ↓' : '+ 멤버 추가',
                      style: TextStyle(
                        fontSize: 13,
                        color: hovering
                            ? groupColor
                            : const Color(0xFFD0D0D0),
                        fontWeight: hovering
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                  if (!isFinalized && !hovering)
                    Icon(Icons.add_circle_outline,
                        size: 20,
                        color: groupColor.withValues(alpha: 0.35)),
                  if (hovering)
                    Icon(Icons.south_rounded,
                        size: 18, color: groupColor),
                ],
              ),
            ),
          );
        },
      );
    }

    // ── 채워진 슬롯 ──
    final genderIcon = slot.gender == '여' ? '♀' : '♂';
    final genderColor = slot.gender == '여'
        ? const Color(0xFFE91E63)
        : AppColors.primaryLight;

    final rowContent = DragTarget<GroupSlot>(
      onWillAcceptWithDetails: (d) =>
          d.data.isFilled &&
          d.data.memberId != slot.memberId &&
          !isFinalized,
      onAcceptWithDetails: (d) => onDrop(d.data),
      builder: (_, candidateData, __) {
        final hovering = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 62,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: hovering
                ? groupColor.withValues(alpha: 0.05)
                : Colors.transparent,
          ),
          child: Row(
            children: [
              // 아바타
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      groupColor.withValues(alpha: 0.18),
                      groupColor.withValues(alpha: 0.08),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    slot.memberName!.substring(0, 1),
                    style: TextStyle(
                      color: groupColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Text(
                          slot.memberName!,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: Color(0xFF1C2B36),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(genderIcon,
                            style: TextStyle(
                                fontSize: 11, color: genderColor)),
                      ],
                    ),
                    if (slot.handicap != null)
                      Text(
                        '핸디 \${slot.handicap!.toStringAsFixed(0)}',
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF90A4AE)),
                      ),
                  ],
                ),
              ),
              if (hovering)
                Icon(Icons.swap_horiz_rounded,
                    size: 22, color: groupColor),
              // X 삭제 버튼
              if (!isFinalized && !hovering)
                GestureDetector(
                  onTap: onClear,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: const Icon(Icons.close_rounded,
                        size: 14, color: Color(0xFF90A4AE)),
                  ),
                ),
            ],
          ),
        );
      },
    );`;

const to = `class _SlotRow extends StatelessWidget {
  final GroupSlot slot;
  final int slotIndex;
  final Color groupColor;
  final bool isFinalized;
  final bool compact;
  final VoidCallback? onTap;
  final ValueChanged<GroupSlot> onDrop;
  final VoidCallback onClear;
  final VoidCallback? onDragStarted;
  final VoidCallback onDragEnded;

  const _SlotRow({
    required this.slot,
    required this.slotIndex,
    required this.groupColor,
    required this.isFinalized,
    this.compact = false,
    required this.onTap,
    required this.onDrop,
    required this.onClear,
    required this.onDragStarted,
    required this.onDragEnded,
  });

  @override
  Widget build(BuildContext context) {
    final rowH = compact ? 48.0 : 62.0;
    final hPad = compact ? 8.0 : 16.0;
    final avatar = compact ? 28.0 : 38.0;

    if (slot.isEmpty) {
      // ── 빈 슬롯 ──
      return DragTarget<GroupSlot>(
        onWillAcceptWithDetails: (d) => d.data.isFilled && !isFinalized,
        onAcceptWithDetails: (d) => onDrop(d.data),
        builder: (_, candidateData, __) {
          final hovering = candidateData.isNotEmpty;
          return GestureDetector(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: rowH,
              padding: EdgeInsets.symmetric(horizontal: hPad),
              decoration: BoxDecoration(
                color: hovering
                    ? groupColor.withValues(alpha: 0.06)
                    : Colors.transparent,
              ),
              child: Row(
                children: [
                  // 슬롯 번호
                  Container(
                    width: compact ? 24 : 30,
                    height: compact ? 24 : 30,
                    decoration: BoxDecoration(
                      color: hovering
                          ? groupColor.withValues(alpha: 0.15)
                          : const Color(0xFFF5F5F5),
                      shape: BoxShape.circle,
                      border: hovering
                          ? Border.all(
                              color: groupColor.withValues(alpha: 0.4))
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        '\${slotIndex + 1}',
                        style: TextStyle(
                          fontSize: compact ? 11 : 13,
                          fontWeight: FontWeight.w700,
                          color: hovering
                              ? groupColor
                              : const Color(0xFFBDBDBD),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: compact ? 8 : 14),
                  Expanded(
                    child: Text(
                      hovering
                          ? '놓기'
                          : (compact ? '+ 추가' : '+ 멤버 추가'),
                      style: TextStyle(
                        fontSize: compact ? 11 : 13,
                        color: hovering
                            ? groupColor
                            : const Color(0xFFD0D0D0),
                        fontWeight: hovering
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (!isFinalized && !hovering && !compact)
                    Icon(Icons.add_circle_outline,
                        size: 20,
                        color: groupColor.withValues(alpha: 0.35)),
                  if (hovering)
                    Icon(Icons.south_rounded,
                        size: compact ? 14 : 18, color: groupColor),
                ],
              ),
            ),
          );
        },
      );
    }

    // ── 채워진 슬롯 ──
    final genderIcon = slot.gender == '여' ? '♀' : '♂';
    final genderColor = slot.gender == '여'
        ? const Color(0xFFE91E63)
        : AppColors.primaryLight;

    final rowContent = DragTarget<GroupSlot>(
      onWillAcceptWithDetails: (d) =>
          d.data.isFilled &&
          d.data.memberId != slot.memberId &&
          !isFinalized,
      onAcceptWithDetails: (d) => onDrop(d.data),
      builder: (_, candidateData, __) {
        final hovering = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: rowH,
          padding: EdgeInsets.symmetric(horizontal: hPad),
          decoration: BoxDecoration(
            color: hovering
                ? groupColor.withValues(alpha: 0.05)
                : Colors.transparent,
          ),
          child: Row(
            children: [
              // 아바타
              Container(
                width: avatar,
                height: avatar,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      groupColor.withValues(alpha: 0.18),
                      groupColor.withValues(alpha: 0.08),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    slot.memberName!.substring(0, 1),
                    style: TextStyle(
                      color: groupColor,
                      fontWeight: FontWeight.w800,
                      fontSize: compact ? 12 : 16,
                    ),
                  ),
                ),
              ),
              SizedBox(width: compact ? 6 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            slot.memberName!,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: compact ? 12 : 14,
                              color: const Color(0xFF1C2B36),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 3),
                        Text(genderIcon,
                            style: TextStyle(
                                fontSize: compact ? 10 : 11,
                                color: genderColor)),
                      ],
                    ),
                    if (slot.handicap != null && !compact)
                      Text(
                        '핸디 \${slot.handicap!.toStringAsFixed(0)}',
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF90A4AE)),
                      ),
                  ],
                ),
              ),
              if (hovering)
                Icon(Icons.swap_horiz_rounded,
                    size: compact ? 16 : 22, color: groupColor),
              // X 삭제 버튼
              if (!isFinalized && !hovering)
                GestureDetector(
                  onTap: onClear,
                  child: Container(
                    width: compact ? 22 : 28,
                    height: compact ? 22 : 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Icon(Icons.close_rounded,
                        size: compact ? 12 : 14,
                        color: const Color(0xFF90A4AE)),
                  ),
                ),
            ],
          ),
        );
      },
    );`;

if (!src.includes(from)) {
  console.error('slot row block not found');
  // debug: check if compact already added
  if (src.includes('final bool compact')) {
    console.log('already has compact');
    process.exit(0);
  }
  process.exit(1);
}

src = src.replace(from, to);
fs.writeFileSync(file, src, 'utf8');
console.log('patched slot row compact');
