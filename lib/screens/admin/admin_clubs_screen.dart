// ════════════════════════════════════════════════════════════
//  ROUNDER Admin — Club Management
//  모임 목록 + 블라인드 기능
// ════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import '../../di/app_dependencies.dart';
import '../../features/admin/application/admin_controller.dart';
import '../../models/club_model.dart';
import '../../providers/club_provider.dart';
import 'admin_theme.dart';
import 'admin_models.dart';

class AdminClubsScreen extends StatefulWidget {
  const AdminClubsScreen({super.key});

  @override
  State<AdminClubsScreen> createState() => _AdminClubsScreenState();
}

class _AdminClubsScreenState extends State<AdminClubsScreen> {
  final _searchCtrl = TextEditingController();
  String _statusFilter = 'all';
  String _sortBy = 'createdDate';
  bool _sortAsc = false;
  AdminClub? _selectedClub;

  List<AdminClub> _filtered(List<AdminClub> source) {
    var list = source.where((c) {
      final q = _searchCtrl.text.trim().toLowerCase();
      final matchSearch = q.isEmpty ||
          c.name.toLowerCase().contains(q) ||
          c.host.toLowerCase().contains(q) ||
          c.region.toLowerCase().contains(q);
      final matchStatus = _statusFilter == 'all' ||
          (_statusFilter == 'active'
              ? (c.status == 'active' || c.status == 'pending')
              : c.status == _statusFilter);
      return matchSearch && matchStatus;
    }).toList();

    list.sort((a, b) {
      int cmp;
      switch (_sortBy) {
        case 'name':        cmp = a.name.compareTo(b.name); break;
        case 'memberCount': cmp = a.memberCount.compareTo(b.memberCount); break;
        case 'createdDate':
        default:            cmp = a.createdDate.compareTo(b.createdDate); break;
      }
      return _sortAsc ? cmp : -cmp;
    });
    return list;
  }

