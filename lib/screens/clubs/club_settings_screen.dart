import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../providers/club_provider.dart';
import '../../theme/app_theme.dart';

/// 모임 정보 수정 (관리자 전용)
class ClubSettingsScreen extends StatefulWidget {
  const ClubSettingsScreen({super.key});

  @override
  State<ClubSettingsScreen> createState() => _ClubSettingsScreenState();
}

class _ClubSettingsScreenState extends State<ClubSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _teamCountCtrl;
  String? _imageUrl;
  Uint8List? _localImageBytes;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final club = context.read<ClubProvider>().selectedClub;
    _nameCtrl = TextEditingController(text: club.name);
    _descCtrl = TextEditingController(text: club.description);
    _teamCountCtrl = TextEditingController(text: '${club.teamCount}');
    _imageUrl = club.imageUrl;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _teamCountCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        imageQuality: 85,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      setState(() {
        _localImageBytes = bytes;
        // 로컬/웹 모두 저장 가능한 data URI로 보관
        _imageUrl = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미지를 불러오지 못했습니다')),
      );
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameCtrl.text.trim();
    final description = _descCtrl.text.trim();
    final teamCount = int.tryParse(_teamCountCtrl.text) ?? 0;
    if (name.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('모임 이름은 2자 이상 입력해주세요')),
      );
      return;
    }
    if (description.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('모임 소개는 10자 이상 입력해주세요')),
      );
      return;
    }
    if (teamCount < 1 || teamCount > 30) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('팀 수는 1~30 사이로 입력해주세요')),
      );
      return;
    }

    final provider = context.read<ClubProvider>();
    if (!provider.canEditClubInfo) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('관리자만 모임 정보를 수정할 수 있습니다.')),
      );
      return;
    }

    setState(() => _saving = true);
    provider.updateClubInfo(
      clubId: provider.selectedClub.id,
      name: name,
      description: description,
      imageUrl: _imageUrl,
      teamCount: teamCount,
    );
    if (!mounted) return;
    setState(() => _saving = false);

    // 저장 후 설정 화면을 닫고, 설정 버튼을 누르기 전(모임 방)으로 복귀
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (nav.canPop()) {
      nav.pop();
    }
    messenger?.showSnackBar(
      const SnackBar(content: Text('모임 정보가 저장되었습니다')),
    );
  }

  Widget _buildImagePreview() {
    Widget child;
    if (_localImageBytes != null) {
      child = Image.memory(
        _localImageBytes!,
        fit: BoxFit.cover,
        width: 100,
        height: 100,
      );
    } else if (_imageUrl != null && _imageUrl!.isNotEmpty) {
      final url = _imageUrl!;
      if (url.startsWith('data:image')) {
        try {
          final b64 = url.split(',').last;
          child = Image.memory(
            base64Decode(b64),
            fit: BoxFit.cover,
            width: 100,
            height: 100,
          );
        } catch (_) {
          child = const Icon(Icons.broken_image_outlined);
        }
      } else {
        child = Image.network(
          url,
          fit: BoxFit.cover,
          width: 100,
          height: 100,
          errorBuilder: (_, __, ___) =>
              const Icon(Icons.broken_image_outlined),
        );
      }
    } else {
      child = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_photo_alternate_outlined,
              size: 32, color: AppColors.primary.withValues(alpha: 0.7)),
          const SizedBox(height: 4),
          Text('모임 이미지',
              style: TextStyle(
                  fontSize: 11,
                  color: AppColors.primary.withValues(alpha: 0.7))),
        ],
      );
    }

    return Center(
      child: GestureDetector(
        onTap: _pickImage,
        child: Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('모임 설정',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 17)),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
          children: [
            _buildImagePreview(),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                '탭하여 대표 이미지 변경',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 24),
            const Text('모임 이름',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameCtrl,
              decoration: _inputDeco(hint: '모임 이름'),
              validator: (v) {
                if ((v ?? '').trim().length < 2) return '2자 이상 입력해주세요';
                return null;
              },
            ),
            const SizedBox(height: 20),
            const Text('모임 소개',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descCtrl,
              maxLines: 4,
              minLines: 3,
              decoration: _inputDeco(hint: '모임의 특징·분위기를 알려주세요'),
              validator: (v) {
                if ((v ?? '').trim().length < 10) return '10자 이상 입력해주세요';
                return null;
              },
            ),
            const SizedBox(height: 20),
            const Text('팀 수',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            const Text(
              '일정 등록 시 기본 팀 수로 반영됩니다. 조편성 때도 수정할 수 있어요.',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            _buildTeamCountRow(),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('저장하기',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTeamCountRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          const Icon(Icons.people_outline,
              size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          const Text('팀 수',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
          const Spacer(),
          _CountBtn(
            icon: Icons.remove,
            onTap: () {
              final v = int.tryParse(_teamCountCtrl.text) ?? 4;
              if (v > 1) setState(() => _teamCountCtrl.text = '${v - 1}');
            },
          ),
          SizedBox(
            width: 50,
            child: TextFormField(
              controller: _teamCountCtrl,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(2),
              ],
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(border: InputBorder.none),
              validator: (v) {
                final n = int.tryParse(v ?? '');
                if (n == null || n < 1 || n > 30) return '1~30';
                return null;
              },
            ),
          ),
          _CountBtn(
            icon: Icons.add,
            onTap: () {
              final v = int.tryParse(_teamCountCtrl.text) ?? 4;
              if (v < 30) setState(() => _teamCountCtrl.text = '${v + 1}');
            },
          ),
          const SizedBox(width: 4),
          const Text('팀 (최대 30)',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  InputDecoration _inputDeco({required String hint}) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
      ),
    );
  }
}

class _CountBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CountBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.divider),
        ),
        child: Icon(icon, size: 18, color: AppColors.primary),
      ),
    );
  }
}
