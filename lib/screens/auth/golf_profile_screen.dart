import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/club_provider.dart';
import '../../theme/app_theme.dart';

/// 휴대폰 인증 직후 — 생년월일(양/음)·핸디캡 수집
///
/// 생년월일은 나이·생일 안내에, 핸디캡은 조편성에 쓰인다.
/// 저장은 `AuthProvider.updateGolfProfile` → Firestore `users/{id}` 로 가고,
/// 이미 가입한 모임 명단에도 함께 반영된다.
class GolfProfileScreen extends StatefulWidget {
  const GolfProfileScreen({super.key});

  @override
  State<GolfProfileScreen> createState() => _GolfProfileScreenState();
}

class _GolfProfileScreenState extends State<GolfProfileScreen> {
  final _handicapCtrl = TextEditingController();

  int? _year;
  int? _month;
  int? _day;
  bool _isLunar = false;
  bool _busy = false;
  String? _error;

  static const int _minYear = 1930;

  late final int _maxYear = DateTime.now().year - 10;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().currentUser;
    final birth = user?.birthDate;
    if (birth != null) {
      _year = birth.year;
      _month = birth.month;
      _day = birth.day;
      _isLunar = user?.birthIsLunar ?? false;
    }
    // 정수 핸디만 쓴다. 예전 소수점 값이 남아 있으면 반올림해서 보여 준다.
    final handicap = user?.handicap;
    if (handicap != null) _handicapCtrl.text = handicap.round().toString();
  }

  @override
  void dispose() {
    _handicapCtrl.dispose();
    super.dispose();
  }

  /// 선택한 연·월에 존재하는 일수 (윤년 포함)
  int get _daysInSelectedMonth {
    final y = _year;
    final m = _month;
    if (y == null || m == null) return 31;
    return DateTime(y, m + 1, 0).day;
  }

  DateTime? get _birthDate {
    final y = _year;
    final m = _month;
    final d = _day;
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m, d);
  }

  Future<void> _save() async {
    final birth = _birthDate;
    if (birth == null) {
      setState(() => _error = '생년월일을 모두 선택해 주세요');
      return;
    }

    final raw = _handicapCtrl.text.trim();
    double? handicap;
    if (raw.isNotEmpty) {
      final n = int.tryParse(raw);
      if (n == null || n < 0 || n > 54) {
        setState(() => _error = '핸디캡은 0~54 사이 정수로 입력해 주세요');
        return;
      }
      handicap = n.toDouble();
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final auth = context.read<AuthProvider>();
      final saved = await auth.updateGolfProfile(
        birthDate: birth,
        birthIsLunar: _isLunar,
        handicap: handicap,
      );
      if (!mounted) return;
      if (saved == null) {
        setState(() {
          _busy = false;
          _error = '저장에 실패했습니다. 다시 시도해 주세요.';
        });
        return;
      }
      try {
        context.read<ClubProvider>().syncAuthGolfProfile(
              birthDate: birth,
              handicap: handicap,
            );
      } catch (_) {}
      await auth.markGolfProfileAsked();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/main', (_) => false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '저장 중 오류가 발생했습니다.';
      });
    }
  }

  Future<void> _skip() async {
    // '나중에'도 물어본 걸로 친다. 켤 때마다 다시 뜨면 안 된다.
    // 이후에는 마이페이지에서 입력·수정한다.
    await context.read<AuthProvider>().markGolfProfileAsked();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/main', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          '골프 프로필',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '인증이 완료되었습니다',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '마지막으로 생년월일과 핸디캡만 알려 주세요.\n'
                '나이·생일 안내와 조편성에 사용됩니다.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 28),
              const _FieldLabel('생년월일'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: _Dropdown<int>(
                      hint: '년',
                      value: _year,
                      items: [
                        for (var y = _maxYear; y >= _minYear; y--)
                          DropdownMenuItem(value: y, child: Text('$y년')),
                      ],
                      onChanged: _busy
                          ? null
                          : (v) => setState(() {
                                _year = v;
                                _clampDay();
                              }),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: _Dropdown<int>(
                      hint: '월',
                      value: _month,
                      items: [
                        for (var m = 1; m <= 12; m++)
                          DropdownMenuItem(value: m, child: Text('$m월')),
                      ],
                      onChanged: _busy
                          ? null
                          : (v) => setState(() {
                                _month = v;
                                _clampDay();
                              }),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: _Dropdown<int>(
                      hint: '일',
                      value: _day,
                      items: [
                        for (var d = 1; d <= _daysInSelectedMonth; d++)
                          DropdownMenuItem(value: d, child: Text('$d일')),
                      ],
                      onChanged:
                          _busy ? null : (v) => setState(() => _day = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _ToggleChip(
                    label: '양력',
                    selected: !_isLunar,
                    onTap: _busy ? null : () => setState(() => _isLunar = false),
                  ),
                  const SizedBox(width: 8),
                  _ToggleChip(
                    label: '음력',
                    selected: _isLunar,
                    onTap: _busy ? null : () => setState(() => _isLunar = true),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const _FieldLabel('핸디캡', required: false),
              const SizedBox(height: 8),
              TextField(
                controller: _handicapCtrl,
                enabled: !_busy,
                keyboardType: TextInputType.number,
                // 소수점 핸디는 안 쓴다 — 마이페이지 편집과 같은 규칙.
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(2),
                ],
                decoration: InputDecoration(
                  hintText: '예: 18 (모르면 비워 두세요)',
                  prefixIcon: const Icon(Icons.sports_golf_rounded),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(
                    color: AppColors.danger,
                    fontSize: 13,
                  ),
                ),
              ],
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _busy ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          '시작하기',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: _busy ? null : _skip,
                  child: const Text(
                    '나중에 입력하기',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              const Center(
                child: Text(
                  '마이페이지에서 언제든 바꿀 수 있어요.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 2월 31일처럼 없는 날짜가 남지 않게 보정
  void _clampDay() {
    final d = _day;
    if (d != null && d > _daysInSelectedMonth) {
      _day = _daysInSelectedMonth;
    }
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  final bool required;
  const _FieldLabel(this.label, {this.required = true});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          required ? '*' : '(선택)',
          style: TextStyle(
            fontSize: required ? 13 : 11,
            fontWeight: FontWeight.w600,
            color: required ? AppColors.danger : AppColors.textTertiary,
          ),
        ),
      ],
    );
  }
}

class _Dropdown<T> extends StatelessWidget {
  final String hint;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;

  const _Dropdown({
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      items: items,
      onChanged: onChanged,
      isExpanded: true,
      hint: Text(hint, style: const TextStyle(fontSize: 14)),
      style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const _ToggleChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.divider,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