  Future<void> _updateClubStatus(AdminClub club, String newStatus) async {
    await context.read<AdminController>().updateClubStatus(club.id, newStatus);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminController>();
    final clubs = admin.clubs;
    if (_selectedClub != null) {
      final updated = clubs.where((c) => c.id == _selectedClub!.id).firstOrNull;
      if (updated != null) _selectedClub = updated;
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _buildMainContent(admin, clubs)),
        if (_selectedClub != null)
          SizedBox(width: 310, child: _buildDetailPanel(admin, _selectedClub!)),
      ],
    );
  }

  Widget _buildMainContent(AdminController admin, List<AdminClub> clubs) {
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
          _buildHeader(clubs),
          const SizedBox(height: 20),

          // Status Summary Tabs
          _buildStatusTabs(clubs),
          const SizedBox(height: 16),

          // Search & Sort
          AdminCard(
            padding: const EdgeInsets.all(16),
            child: _buildFilters(),
          ),
          const SizedBox(height: 16),

          // Club Grid / Table
          _buildClubCards(clubs),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildHeader(List<AdminClub> clubs) {
    return Row(
      children: [
        const Text('모임 관리', style: AdminTextStyles.pageTitle),
        const Spacer(),
        Container(
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
              Text('내보내기', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusTabs(List<AdminClub> clubs) {
    final statuses = [
      ('all',     '전체',    clubs.length),
      ('active',  '활성',    clubs.where((c) => c.status == 'active' || c.status == 'pending').length),
      ('ended',   '종료',    clubs.where((c) => c.status == 'ended').length),
      ('blinded', '블라인드', clubs.where((c) => c.status == 'blinded').length),
    ];

    return Row(
      children: statuses.map((s) {
        final (key, label, count) = s;
        final isSelected = _statusFilter == key;
        Color accentColor;
        switch (key) {
          case 'pending': accentColor = AdminColors.statusWarn; break;
          case 'active':  accentColor = AdminColors.statusOk; break;
          case 'ended':   accentColor = AdminColors.textHint; break;
          case 'blinded': accentColor = AdminColors.statusDanger; break;
          default:        accentColor = AdminColors.accent; break;
        }

        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: InkWell(
            onTap: () => setState(() => _statusFilter = key),
            borderRadius: BorderRadius.circular(8),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: isSelected ? accentColor : AdminColors.cardBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? accentColor : AdminColors.cardBorder,
                ),
                boxShadow: isSelected
                    ? [BoxShadow(color: accentColor.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3))]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : AdminColors.textSecond,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white.withValues(alpha: 0.25) : AdminColors.contentBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? Colors.white : AdminColors.textHint,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFilters() {
    return Wrap(
      spacing: 12,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 260,
          height: 38,
          child: TextField(
            controller: _searchCtrl,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: '모임명, 방장, 지역 검색',
              hintStyle: const TextStyle(fontSize: 13, color: AdminColors.textHint),
              prefixIcon: const Icon(Icons.search, size: 18, color: AdminColors.textHint),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AdminColors.cardBorder)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AdminColors.cardBorder)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AdminColors.accent)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
              filled: true, fillColor: AdminColors.contentBg,
            ),
          ),
        ),
        _buildDropdown<String>(
          value: _sortBy,
          items: const [
            DropdownMenuItem(value: 'createdDate',  child: Text('개설일 순')),
            DropdownMenuItem(value: 'name',         child: Text('이름 순')),
            DropdownMenuItem(value: 'memberCount',  child: Text('회원수 순')),
          ],
          onChanged: (v) => setState(() => _sortBy = v!),
          width: 120,
        ),
        InkWell(
          onTap: () => setState(() => _sortAsc = !_sortAsc),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 38, height: 38,
            decoration: BoxDecoration(border: Border.all(color: AdminColors.cardBorder), borderRadius: BorderRadius.circular(8), color: AdminColors.contentBg),
            child: Icon(_sortAsc ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, size: 17, color: AdminColors.textSecond),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown<T>({required T value, required List<DropdownMenuItem<T>> items, required ValueChanged<T?> onChanged, double width = 130}) {
    return SizedBox(
      width: width, height: 38,
      child: DropdownButtonFormField<T>(
        value: value, items: items, onChanged: onChanged,
        style: const TextStyle(fontSize: 13, color: AdminColors.textPrimary),
        decoration: InputDecoration(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AdminColors.cardBorder)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AdminColors.cardBorder)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AdminColors.accent)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
          filled: true, fillColor: AdminColors.contentBg,
        ),
        dropdownColor: Colors.white,
        icon: const Icon(Icons.expand_more_rounded, size: 18, color: AdminColors.textSecond),
      ),
    );
  }

  Widget _buildClubCards(List<AdminClub> source) {
    final clubs = _filtered(source);
    if (clubs.isEmpty) {
      return AdminCard(
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.golf_course_outlined, size: 48, color: AdminColors.textHint),
                SizedBox(height: 8),
                Text('검색 결과가 없습니다', style: TextStyle(color: AdminColors.textHint, fontSize: 14)),
              ],
            ),
          ),
        ),
      );
    }

    return AdminCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _buildTableHeader(),
          ...clubs.asMap().entries.map((e) => _buildClubRow(e.value, e.key.isEven)),
        ],
      ),
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
          Expanded(flex: 5, child: Text('모임명',   style: AdminTextStyles.tableHeader)),
          Expanded(flex: 3, child: Text('방장',     style: AdminTextStyles.tableHeader)),
          Expanded(flex: 3, child: Text('지역',     style: AdminTextStyles.tableHeader)),
          Expanded(flex: 2, child: Text('회원수',   style: AdminTextStyles.tableHeader)),
          Expanded(flex: 3, child: Text('개설일',   style: AdminTextStyles.tableHeader)),
          Expanded(flex: 2, child: Text('상태',     style: AdminTextStyles.tableHeader)),
          SizedBox(width: 180, child: Text('액션',  style: AdminTextStyles.tableHeader)),
        ],
      ),
    );
  }

  Widget _buildClubRow(AdminClub c, bool even) {
    final isSelected = _selectedClub?.id == c.id;

    return InkWell(
      onTap: () => setState(() => _selectedClub = isSelected ? null : c),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: AdminSizes.tableRowHeight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: isSelected
              ? AdminColors.accent.withValues(alpha: 0.07)
              : even ? Colors.white : const Color(0xFFFAFCFB),
          border: isSelected
              ? Border.all(color: AdminColors.accent.withValues(alpha: 0.3))
              : const Border(bottom: BorderSide(color: AdminColors.divider)),
        ),
        child: Row(
          children: [
            // Name
            Expanded(
              flex: 5,
              child: Row(
                children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: c.statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.golf_course_rounded, size: 16, color: c.statusColor),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(c.name, style: AdminTextStyles.tableCell.copyWith(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
            Expanded(flex: 3, child: Text(c.host, style: AdminTextStyles.tableCell)),
            Expanded(flex: 3, child: Text(c.region, style: AdminTextStyles.tableCell.copyWith(color: AdminColors.textSecond), overflow: TextOverflow.ellipsis)),
            // Member count
            Expanded(
              flex: 2,
              child: Text(
                '${c.memberCount}명',
                style: AdminTextStyles.tableCell.copyWith(
                  color: AdminColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(flex: 3, child: Text(c.createdDate, style: AdminTextStyles.tableCell.copyWith(color: AdminColors.textSecond))),
            Expanded(flex: 2, child: AdminBadge(label: c.statusLabel, color: c.statusColor)),
            // Actions
            SizedBox(
              width: 180,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: _buildRowActions(c),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildRowActions(AdminClub c) {
    final actions = <Widget>[];

    if (c.status == 'active' || c.status == 'pending') {
      actions.addAll([
        AdminActionButton(label: '블라인드', color: AdminColors.statusDanger, onTap: () => _showConfirmDialog(c, 'blinded'), icon: Icons.visibility_off_rounded),
        const SizedBox(width: 5),
      ]);
    } else if (c.status == 'blinded') {
      actions.add(AdminActionButton(label: '복구', color: AdminColors.statusOk, onTap: () => _showConfirmDialog(c, 'active'), icon: Icons.restore_rounded));
      actions.add(const SizedBox(width: 5));
    }

    actions.add(AdminActionButton(label: '상세', color: AdminColors.statusInfo, onTap: () => setState(() => _selectedClub = _selectedClub?.id == c.id ? null : c), icon: Icons.info_outline_rounded));

    return actions;
  }

  void _showConfirmDialog(AdminClub club, String newStatus) {
    final actionLabel = {
      'active':  '활성 복구',
      'ended':   '종료 처리',
      'blinded': '블라인드 처리',
    }[newStatus] ?? newStatus;
    final actionColor = {
      'active':  AdminColors.statusOk,
      'ended':   AdminColors.statusDanger,
      'blinded': AdminColors.statusDanger,
    }[newStatus] ?? AdminColors.accent;

    final reasonCtrl = TextEditingController();
    final needReason = newStatus == 'ended' || newStatus == 'blinded';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('모임 $actionLabel', style: AdminTextStyles.sectionTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '"${club.name}"을 $actionLabel 하시겠습니까?',
              style: const TextStyle(fontSize: 14, color: AdminColors.textSecond),
            ),
            if (needReason) ...[
              const SizedBox(height: 14),
              const Text('처리 사유 (선택)', style: TextStyle(fontSize: 12, color: AdminColors.textSecond)),
              const SizedBox(height: 6),
              TextField(
                controller: reasonCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: '사유를 입력하세요 (방장에게 알림 발송)',
                  hintStyle: const TextStyle(fontSize: 12, color: AdminColors.textHint),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AdminColors.cardBorder)),
                  contentPadding: const EdgeInsets.all(10),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: actionColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              _updateClubStatus(club, newStatus);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('"${club.name}" ${club.statusLabel} 처리 완료'),
                  backgroundColor: actionColor,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: Text(actionLabel, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailPanel(AdminController admin, AdminClub c) {
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
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [c.statusColor.withValues(alpha: 0.8), c.statusColor],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(AdminSizes.cardRadius)),
            ),
            child: Row(
              children: [
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.golf_course_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.name, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
                      Text('방장: ${c.host}', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _selectedClub = null),
                  icon: const Icon(Icons.close, color: Colors.white, size: 20),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _detailField('모임 ID',  c.id,                   Icons.badge_outlined),
                  _detailField('지역',     c.region,               Icons.location_on_outlined),
                  _detailField('개설일',   c.createdDate,          Icons.calendar_today_outlined),
                  _detailField('회원수',   '${c.memberCount}명 (게스트 제외)', Icons.people_outlined),
                  const SizedBox(height: 4),
                  Row(children: [
                    const SizedBox(width: 23),
                    const SizedBox(width: 8),
                    const SizedBox(width: 80, child: Text('상태', style: TextStyle(color: AdminColors.textSecond, fontSize: 12))),
                    AdminBadge(label: c.statusLabel, color: c.statusColor),
                  ]),
                  const SizedBox(height: 20),
                  const Divider(color: AdminColors.divider),
                  const SizedBox(height: 12),
                  const Text('관리 액션', style: AdminTextStyles.sectionTitle),
                  const SizedBox(height: 12),
                  ..._buildDetailActions(c),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildDetailActions(AdminClub c) {
    final actions = <Widget>[];

    if (c.status == 'active' || c.status == 'pending') {
      actions.add(_detailActionBtn(icon: Icons.visibility_off_rounded, label: '블라인드 처리', color: AdminColors.statusDanger, onTap: () => _showConfirmDialog(c, 'blinded')));
    } else if (c.status == 'blinded') {
      actions.add(_detailActionBtn(icon: Icons.restore_rounded, label: '블라인드 해제', color: AdminColors.statusOk, onTap: () => _showConfirmDialog(c, 'active')));
    }

    actions.addAll([
      const SizedBox(height: 8),
      _detailActionBtn(icon: Icons.send_rounded, label: '방장에게 알림 발송', color: AdminColors.statusInfo, onTap: () {}),
      const SizedBox(height: 8),
      _detailActionBtn(
        icon: Icons.list_alt_rounded,
        label: '회원 목록 보기',
        color: AdminColors.textSecond,
        onTap: () => _showClubMembers(c),
      ),
    ]);

    return actions;
  }

  Future<List<Member>> _loadClubMembers(AdminClub club) async {
    final store = AppDependencies.instance.mockDataStore;
    var members = store?.membersOf(club.id) ?? const <Member>[];
    if (members.isEmpty && mounted) {
      members = context.read<ClubProvider>().membersForClub(club.id);
    }
    // Firestore: clubs/{id}/members
    if (members.isEmpty && !AppDependencies.instance.isOfflineMockMode) {
      try {
        final snap = await FirebaseFirestore.instance
            .collection('clubs')
            .doc(club.id)
            .collection('members')
            .get();
        members = snap.docs.map((d) {
          final data = d.data();
          return Member(
            id: d.id,
            name: (data['name'] as String?) ?? '',
            gender: (data['gender'] as String?) ?? '남',
            phone: data['phone'] as String?,
            memberType: (data['member_type'] as String?) ??
                (data['memberType'] as String?) ??
                '정회원',
            role: (data['role'] as String?) ?? '일반',
            status: (data['status'] as String?) ?? '활성',
          );
        }).toList();
      } catch (_) {}
    }
    // 최후: 방장 이름만이라도 표시
    if (members.isEmpty && club.host.isNotEmpty) {
      members = [
        Member(
          id: 'host_${club.id}',
          name: club.host,
          gender: '남',
          memberType: '정회원',
          role: '총무',
          status: '활성',
        ),
      ];
    }
    return members;
  }

  Future<void> _showClubMembers(AdminClub club) async {
    final members = await _loadClubMembers(club);
    if (!mounted) return;

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          '${club.name} 회원',
          style: AdminTextStyles.sectionTitle,
        ),
        content: SizedBox(
          width: 420,
          height: 360,
          child: members.isEmpty
              ? const Center(
                  child: Text(
                    '등록된 회원이 없습니다.',
                    style: TextStyle(color: AdminColors.textHint),
                  ),
                )
              : ListView.separated(
                  itemCount: members.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: AdminColors.divider),
                  itemBuilder: (_, i) {
                    final m = members[i];
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor:
                            AdminColors.accent.withValues(alpha: 0.12),
                        child: Text(
                          m.name.isNotEmpty ? m.name.substring(0, 1) : '?',
                          style: const TextStyle(
                            color: AdminColors.accent,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      title: Text(
                        m.name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AdminColors.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        '${m.role} · ${m.phone ?? '-'}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AdminColors.textHint,
                        ),
                      ),
                      trailing: Text(
                        m.memberType,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AdminColors.textSecond,
                        ),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('닫기'),
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
          SizedBox(width: 80, child: Text(label, style: const TextStyle(fontSize: 12, color: AdminColors.textSecond))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AdminColors.textPrimary))),
        ],
      ),
    );
  }

  Widget _detailActionBtn({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
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
