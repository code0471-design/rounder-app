import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../providers/club_provider.dart';
import '../../utils/past_schedule_import.dart';
import '../../widgets/golf_course_field.dart';

const _kTossInk = Color(0xFF191F28);
const _kTossGray = Color(0xFF6B7684);
const _kTossMuted = Color(0xFF8B95A1);
const _kTossLine = Color(0xFFE5E8EB);

Future<void> openPastScheduleImport(BuildContext context) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(builder: (_) => const PastScheduleImportScreen()),
  );
}

Future<String> pastImportHintKey(String clubId) async {
  return 'past_import_hint_${clubId}_${DateTime.now().year}';
}

/// 일괄 등록을 한 번이라도 마치면 최초 안내를 다시 보지 않는다.
Future<void> markPastImportHintSeen(String clubId) async {
  final prefs = await SharedPreferences.getInstance();
  final key = await pastImportHintKey(clubId);
  await prefs.setBool(key, true);
}

/// 예정/지난 탭 위 안내. 임원만.
/// 일정이 하나도 없으면 다음 라운딩 등록이 먼저다.
class PastScheduleImportBanner extends StatefulWidget {
  final String clubId;
  final VoidCallback onStart;
  final VoidCallback? onAddUpcoming;
  final bool clubHasSchedules;
  final bool isTreasurer;
  const PastScheduleImportBanner({
    super.key,
    required this.clubId,
    required this.onStart,
    this.onAddUpcoming,
    this.clubHasSchedules = true,
    this.isTreasurer = false,
  });

  @override
  State<PastScheduleImportBanner> createState() =>
      _PastScheduleImportBannerState();
}

