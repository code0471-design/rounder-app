import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/score_ocr_service.dart';
import '../../theme/app_theme.dart';

// 웹 전용 import (조건부)
import 'score_ocr_screen_web.dart'
    if (dart.library.io) 'score_ocr_screen_stub.dart' as platform;

// ════════════════════════════════════════════════════════════
//  ScoreOcrScreen — 스코어카드 사진 → GPT-4o OCR → 확인/수정
//  웹: HTML input[file] 사용 / 앱: image_picker 사용
// ════════════════════════════════════════════════════════════
class ScoreOcrScreen extends StatefulWidget {
  final List<String> memberNames;
  const ScoreOcrScreen({super.key, required this.memberNames});

  @override
  State<ScoreOcrScreen> createState() => _ScoreOcrScreenState();
}

class _ScoreOcrScreenState extends State<ScoreOcrScreen> {
  Uint8List? _imageBytes;
  String _imageMime = 'image/jpeg';
  bool _isAnalyzing = false;
  ScoreOcrResult? _ocrResult;
  String? _errorMessage;

  final List<TextEditingController> _nameCtrl = [];
  final List<TextEditingController> _scoreCtrl = [];

  @override
  void dispose() {
    for (final c in _nameCtrl) { c.dispose(); }
    for (final c in _scoreCtrl) { c.dispose(); }
    super.dispose();
  }

  // ── 이미지 선택 (플랫폼 통합) ──────────────────────────
  Future<void> _pickImage({bool fromCamera = false}) async {
    try {
      final result = await platform.pickImageBytes(fromCamera: fromCamera);
      if (result == null) return;

      setState(() {
        _imageBytes = result.bytes;
        _imageMime = result.mimeType;
        _ocrResult = null;
        _errorMessage = null;
        _nameCtrl.clear();
        _scoreCtrl.clear();
      });

      await _analyze();
    } catch (e) {
      setState(() => _errorMessage = '이미지를 불러올 수 없습니다: $e');
    }
  }

