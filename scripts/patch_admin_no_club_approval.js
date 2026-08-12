/**
 * Remove club-approval (승인대기) from admin UI (part 2 — after createClub already active).
 */
const fs = require('fs');
const path = require('path');

function mustReplace(src, oldS, newS, label) {
  if (!src.includes(oldS)) throw new Error('FAIL: ' + label);
  return src.replace(oldS, newS);
}

function write(rel, src) {
  fs.writeFileSync(path.join(__dirname, '..', rel), src, 'utf8');
  console.log('OK', rel);
}

function read(rel) {
  return fs.readFileSync(path.join(__dirname, '..', rel), 'utf8');
}

// ── admin clubs screen ──
{
  const rel = 'lib/screens/admin/admin_clubs_screen.dart';
  let src = read(rel);

  if (src.includes('승인/반려/블라인드')) {
    src = mustReplace(
      src,
      '//  모임 목록 + 승인/반려/블라인드 기능',
      '//  모임 목록 + 블라인드 기능',
      'header comment',
    );
  }

  if (src.includes("승인대기 $pending건")) {
    src = mustReplace(
      src,
      "  Widget _buildHeader(List<AdminClub> clubs) {\n    final pending = clubs.where((c) => c.status == 'pending').length;\n    return Row(\n      children: [\n        const Text('모임 관리', style: AdminTextStyles.pageTitle),\n        const SizedBox(width: 12),\n        if (pending > 0)\n          AdminBadge(label: '승인대기 $pending건', color: AdminColors.statusWarn),\n        const Spacer(),",
      "  Widget _buildHeader(List<AdminClub> clubs) {\n    return Row(\n      children: [\n        const Text('모임 관리', style: AdminTextStyles.pageTitle),\n        const Spacer(),",
      'header badge',
    );
  }

  if (src.includes("('pending', '승인대기'")) {
    src = mustReplace(
      src,
      "      ('all',     '전체',    clubs.length),\n      ('pending', '승인대기', clubs.where((c) => c.status == 'pending').length),\n      ('active',  '활성',    clubs.where((c) => c.status == 'active').length),",
      "      ('all',     '전체',    clubs.length),\n      ('active',  '활성',    clubs.where((c) => c.status == 'active' || c.status == 'pending').length),",
      'status tabs',
    );
  }

  src = mustReplace(
    src,
    "      final matchStatus = _statusFilter == 'all' || c.status == _statusFilter;",
    "      final matchStatus = _statusFilter == 'all' ||\n          (_statusFilter == 'active'\n              ? (c.status == 'active' || c.status == 'pending')\n              : c.status == _statusFilter);",
    'filter match',
  );

  if (src.includes("AdminActionButton(label: '승인'")) {
    src = mustReplace(
      src,
      "    if (c.status == 'pending') {\n      actions.addAll([\n        AdminActionButton(label: '승인', color: AdminColors.statusOk, onTap: () => _showConfirmDialog(c, 'active'), icon: Icons.check_rounded),\n        const SizedBox(width: 5),\n        AdminActionButton(label: '반려', color: AdminColors.statusDanger, onTap: () => _showConfirmDialog(c, 'ended'), icon: Icons.close_rounded),\n        const SizedBox(width: 5),\n      ]);\n    } else if (c.status == 'active') {",
      "    if (c.status == 'active' || c.status == 'pending') {",
      'row actions',
    );
  }

  if (src.includes("'active':  '승인'")) {
    src = mustReplace(
      src,
      "    final actionLabel = {\n      'active':  '승인',\n      'ended':   '반려',\n      'blinded': '블라인드 처리',\n    }[newStatus] ?? newStatus;",
      "    final actionLabel = {\n      'active':  '활성 복구',\n      'ended':   '종료 처리',\n      'blinded': '블라인드 처리',\n    }[newStatus] ?? newStatus;",
      'confirm labels',
    );
  }

  if (src.includes("label: '승인 처리'")) {
    src = mustReplace(
      src,
      "    if (c.status == 'pending') {\n      actions.addAll([\n        _detailActionBtn(icon: Icons.check_circle_rounded, label: '승인 처리', color: AdminColors.statusOk, onTap: () => _showConfirmDialog(c, 'active')),\n        const SizedBox(height: 8),\n        _detailActionBtn(icon: Icons.cancel_rounded, label: '반려 처리', color: AdminColors.statusDanger, onTap: () => _showConfirmDialog(c, 'ended')),\n      ]);\n    } else if (c.status == 'active') {\n      actions.add(_detailActionBtn(icon: Icons.visibility_off_rounded, label: '블라인드 처리', color: AdminColors.statusDanger, onTap: () => _showConfirmDialog(c, 'blinded')));",
      "    if (c.status == 'active' || c.status == 'pending') {\n      actions.add(_detailActionBtn(icon: Icons.visibility_off_rounded, label: '블라인드 처리', color: AdminColors.statusDanger, onTap: () => _showConfirmDialog(c, 'blinded')));",
      'detail actions',
    );
  }

  write(rel, src);
}

