// ════════════════════════════════════════════════════════════
//  ROUNDER Admin — Member Management
//  회원 목록 DataTable + 검색/필터 + 상세보기
// ════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'admin_theme.dart';
import 'package:provider/provider.dart';
import '../../features/admin/application/admin_controller.dart';
import '../../services/csv_download.dart';
import '../../services/member_roster_csv.dart';
import 'admin_models.dart';

class AdminMembersScreen extends StatefulWidget {
  const AdminMembersScreen({super.key});

  @override
  State<AdminMembersScreen> createState() => _AdminMembersScreenState();
}

class _AdminMembersScreenState extends State<AdminMembersScreen> {
  final _searchCtrl = TextEditingController();
  String _statusFilter = 'all'; // all | normal | blocked
  String _genderFilter = 'all'; // all | 남 | 여
  String _sortBy = 'joinDate'; // joinDate | name | clubCount
  bool _sortAsc = false;
  AdminMember? _selectedMember;

  List<AdminMember> _filtered(List<AdminMember> source) {
    var list = source.where((m) {
      final q = _searchCtrl.text.trim().toLowerCase();
      final matchSearch = q.isEmpty ||
          m.name.toLowerCase().contains(q) ||
          m.phone.contains(q) ||
          m.nickname.toLowerCase().contains(q);
      final matchStatus = _statusFilter == 'all' || m.status == _statusFilter;
      final matchGender = _genderFilter == 'all' || m.gender == _genderFilter;
      return matchSearch && matchStatus && matchGender;
    }).toList();

    list.sort((a, b) {
      int cmp;
      switch (_sortBy) {
        case 'name':      cmp = a.name.compareTo(b.name); break;
        case 'clubCount': cmp = a.clubCount.compareTo(b.clubCount); break;
        case 'joinDate':
        default:          cmp = a.joinDate.compareTo(b.joinDate); break;
      }
      return _sortAsc ? cmp : -cmp;
    });
    return list;
  }