  // ── GPT-4o 분석 ─────────────────────────────────────────
  Future<void> _analyze() async {
    if (_imageBytes == null) return;

    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
    });

    final result = await ScoreOcrService.analyzeScorecardBytes(
      _imageBytes!,
      mimeType: _imageMime,
    );

    // 컨트롤러 초기화
    for (final c in _nameCtrl) { c.dispose(); }
    for (final c in _scoreCtrl) { c.dispose(); }
    _nameCtrl.clear();
    _scoreCtrl.clear();

    if (result.success) {
      for (final p in result.players) {
        _nameCtrl.add(TextEditingController(text: p.name));
        _scoreCtrl.add(
            TextEditingController(text: p.totalScore?.toString() ?? ''));
      }
    }

    setState(() {
      _isAnalyzing = false;
      _ocrResult = result;
      if (!result.success) _errorMessage = result.errorMessage;
    });
  }

  // ── 확인 → 상위 화면에 결과 전달 ────────────────────────
  void _confirm() {
    if (_ocrResult == null || !_ocrResult!.success) return;
    final Map<String, int> scores = {};
    for (int i = 0; i < _nameCtrl.length; i++) {
      final name = _nameCtrl[i].text.trim();
      final score = int.tryParse(_scoreCtrl[i].text.trim());
      if (name.isNotEmpty && score != null) scores[name] = score;
    }
    if (scores.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('입력된 스코어가 없습니다.')));
      return;
    }
    Navigator.pop(context, scores);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('스코어카드 자동 인식',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context, null),
        ),
        actions: [
          if (_ocrResult != null && _ocrResult!.success)
            TextButton(
              onPressed: _confirm,
              child: const Text('적용',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isAnalyzing) return _buildLoadingView();
    if (_ocrResult != null && _ocrResult!.success) return _buildResultView();
    return _buildPickerView();
  }

  // ── 로딩 ────────────────────────────────────────────────
  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const CircularProgressIndicator(
                color: AppColors.primary, strokeWidth: 3),
          ),
          const SizedBox(height: 24),
          const Text('GPT-4o가 스코어카드를 분석 중...',
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600,
                  color: Color(0xFF1E1B4B))),
          const SizedBox(height: 8),
          // 미리보기
          if (_imageBytes != null) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.memory(
                _imageBytes!,
                height: 140, width: 200,
                fit: BoxFit.cover,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text('잠시만 기다려주세요 (5~15초)',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  // ── 초기 선택 화면 ───────────────────────────────────────
  Widget _buildPickerView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          // ── 메인 안내 배너 ──────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                AppColors.primary.withValues(alpha: 0.08),
                AppColors.primary.withValues(alpha: 0.03),
              ]),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: Column(
              children: [
                const Text('🤖', style: TextStyle(fontSize: 40)),
                const SizedBox(height: 10),
                const Text(
                  'AI 스코어 자동 인식',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold,
                      color: Color(0xFF1E1B4B)),
                ),
                const SizedBox(height: 4),
                Text(
                  '스마트스코어 화면을 사진 찍으면\nGPT-4o가 이름과 타수를 자동으로 읽어줍니다',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── 핵심 촬영 안내 (가장 중요!) ──────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.screen_rotation, color: Colors.red, size: 16),
                    SizedBox(width: 6),
                    Text('📐 촬영 방향이 핵심입니다!',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold,
                            color: Colors.red)),
                  ],
                ),
                const SizedBox(height: 10),
                // 비교 카드
                Row(
                  children: [
                    // 잘못된 예
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: Colors.red.withValues(alpha: 0.3)),
                        ),
                        child: const Column(
                          children: [
                            Text('❌', style: TextStyle(fontSize: 22)),
                            SizedBox(height: 4),
                            Text('폰 세로 + 태블릿 가로',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 11, fontWeight: FontWeight.w600,
                                    color: Colors.red)),
                            SizedBox(height: 2),
                            Text('이름이 90도 눕혀서\n오인식 발생',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 10, color: Colors.red)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 올바른 예
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: Colors.green.withValues(alpha: 0.3)),
                        ),
                        child: const Column(
                          children: [
                            Text('✅', style: TextStyle(fontSize: 22)),
                            SizedBox(height: 4),
                            Text('폰 가로 + 태블릿 가로',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 11, fontWeight: FontWeight.w600,
                                    color: Colors.green)),
                            SizedBox(height: 2),
                            Text('방향 맞추면\n정확하게 인식',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 10, color: Colors.green)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── 단계별 가이드 ─────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('이렇게 하면 가장 정확해요',
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700)),
                const SizedBox(height: 10),
                _StepGuide(step: '1', text: '스마트스코어 앱 → 라운드 종료 후 결과 화면'),
                _StepGuide(step: '2', text: '폰을 가로로 돌려서 태블릿과 같은 방향으로'),
                _StepGuide(step: '3', text: '이름과 합계 타수가 모두 보이도록 촬영'),
                _StepGuide(step: '✓', text: '또는: 결과 화면 스크린샷을 갤러리에서 선택', highlight: true),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 선택된 이미지 미리보기
          if (_imageBytes != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                _imageBytes!,
                height: 200, width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 16),
          ],

          // 에러 메시지
          if (_errorMessage != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(_errorMessage!,
                        style: const TextStyle(
                            fontSize: 13, color: Colors.red)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // 버튼들 — 웹이면 갤러리만, 앱이면 카메라+갤러리
          if (kIsWeb)
            // 웹: 파일 선택 버튼 하나
            SizedBox(
              width: double.infinity,
              child: _PickerButton(
                icon: Icons.photo_library,
                label: '사진 선택하기',
                subtitle: '스코어카드 이미지 파일을 선택하세요',
                onTap: () => _pickImage(fromCamera: false),
                primary: true,
              ),
            )
          else
            // 앱: 카메라 + 갤러리
            Row(
              children: [
                Expanded(
                  child: _PickerButton(
                    icon: Icons.camera_alt,
                    label: '카메라 촬영',
                    onTap: () => _pickImage(fromCamera: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PickerButton(
                    icon: Icons.photo_library,
                    label: '갤러리 선택',
                    onTap: () => _pickImage(fromCamera: false),
                  ),
                ),
              ],
            ),

          const SizedBox(height: 24),

          // 인식 후 수정 가능 안내
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.edit_note, size: 16, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '인식 후 틀린 부분은 직접 수정할 수 있어요',
                    style: TextStyle(
                        fontSize: 12, color: Colors.blue.shade700),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── OCR 결과 확인 화면 ───────────────────────────────────
  Widget _buildResultView() {
    final players = _ocrResult!.players;
    final uncertainCount = players.where((p) => p.uncertain).length;

    return Column(
      children: [
        // 상단 요약
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              if (_imageBytes != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    _imageBytes!,
                    width: 80, height: 60,
                    fit: BoxFit.cover,
                  ),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.check_circle,
                            color: AppColors.success, size: 16),
                        const SizedBox(width: 6),
                        Text('${players.length}명 인식 완료',
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.bold,
                                color: Color(0xFF1E1B4B))),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (uncertainCount > 0)
                      Text('⚠️ $uncertainCount명 불확실 — 확인 필요',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange.shade700))
                    else
                      Text('정확하게 인식했습니다 ✓',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500)),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: () => setState(() {
                  _ocrResult = null;
                  _imageBytes = null;
                }),
                icon: const Icon(Icons.refresh, size: 14),
                label: const Text('다시', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // 안내
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: const Color(0xFFFFF8E1),
          child: Row(
            children: [
              const Icon(Icons.edit_note, size: 16, color: Colors.amber),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '이름이나 타수가 틀렸으면 직접 수정 후 "적용"을 누르세요',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.amber.shade800,
                      fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),

        // 플레이어 카드 목록
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: players.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _OcrResultCard(
              index: i,
              player: players[i],
              nameCtrl: _nameCtrl[i],
              scoreCtrl: _scoreCtrl[i],
            ),
          ),
        ),

        // 하단 적용 버튼
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, -2)),
            ],
          ),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _confirm,
              icon: const Icon(Icons.check, size: 18),
              label: const Text('스코어 적용하기',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── 결과 카드 ────────────────────────────────────────────────
class _OcrResultCard extends StatelessWidget {
  final int index;
  final OcrPlayerScore player;
  final TextEditingController nameCtrl;
  final TextEditingController scoreCtrl;

  const _OcrResultCard({
    required this.index,
    required this.player,
    required this.nameCtrl,
    required this.scoreCtrl,
  });

  @override
  Widget build(BuildContext context) {
    final isUncertain = player.uncertain || player.totalScore == null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isUncertain
              ? Colors.orange.withValues(alpha: 0.5)
              : AppColors.divider,
          width: isUncertain ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          // 번호 / 경고 아이콘
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: isUncertain
                  ? Colors.orange.withValues(alpha: 0.1)
                  : AppColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: isUncertain
                  ? const Icon(Icons.warning_amber_rounded,
                      color: Colors.orange, size: 18)
                  : Text('${index + 1}',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.bold,
                          color: AppColors.primary)),
            ),
          ),
          const SizedBox(width: 12),

          // 이름
          Expanded(
            flex: 3,
            child: _inputField(
              label: '이름',
              ctrl: nameCtrl,
              isUncertain: false,
            ),
          ),
          const SizedBox(width: 10),

          // 타수
          SizedBox(
            width: 85,
            child: _inputField(
              label: '총 타수',
              ctrl: scoreCtrl,
              isUncertain: isUncertain,
              isNumber: true,
              suffix: '타',
              hint: '?',
            ),
          ),
        ],
      ),
    );
  }

  Widget _inputField({
    required String label,
    required TextEditingController ctrl,
    required bool isUncertain,
    bool isNumber = false,
    String? suffix,
    String? hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          keyboardType:
              isNumber ? TextInputType.number : TextInputType.text,
          inputFormatters:
              isNumber ? [FilteringTextInputFormatter.digitsOnly] : [],
          textAlign: isNumber ? TextAlign.center : TextAlign.start,
          style: TextStyle(
            fontSize: isNumber ? 16 : 14,
            fontWeight: FontWeight.w600,
            color: isUncertain
                ? Colors.orange.shade700
                : const Color(0xFF1E1B4B),
          ),
          decoration: InputDecoration(
            isDense: true,
            hintText: hint,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 8),
            filled: true,
            fillColor: isUncertain
                ? Colors.orange.withValues(alpha: 0.07)
                : AppColors.background,
            suffixText: suffix,
            suffixStyle: TextStyle(
                fontSize: 11, color: Colors.grey.shade500),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                    color: isUncertain
                        ? Colors.orange.withValues(alpha: 0.4)
                        : Colors.grey.shade200)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                    color: isUncertain
                        ? Colors.orange.withValues(alpha: 0.4)
                        : Colors.grey.shade200)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                    color: AppColors.primary, width: 1.5)),
          ),
        ),
      ],
    );
  }
}