class _PastScheduleImportBannerState extends State<PastScheduleImportBanner> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await pastImportHintKey(widget.clubId);
    if (!mounted) return;
    setState(() => _visible = prefs.getBool(key) != true);
  }

  Future<void> _dismiss() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await pastImportHintKey(widget.clubId);
    await prefs.setBool(key, true);
    if (mounted) setState(() => _visible = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _kTossLine),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.clubHasSchedules
                  ? '앱이 처음이신가요?'
                  : (widget.isTreasurer ? '총무님 반갑습니다' : '첫 일정을 등록해 주세요'),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: _kTossInk,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.clubHasSchedules
                  ? '올해 이미 지난 일정을 일괄로 등록할 수 있습니다'
                  : '다음 라운딩을 넣으면 회원에게 참석 안내가 갑니다.\n올해 이미 친 라운딩은 한번에 넣을 수 있어요.',
              style: const TextStyle(
                fontSize: 15,
                height: 1.45,
                color: _kTossGray,
              ),
            ),
            const SizedBox(height: 16),
            if (!widget.clubHasSchedules && widget.onAddUpcoming != null) ...[
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: widget.onAddUpcoming,
                  style: FilledButton.styleFrom(
                    backgroundColor: _kTossInk,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    textStyle: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  child: const Text('다음 일정 등록하기'),
                ),
              ),
              const SizedBox(height: 8),
            ],
            SizedBox(
              width: double.infinity,
              height: 52,
              child: widget.clubHasSchedules || widget.onAddUpcoming == null
                  ? FilledButton(
                      onPressed: widget.onStart,
                      style: FilledButton.styleFrom(
                        backgroundColor: _kTossInk,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        textStyle: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      child: const Text('지난 일정 등록하기'),
                    )
                  : OutlinedButton(
                      onPressed: widget.onStart,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _kTossInk,
                        side: const BorderSide(color: _kTossLine),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        textStyle: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      child: const Text('지난 일정 등록하기'),
                    ),
            ),
            const SizedBox(height: 4),
            Center(
              child: TextButton(
                onPressed: _dismiss,
                child: const Text(
                  '나중에',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _kTossMuted),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PastScheduleImportScreen extends StatefulWidget {
  const PastScheduleImportScreen({super.key});

  @override
  State<PastScheduleImportScreen> createState() =>
      _PastScheduleImportScreenState();
}

class _PastScheduleImportScreenState extends State<PastScheduleImportScreen> {
  static const _total = 6;
  int _step = 0;
  int _savedCount = 0;
  int _monthHint = DateTime.now().month == 1 ? 1 : DateTime.now().month - 1;

  final _titleCtrl = TextEditingController();
  final _courseCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  DateTime? _date;
  TimeOfDay? _time;
  final Set<String> _attendeeIds = {};
  final Map<String, Set<String>> _awardWinners = {
    '메달리스트': {},
    '니어리스트': {},
    '롱기스트': {},
  };

  @override
  void initState() {
    super.initState();
    _titleCtrl.text = '$_monthHint월 모임';
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _courseCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  void _resetForNext() {
    final fromTitle = PastScheduleImport.monthFromTitle(_titleCtrl.text);
    final base = _date?.month ?? fromTitle ?? _monthHint;
    _monthHint = base == 12 ? 1 : base + 1;
    _titleCtrl.text = '$_monthHint월 모임';
    _courseCtrl.clear();
    _addressCtrl.clear();
    _date = null;
    _time = null;
    _attendeeIds.clear();
    for (final k in _awardWinners.keys) {
      _awardWinners[k] = {};
    }
    setState(() => _step = 1);
  }

  String _teeTimeText() {
    final t = _time;
    if (t == null) return '';
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  Future<bool> _commitCurrent() async {
    final provider = context.read<ClubProvider>();
    const awardMeta = [
      ('메달리스트', '🥇'),
      ('니어리스트', '🎯'),
      ('롱기스트', '🏌️'),
    ];
    final awards = [
      for (final a in awardMeta)
        if ((_awardWinners[a.$1] ?? {}).isNotEmpty)
          PastAwardDraft(
            awardName: a.$1,
            awardIcon: a.$2,
            winnerIds: _awardWinners[a.$1]!.toList(),
          ),
    ];
    final ok = provider.importPastSchedule(
      title: _titleCtrl.text,
      roundDate: _date,
      teeTime: _teeTimeText(),
      courseName: _courseCtrl.text,
      courseAddress: _addressCtrl.text,
      attendeeIds: _attendeeIds.toList(),
      awards: awards,
      monthHint: _monthHint,
    );
    if (!ok) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('일정 이름을 입력해 주세요')),
      );
      setState(() => _step = 1);
      return false;
    }
    await markPastImportHintSeen(provider.selectedClub.id);
    setState(() => _savedCount += 1);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ClubProvider>();
    if (!provider.canCreateSchedule) {
      return const Scaffold(
        body: Center(child: Text('임원만 지난 일정을 일괄 등록할 수 있습니다')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: _kTossInk),
          onPressed: () {
            if (_step <= 0 || _step == 5) {
              Navigator.pop(context);
            } else {
              setState(() => _step -= 1);
            }
          },
        ),
        title: _step == 0 || _step == 5
            ? const SizedBox.shrink()
            : Text(
                '$_step / ${_total - 2}',
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _kTossMuted),
              ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 16),
          child: Column(
            children: [
              Expanded(child: _buildStep(provider)),
              _bottomBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep(ClubProvider provider) {
    switch (_step) {
      case 0:
        return _question(
          title: '올해 이미 라운딩을 하셨나요?',
          body: '날짜·시간·구장이 가물가물해도 됩니다.\n일정 이름만 있으면 지난 일정에 넣고, 기억나는 참석자·시상자는 랭킹과 시상 기록에 반영됩니다.',
        );
      case 1:
        return _question(
          title: '일정 이름을 적어 주세요',
          body: '예: 3월 월례회, 봄맞이 라운딩',
          child: TextField(
            controller: _titleCtrl,
            autofocus: true,
            style: const TextStyle(
                fontSize: 20, fontWeight: FontWeight.w700, color: _kTossInk),
            decoration: const InputDecoration(
              hintText: '3월 월례회',
              hintStyle: TextStyle(color: _kTossMuted, fontWeight: FontWeight.w500),
              border: InputBorder.none,
            ),
          ),
        );
      case 2:
        return _question(
          title: '기억나는 것만 적어 주세요',
          body: '날짜, 시간, 구장 중 아는 것만 입력하면 됩니다. 모르면 건너뛰어도 지난 일정에 들어갑니다.',
          child: SingleChildScrollView(
            child: Column(
              children: [
                _optionalTile(
                  label: '날짜',
                  value: _date == null
                      ? '기억 안 남'
                      : '${_date!.month}월 ${_date!.day}일',
                  onTap: _pickDate,
                ),
                _optionalTile(
                  label: '티오프',
                  value: _time == null ? '기억 안 남' : _teeTimeText(),
                  onTap: _pickTime,
                ),
                const SizedBox(height: 8),
                GolfCourseNameField(
                  courseController: _courseCtrl,
                  addressController: _addressCtrl,
                  extras: golfCoursesFromSchedules(provider.schedules),
                  decoration: const InputDecoration(
                    labelText: '골프장',
                    hintText: '모르면 비워 두세요',
                  ),
                ),
              ],
            ),
          ),
        );
      case 3:
        return _question(
          title: '참석한 회원이 기억나시나요?',
          body: '아는 분만 고르면 됩니다. 고른 회원은 올해 랭킹 포인트에 반영됩니다.',
          child: _memberPicker(
            provider: provider,
            selected: _attendeeIds,
            onToggle: (id) => setState(() {
              if (_attendeeIds.contains(id)) {
                _attendeeIds.remove(id);
              } else {
                _attendeeIds.add(id);
              }
            }),
          ),
        );
      case 4:
        return _question(
          title: '시상자가 기억나시나요?',
          body: '메달리스트·니어리스트·롱기스트만 넣어도 됩니다. 올해 시상 횟수에 바로 쌓입니다.',
          child: ListView(
            children: [
              for (final item in const [
                ('메달리스트', '🥇'),
                ('니어리스트', '🎯'),
                ('롱기스트', '🏌️'),
              ])
                _awardRow(provider, item.$1, item.$2),
            ],
          ),
        );
      default:
        return _question(
          title: _savedCount <= 1
              ? '지난 일정에 넣었어요'
              : '$_savedCount개 일정을 넣었어요',
          body: '이어서 다음 달 일정도 넣을 수 있습니다. 예: 1월을 넣었으면 바로 2월을 이어서 등록하세요.',
        );
    }
  }

  Widget _question({
    required String title,
    required String body,
    Widget? child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: _kTossInk,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          body,
          style: const TextStyle(
            fontSize: 16,
            height: 1.5,
            color: _kTossGray,
          ),
        ),
        if (child != null) ...[
          const SizedBox(height: 22),
          Expanded(child: child),
        ],
      ],
    );
  }

  Widget _optionalTile({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label,
          style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600, color: _kTossMuted)),
      subtitle: Text(value,
          style: const TextStyle(
              fontSize: 18, fontWeight: FontWeight.w700, color: _kTossInk)),
      trailing: const Icon(Icons.chevron_right, color: _kTossMuted),
      onTap: onTap,
    );
  }

  Widget _memberPicker({
    required ClubProvider provider,
    required Set<String> selected,
    required void Function(String id) onToggle,
  }) {
    final members = [
      ...provider.regularMembers,
      ...provider.guestMembers,
    ];
    if (members.isEmpty) {
      return const Text('아직 명단이 없습니다. 건너뛰고 나중에 회원 탭에서 추가해 주세요.',
          style: TextStyle(color: _kTossGray, height: 1.5));
    }
    return ListView.builder(
      itemCount: members.length,
      itemBuilder: (_, i) {
        final m = members[i];
        final on = selected.contains(m.id);
        return CheckboxListTile(
          value: on,
          onChanged: (_) => onToggle(m.id),
          contentPadding: EdgeInsets.zero,
          title: Text(m.name,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700, color: _kTossInk)),
          subtitle: Text(m.role,
              style: const TextStyle(fontSize: 12, color: _kTossMuted)),
          activeColor: _kTossInk,
        );
      },
    );
  }

  Widget _awardRow(ClubProvider provider, String name, String icon) {
    final ids = _awardWinners[name] ?? {};
    final label = ids.isEmpty
        ? '수상자 없음'
        : ids.map((id) => provider.memberById(id)?.name ?? id).join(', ');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Text(icon, style: const TextStyle(fontSize: 22)),
      title: Text(name,
          style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.w800, color: _kTossInk)),
      subtitle: Text(label, style: const TextStyle(color: _kTossGray)),
      trailing: const Icon(Icons.chevron_right, color: _kTossMuted),
      onTap: () => _pickAwardWinners(provider, name),
    );
  }

  Future<void> _pickAwardWinners(ClubProvider provider, String awardName) async {
    final pool = _attendeeIds.isEmpty
        ? [...provider.regularMembers, ...provider.guestMembers]
        : [
            for (final id in _attendeeIds)
              if (provider.memberById(id) != null) provider.memberById(id)!,
          ];
    final draft = Set<String>.from(_awardWinners[awardName] ?? {});
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            return SafeArea(
              child: SizedBox(
                height: MediaQuery.of(ctx).size.height * 0.7,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Text('$awardName 수상자',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w800)),
                    ),
                    Expanded(
                      child: ListView(
                        children: [
                          for (final m in pool)
                            CheckboxListTile(
                              value: draft.contains(m.id),
                              onChanged: (_) => setSheet(() {
                                if (draft.contains(m.id)) {
                                  draft.remove(m.id);
                                } else {
                                  draft.add(m.id);
                                }
                              }),
                              title: Text(m.name),
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton(
                          onPressed: () {
                            setState(() => _awardWinners[awardName] = draft);
                            Navigator.pop(ctx);
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: _kTossInk,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Text('확인'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    final first = DateTime(now.year - 1, 1, 1);
    final initial = _date ?? DateTime(now.year, _monthHint, 15);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(yesterday) ? yesterday : initial,
      firstDate: first,
      lastDate: yesterday,
      locale: const Locale('ko', 'KR'),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? const TimeOfDay(hour: 7, minute: 30),
    );
    if (picked != null) setState(() => _time = picked);
  }

  Widget _bottomBar() {
    if (_step == 0) {
      return _primaryButton('네, 등록할게요', () => setState(() => _step = 1));
    }
    if (_step == 5) {
      return Column(
        children: [
          _primaryButton('다음 일정 이어서 넣기', _resetForNext),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('여기서 마치기',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _kTossMuted)),
          ),
        ],
      );
    }
    final lastContent = _step == 4;
    return Column(
      children: [
        _primaryButton(
          lastContent ? '저장하기' : '다음',
          () async {
            if (_step == 1 && _titleCtrl.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('일정 이름은 꼭 적어 주세요')),
              );
              return;
            }
            if (_step == 4) {
              final ok = await _commitCurrent();
              if (ok && mounted) setState(() => _step = 5);
              return;
            }
            setState(() => _step += 1);
          },
        ),
        if (_step >= 2 && _step <= 4)
          TextButton(
            onPressed: () async {
              if (_step == 4) {
                final ok = await _commitCurrent();
                if (ok && mounted) setState(() => _step = 5);
                return;
              }
              setState(() => _step += 1);
            },
            child: const Text('잘 모르겠어요, 건너뛰기',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _kTossMuted)),
          ),
      ],
    );
  }

  Widget _primaryButton(String label, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: _kTossInk,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        child: Text(label),
      ),
    );
  }
}