// ── dashboard ──
{
  const rel = 'lib/screens/admin/dashboard_screen.dart';
  let src = read(rel);

  if (src.includes('_buildPendingClubs(admin)')) {
    src = mustReplace(
      src,
      "                  if (wide)\n                    Row(\n                      crossAxisAlignment: CrossAxisAlignment.start,\n                      children: [\n                        Expanded(child: _buildRecentMembers(admin)),\n                        const SizedBox(width: 16),\n                        Expanded(child: _buildPendingClubs(admin)),\n                      ],\n                    )\n                  else ...[\n                    _buildRecentMembers(admin),\n                    const SizedBox(height: 16),\n                    _buildPendingClubs(admin),\n                  ],",
      '                  _buildRecentMembers(admin),',
      'remove pending section',
    );
  }

  if (src.includes('final pending = admin.pendingClubCount;')) {
    src = mustReplace(
      src,
      '    final pending = admin.pendingClubCount;\n',
      '',
      'remove pending var',
    );
  }

  if (src.includes(' · 승인대기 $pending$modeTag')) {
    src = mustReplace(
      src,
      ' · 승인대기 $pending$modeTag',
      '$modeTag',
      'banner pending text',
    );
  }

  if (src.includes('report.pendingNames')) {
    src = mustReplace(
      src,
      "            '${report.pendingNames.isEmpty ? '' : ' (${report.pendingNames.join(\", \")})'}';",
      ';',
      'banner pending names',
    );
  }

  if (src.includes("subLabel: '승인대기 포함'")) {
    src = mustReplace(
      src,
      "        subLabel: '승인대기 포함',",
      "        subLabel: '운영 중',",
      'stat sublabel',
    );
  }

  const start = src.indexOf('  Widget _buildPendingClubs(AdminController admin) {');
  const end = src.indexOf(
    '// ────────────────────────────────────────────────────────────\n//  Weekly Bar Chart',
  );
  if (start >= 0 && end > start) {
    src = src.slice(0, start) + src.slice(end);
  }

  write(rel, src);
}

// ── admin layout ──
{
  const rel = 'lib/screens/admin/admin_layout.dart';
  let src = read(rel);

  if (src.includes('승인대기 없음')) {
    src = mustReplace(
      src,
      "    final pending = report.pendingNames.isEmpty\n        ? '승인대기 없음'\n        : '승인대기: ${report.pendingNames.join(\", \")}';\n    ScaffoldMessenger.of(context).showSnackBar(\n      SnackBar(\n        content: Text(\n          '동기화 완료 · 운영 ${report.operating}개 ($pending)',",
      "    ScaffoldMessenger.of(context).showSnackBar(\n      SnackBar(\n        content: Text(\n          '동기화 완료 · 운영 ${report.operating}개',",
      'sync snack',
    );
  }

  if (src.includes('admin.pendingClubCount')) {
    src = mustReplace(
      src,
      "    final pending = admin.pendingClubCount;\n    final blocked = admin.members.where((m) => m.status == 'blocked').length;\n    return [\n      for (final item in _menuBase)\n        if (item.key == 'clubs' && pending > 0)\n          item.copyWith(badge: pending)\n        else if (item.key == 'members' && blocked > 0)\n          item.copyWith(badge: blocked)\n        else\n          item,",
      "    final blocked = admin.members.where((m) => m.status == 'blocked').length;\n    return [\n      for (final item in _menuBase)\n        if (item.key == 'members' && blocked > 0)\n          item.copyWith(badge: blocked)\n        else\n          item,",
      'menu badge',
    );
  }

  write(rel, src);
}

// ── notifications ──
{
  const rel = 'lib/screens/admin/admin_notifications_screen.dart';
  let src = read(rel);
  const block =
    "            _autoTile(\n" +
    "              title: '모임 승인 시',\n" +
    "              subtitle: '신규 모임이 승인되면 개설자에게 푸시',\n" +
    '              value: _autoClubApproved,\n' +
    '              onChanged: (v) {\n' +
    '                setState(() => _autoClubApproved = v);\n' +
    "                _saveAutoSetting('push_auto_club_approved', v);\n" +
    '              },\n' +
    '            ),\n';
  if (src.includes(block)) {
    src = src.replace(block, '');
    write(rel, src);
  } else {
    console.warn('WARN: club approved tile not found');
  }
}

// ── admin_app_sync: user clubs active ──
{
  const rel = 'lib/features/admin/application/admin_app_sync.dart';
  let src = read(rel);
  if (src.includes("(isUser ? 'pending' : 'active')")) {
    src = src.replace("(isUser ? 'pending' : 'active')", "'active'");
  }
  // Only replace create-path pending, not join-request pending
  src = src.replace(
    /moderationStatus: 'pending'/g,
    "moderationStatus: 'active'",
  );
  write(rel, src);
}

// also club_provider line that still uses isUser pending
{
  const rel = 'lib/providers/club_provider.dart';
  let src = read(rel);
  if (src.includes("(isUser ? 'pending' : 'active')")) {
    src = src.replace("(isUser ? 'pending' : 'active')", "'active'");
    write(rel, src);
  }
}

console.log('DONE');
