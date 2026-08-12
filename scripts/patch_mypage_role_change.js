const fs = require('fs');
const path = require('path');

const p = path.join(__dirname, '..', 'lib', 'screens', 'ad', 'ad_screen.dart');
let s = fs.readFileSync(p, 'utf8');

if (!s.includes("my_role_change_screen.dart")) {
  const anchor = "import '../../theme/app_theme.dart';\n";
  if (!s.includes(anchor)) {
    console.error('import anchor missing');
    process.exit(1);
  }
  s = s.replace(
    anchor,
    "import '../../theme/app_theme.dart';\nimport '../members/my_role_change_screen.dart';\n",
  );
  console.log('added import');
}

if (!s.includes("label: '직책'")) {
  const marker =
    "            const SizedBox(height: 24),\n\n            // ── 모임 탈퇴";
  const block = `            const SizedBox(height: 24),

            // ── 직책 변경 ────────────────────────────────
            const _AccountSectionHeader(label: '직책'),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const MyRoleChangeScreen(),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 16),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.military_tech_outlined,
                            color: AppColors.primary, size: 18),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('직책 변경',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary)),
                            SizedBox(height: 2),
                            Text('내 모임 선택 후 직책을 수정합니다',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right,
                          color: AppColors.textSecondary),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 28),

            // ── 모임 탈퇴`;
  if (!s.includes(marker)) {
    console.error('marker missing');
    process.exit(1);
  }
  s = s.replace(marker, block);
  console.log('inserted role section');
} else {
  console.log('role section already present');
}

fs.writeFileSync(p, s, 'utf8');
console.log('ok');