// ── 이미지 선택 버튼 ────────────────────────────────────────
class _PickerButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final bool primary;

  const _PickerButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
            vertical: subtitle != null ? 20 : 20),
        decoration: BoxDecoration(
          color: primary
              ? AppColors.primary.withValues(alpha: 0.05)
              : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: primary
                  ? AppColors.primary.withValues(alpha: 0.3)
                  : AppColors.divider),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 36,
                color: primary ? AppColors.primary : AppColors.primary),
            const SizedBox(height: 8),
            Text(label,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600,
                    color: Color(0xFF1E1B4B))),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey.shade500)),
            ],
          ],
        ),
      ),
    );
  }
}

// ── 단계별 가이드 위젯 ───────────────────────────────────────
class _StepGuide extends StatelessWidget {
  final String step;
  final String text;
  final bool highlight;

  const _StepGuide({
    required this.step,
    required this.text,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20, height: 20,
            decoration: BoxDecoration(
              color: highlight
                  ? AppColors.success.withValues(alpha: 0.15)
                  : AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(step,
                  style: TextStyle(
                      fontSize: 9, fontWeight: FontWeight.bold,
                      color: highlight ? AppColors.success : AppColors.primary)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize: 12,
                    color: highlight
                        ? AppColors.success
                        : Colors.grey.shade700,
                    fontWeight: highlight
                        ? FontWeight.w600 : FontWeight.normal)),
          ),
        ],
      ),
    );
  }
}