  Future<void> _downloadExcel(List<AdminMember> source) async {
    final members = _filtered(source);
    if (members.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('다운로드할 회원이 없습니다')),
      );
      return;
    }
    try {
      await downloadCsvFile(
        filename: 'ROUNDER_회원명단.xlsx',
        bytes: adminMemberRosterXlsx(members),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('파일 앱의 다운로드 폴더에서 열어 주세요')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('엑셀 파일을 만들지 못했습니다')),
      );
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminController>();
    final members = admin.members;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Main Content
        Expanded(
          flex: _selectedMember != null ? 6 : 10,
          child: _buildMainContent(admin, members),
        ),
        // ── Detail Panel
        if (_selectedMember != null) ...[
          const SizedBox(width: 0),
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 320,
            child: _buildDetailPanel(_selectedMember!),
          ),
        ],
      ],
    );
  }

  Widget _buildMainContent(AdminController admin, List<AdminMember> members) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AdminSizes.sectionPadding,
        AdminSizes.listPagePaddingTop,
        AdminSizes.sectionPadding,
        AdminSizes.sectionPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header
          _buildHeader(members),
          const SizedBox(height: 20),

          // ── Search & Filters
          AdminCard(
            padding: const EdgeInsets.all(16),
            child: _buildFilters(),
          ),
          const SizedBox(height: 16),

          // ── Table
          AdminCard(
            padding: EdgeInsets.zero,
            child: _buildTable(members),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildHeader(List<AdminMember> members) {
    final total = _filtered(members).length;
    final blocked = _filtered(members).where((m) => m.status == 'blocked').length;

    return Row(
      children: [
        const Text('회원 관리', style: AdminTextStyles.pageTitle),
        const SizedBox(width: 12),
        AdminBadge(label: '전체 $total명', color: AdminColors.accent),
        const SizedBox(width: 6),
        AdminBadge(label: '차단 $blocked명', color: AdminColors.statusDanger),
        const Spacer(),
        InkWell(
          onTap: () => _downloadExcel(members),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AdminColors.accent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.file_download_outlined, color: Colors.white, size: 15),
                SizedBox(width: 6),
                Text('엑셀 다운로드', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilters() {
    return Wrap(
      spacing: 12,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Search
        SizedBox(
          width: 260,
          height: 38,
          child: TextField(
            controller: _searchCtrl,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: '이름, 연락처, 닉네임 검색',
              hintStyle: const TextStyle(fontSize: 13, color: AdminColors.textHint),
              prefixIcon: const Icon(Icons.search, size: 18, color: AdminColors.textHint),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AdminColors.cardBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AdminColors.cardBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AdminColors.accent),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
              filled: true,
              fillColor: AdminColors.contentBg,
            ),
          ),
        ),

        // Status Filter
        _buildDropdown<String>(
          value: _statusFilter,
          items: const [
            DropdownMenuItem(value: 'all',     child: Text('전체 상태')),
            DropdownMenuItem(value: 'normal',  child: Text('정상')),
            DropdownMenuItem(value: 'blocked', child: Text('차단')),
          ],
          onChanged: (v) => setState(() => _statusFilter = v!),
          width: 110,
        ),

        // Gender Filter
        _buildDropdown<String>(
          value: _genderFilter,
          items: const [
            DropdownMenuItem(value: 'all', child: Text('전체 성별')),
            DropdownMenuItem(value: '남',  child: Text('남성')),
            DropdownMenuItem(value: '여',  child: Text('여성')),
          ],
          onChanged: (v) => setState(() => _genderFilter = v!),
          width: 110,
        ),

        // Sort
        _buildDropdown<String>(
          value: _sortBy,
          items: const [
            DropdownMenuItem(value: 'joinDate',  child: Text('가입일 순')),
            DropdownMenuItem(value: 'name',      child: Text('이름 순')),
            DropdownMenuItem(value: 'clubCount', child: Text('모임수 순')),
          ],
          onChanged: (v) => setState(() => _sortBy = v!),
          width: 120,
        ),

        // Sort Direction
        InkWell(
          onTap: () => setState(() => _sortAsc = !_sortAsc),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              border: Border.all(color: AdminColors.cardBorder),
              borderRadius: BorderRadius.circular(8),
              color: AdminColors.contentBg,
            ),
            child: Icon(
              _sortAsc ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
              size: 17,
              color: AdminColors.textSecond,
            ),
          ),
        ),

        // Reset
        InkWell(
          onTap: () => setState(() {
            _searchCtrl.clear();
            _statusFilter = 'all';
            _genderFilter = 'all';
            _sortBy = 'joinDate';
            _sortAsc = false;
          }),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              border: Border.all(color: AdminColors.cardBorder),
              borderRadius: BorderRadius.circular(8),
              color: AdminColors.contentBg,
            ),
            child: const Text('초기화', style: TextStyle(fontSize: 13, color: AdminColors.textSecond)),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown<T>({
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    double width = 130,
  }) {
    return SizedBox(
      width: width,
      height: 38,
      child: DropdownButtonFormField<T>(
        value: value,
        items: items,
        onChanged: onChanged,
        style: const TextStyle(fontSize: 13, color: AdminColors.textPrimary),
        decoration: InputDecoration(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AdminColors.cardBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AdminColors.cardBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AdminColors.accent),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
          filled: true,
          fillColor: AdminColors.contentBg,
        ),
        dropdownColor: Colors.white,
        icon: const Icon(Icons.expand_more_rounded, size: 18, color: AdminColors.textSecond),
      ),
    );
  }

  Widget _buildTable(List<AdminMember> source) {
    final members = _filtered(source);
    return Column(
      children: [
        // Table Header
        _buildTableHeader(),
        // Table Rows
        if (members.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.people_outline, size: 40, color: AdminColors.textHint),
                  SizedBox(height: 8),
                  Text('검색 결과가 없습니다', style: TextStyle(color: AdminColors.textHint, fontSize: 14)),
                ],
              ),
            ),
          )
        else
          ...members.asMap().entries.map((e) => _buildTableRow(e.value, e.key.isEven)),
      ],
    );
  }

  Widget _buildTableHeader() {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(bottom: BorderSide(color: AdminColors.cardBorder)),
        borderRadius: BorderRadius.vertical(top: Radius.circular(AdminSizes.cardRadius)),
      ),
      child: Row(
        children: const [
          SizedBox(width: 40, child: Text('',         style: AdminTextStyles.tableHeader)),
          Expanded(flex: 3, child: Text('이름',       style: AdminTextStyles.tableHeader)),
          Expanded(flex: 4, child: Text('연락처',     style: AdminTextStyles.tableHeader)),
          Expanded(flex: 3, child: Text('닉네임',     style: AdminTextStyles.tableHeader)),
          Expanded(flex: 2, child: Text('성별',       style: AdminTextStyles.tableHeader)),
          Expanded(flex: 3, child: Text('가입일',     style: AdminTextStyles.tableHeader)),
          Expanded(flex: 2, child: Text('모임수',     style: AdminTextStyles.tableHeader)),
          Expanded(flex: 2, child: Text('상태',       style: AdminTextStyles.tableHeader)),
          SizedBox(width: 100, child: Text('액션',    style: AdminTextStyles.tableHeader)),
        ],
      ),
    );
  }

  Widget _buildTableRow(AdminMember m, bool even) {
    final isSelected = _selectedMember?.id == m.id;

    return InkWell(
      onTap: () => setState(() => _selectedMember = isSelected ? null : m),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: AdminSizes.tableRowHeight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: isSelected
              ? AdminColors.accent.withValues(alpha: 0.07)
              : even
                  ? Colors.white
                  : const Color(0xFFFAFCFB),
          border: isSelected
              ? Border.all(color: AdminColors.accent.withValues(alpha: 0.3))
              : const Border(bottom: BorderSide(color: AdminColors.divider)),
        ),
        child: Row(
          children: [
            // Avatar
            SizedBox(
              width: 40,
              child: CircleAvatar(
                radius: 15,
                backgroundColor: AdminColors.accent.withValues(alpha: 0.12),
                child: Text(
                  m.name.substring(0, 1),
                  style: const TextStyle(color: AdminColors.accent, fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            // Name
            Expanded(
              flex: 3,
              child: Text(m.name, style: AdminTextStyles.tableCell.copyWith(fontWeight: FontWeight.w600)),
            ),
            // Phone
            Expanded(flex: 4, child: Text(m.phone, style: AdminTextStyles.tableCell)),
            // Nickname
            Expanded(flex: 3, child: Text(m.nickname, style: AdminTextStyles.tableCell.copyWith(color: AdminColors.textSecond))),
            // Gender — 읽기 쉬운 칩
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _GenderChip(gender: m.gender),
              ),
            ),
            // Join Date
            Expanded(flex: 3, child: Text(m.joinDate, style: AdminTextStyles.tableCell.copyWith(color: AdminColors.textSecond))),
            // Club Count
            Expanded(
              flex: 2,
              child: Text(
                '${m.clubCount}개',
                style: AdminTextStyles.tableCell.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            // Status — 도트 + 라벨
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _StatusChip(label: m.statusLabel, color: m.statusColor),
              ),
            ),
            // Actions
            SizedBox(
              width: 100,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AdminActionButton(
                    label: '상세',
                    color: AdminColors.statusInfo,
                    onTap: () => setState(() => _selectedMember = isSelected ? null : m),
                    icon: Icons.visibility_outlined,
                  ),
                  const SizedBox(width: 5),
                  AdminActionButton(
                    label: m.status == 'blocked' ? '해제' : '차단',
                    color: m.status == 'blocked' ? AdminColors.statusOk : AdminColors.statusDanger,
                    onTap: () => _toggleBlock(m),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleBlock(AdminMember m) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          m.status == 'blocked' ? '차단 해제' : '회원 차단',
          style: AdminTextStyles.sectionTitle,
        ),
        content: Text(
          m.status == 'blocked'
              ? '${m.name}님의 차단을 해제하시겠습니까?'
              : '${m.name}님을 차단하시겠습니까?\n차단된 회원은 앱을 사용할 수 없습니다.',
          style: const TextStyle(fontSize: 14, color: AdminColors.textSecond),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: m.status == 'blocked' ? AdminColors.statusOk : AdminColors.statusDanger,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final wasBlocked = m.status == 'blocked';
              await context.read<AdminController>().toggleMemberBlock(m);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(wasBlocked ? '${m.name}님 차단이 해제되었습니다.' : '${m.name}님이 차단되었습니다.'),
                  backgroundColor: wasBlocked ? AdminColors.statusOk : AdminColors.statusDanger,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: Text(m.status == 'blocked' ? '해제' : '차단', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── Detail Panel
  Widget _buildDetailPanel(AdminMember m) {
    return Container(
      margin: const EdgeInsets.only(right: 24, top: 24, bottom: 24),
      decoration: BoxDecoration(
        color: AdminColors.cardBg,
        borderRadius: BorderRadius.circular(AdminSizes.cardRadius),
        border: Border.all(color: AdminColors.cardBorder),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12)],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AdminColors.statGreen1, AdminColors.statGreen2],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(AdminSizes.cardRadius)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  child: Text(m.name.substring(0, 1),
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m.name, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                      Text(m.nickname, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _selectedMember = null),
                  icon: const Icon(Icons.close, color: Colors.white, size: 20),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),

          // Info Fields
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _detailField('회원 ID',  m.id,       Icons.badge_outlined),
                  _detailField('연락처',   m.phone,    Icons.phone_outlined),
                  _detailField('성별',     m.gender,   Icons.person_outline),
                  _detailField('가입일',   m.joinDate, Icons.calendar_today_outlined),
                  _detailField('마지막 접속', m.lastLogin ?? '-', Icons.access_time_outlined),
                  _detailField('소속 모임', '${m.clubCount}개', Icons.golf_course_outlined),
                  const SizedBox(height: 8),
                  // Status
                  Row(
                    children: [
                      const Expanded(
                        child: Text('계정 상태', style: TextStyle(color: AdminColors.textSecond, fontSize: 12)),
                      ),
                      AdminBadge(label: m.statusLabel, color: m.statusColor),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: AdminColors.divider),
                  const SizedBox(height: 12),

                  // Action Buttons
                  const Text('관리 액션', style: AdminTextStyles.sectionTitle),
                  const SizedBox(height: 12),
                  _detailActionBtn(
                    icon: m.status == 'blocked' ? Icons.lock_open_rounded : Icons.block_rounded,
                    label: m.status == 'blocked' ? '차단 해제' : '계정 차단',
                    color: m.status == 'blocked' ? AdminColors.statusOk : AdminColors.statusDanger,
                    onTap: () => _toggleBlock(m),
                  ),
                  const SizedBox(height: 8),
                  _detailActionBtn(
                    icon: Icons.send_rounded,
                    label: '알림 발송',
                    color: AdminColors.statusInfo,
                    onTap: () {},
                  ),
                  const SizedBox(height: 8),
                  _detailActionBtn(
                    icon: Icons.history_rounded,
                    label: '활동 내역 보기',
                    color: AdminColors.textSecond,
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailField(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 15, color: AdminColors.textHint),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: Text(label, style: const TextStyle(fontSize: 12, color: AdminColors.textSecond)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AdminColors.textPrimary)),
          ),
        ],
      ),
    );
  }

  Widget _detailActionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }
}

class _GenderChip extends StatelessWidget {
  final String gender;
  const _GenderChip({required this.gender});

  @override
  Widget build(BuildContext context) {
    final isMale = gender == '남';
    final color = isMale ? AdminColors.statusInfo : const Color(0xFFC026D3);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isMale ? Icons.male_rounded : Icons.female_rounded,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            isMale ? '남성' : '여성',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
