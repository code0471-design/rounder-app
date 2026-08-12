import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/club_model.dart';
import '../../models/member_role.dart';
import '../../providers/club_provider.dart';
import '../../theme/app_theme.dart';

/// 마이페이지 → 직책 변경
/// 1) 내 모임 선택  2) 내 직책 수정
class MyRoleChangeScreen extends StatefulWidget {
  const MyRoleChangeScreen({super.key});

  @override
  State<MyRoleChangeScreen> createState() => _MyRoleChangeScreenState();
}

class _MyRoleChangeScreenState extends State<MyRoleChangeScreen> {
  Club? _selectedClub;
  final Set<String> _roles = {ClubMemberRole.regular};
  bool _saving = false;

  String get _roleEncoded => ClubMemberRole.encodeRoles(_roles);

  void _pickClub(Club club, ClubProvider provider) {
    provider.selectClubById(club.id);
    final me = provider.currentMember;
    final seed = me?.role ?? club.myRole;
    setState(() {
      _selectedClub = club;
      _roles
        ..clear()
        ..addAll(ClubMemberRole.splitRoles(seed));
      if (_roles.isEmpty) _roles.add(ClubMemberRole.regular);
    });
  }

  void _toggleRole(String role) {
    setState(() {
      if (role == ClubMemberRole.regular) {
        _roles
          ..clear()
          ..add(ClubMemberRole.regular);
        return;
      }
      _roles.remove(ClubMemberRole.regular);
      _roles.remove(ClubMemberRole.legacyRegular);
      if (_roles.contains(role)) {
        _roles.remove(role);
        if (_roles.isEmpty) _roles.add(ClubMemberRole.regular);
      } else {
        _roles.add(role);
      }
    });
  }

  Future<void> _save(ClubProvider provider) async {
    final club = _selectedClub;
    if (club == null || _saving) return;

    setState(() => _saving = true);
    final encoded = _roleEncoded;
    var ok = false;
    try {
      ok = provider.setMyRoleForClub(club.id, encoded);
    } catch (e, st) {
      debugPrint('[MyRoleChange] save failed: $e\n$st');
      ok = false;
    }

    if (!mounted) return;
    setState(() {
      _saving = false;
      if (ok) _selectedClub = null; // 직책변경 — 모임 선택으로 복귀
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? '${club.name} 직책이 $encoded(으)로 변경되었습니다'
              : '직책 저장에 실패했습니다. 다시 시도해 주세요.',
        ),
        backgroundColor: ok ? AppColors.primary : AppColors.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ClubProvider>(
      builder: (context, provider, _) {
        final clubs = provider.myClubs;
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.primaryDark,
            iconTheme: const IconThemeData(color: Colors.white),
            title: Text(
              _selectedClub == null ? '직책 변경 — 모임 선택' : '직책 변경',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 18),
              onPressed: () {
                if (_selectedClub != null) {
                  setState(() => _selectedClub = null);
                } else {
                  Navigator.pop(context);
                }
              },
            ),
          ),
          body: _selectedClub == null
              ? _buildClubPicker(clubs, provider)
              : _buildRoleEditor(provider),
        );
      },
    );
  }

  Widget _buildClubPicker(List<Club> clubs, ClubProvider provider) {
    if (clubs.isEmpty) {
      return const Center(
        child: Text('참여 중인 모임이 없습니다',
            style: TextStyle(color: AppColors.textSecondary)),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        const Text(
          '직책을 변경할 모임을 선택하세요',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        ...clubs.map((club) {
          final role = ClubMemberRole.encodeRoles(
            ClubMemberRole.splitRoles(club.myRole),
          );
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              title: Text(club.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15)),
              subtitle: Text('현재 직책 · $role',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
              trailing: const Icon(Icons.chevron_right,
                  color: AppColors.textSecondary),
              onTap: () => _pickClub(club, provider),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildRoleEditor(ClubProvider provider) {
    final club = _selectedClub!;
    final options = [
      (ClubMemberRole.president, '회장'),
      (ClubMemberRole.vicePresident, '부회장'),
      (ClubMemberRole.treasurer, '총무'),
      (ClubMemberRole.regular, '일반 회원'),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.groups_outlined, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  club.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          '내 직책 (복수 선택 가능)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '회장·총무처럼 겸직할 수 있고, 일반 회원으로도 내릴 수 있습니다.',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary.withValues(alpha: 0.9),
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((o) {
            final selected = _roles.contains(o.$1) ||
                (o.$1 == ClubMemberRole.regular &&
                    !ClubMemberRole.isOfficer(_roleEncoded));
            return FilterChip(
              label: Text(o.$2),
              selected: selected,
              onSelected: (_) => _toggleRole(o.$1),
              selectedColor: AppColors.primary,
              checkmarkColor: Colors.white,
              labelStyle: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? Colors.white : AppColors.textPrimary,
              ),
              side: BorderSide(
                color: selected ? AppColors.primary : AppColors.divider,
              ),
              backgroundColor: Colors.white,
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        Text(
          ClubMemberRole.isOfficer(_roleEncoded)
              ? '선택: $_roleEncoded'
              : '일반 회원으로 저장됩니다',
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _saving ? null : () => _save(provider),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('직책 저장',
                    style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}
