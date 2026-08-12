// ────────────────────────────────────────────────────────────
//  Push Notification Tab
//  · 모임 자동 푸시 / 본사 전체 발송
//  · 메인 화면은 테이블(스크롤 최소), 추가·수정은 다이얼로그
// ────────────────────────────────────────────────────────────
class _PushNotificationTab extends StatefulWidget {
  const _PushNotificationTab();

  @override
  State<_PushNotificationTab> createState() => _PushNotificationTabState();
}

class _PushNotificationTabState extends State<_PushNotificationTab> {
  int _mode = 0; // 0 club auto, 1 hq broadcast

  late List<HqPushType> _clubTypes;
  late List<HqBroadcastJob> _broadcasts;

  @override
  void initState() {
    super.initState();
    _clubTypes = List<HqPushType>.from(AdminCatalog.hqPushTypes);
    _broadcasts = [
      HqBroadcastJob(
        id: 'bc1',
        title: 'ROUNDER 업데이트 안내',
        body: '앱이 업데이트되었습니다. 최신 버전으로 이용해 주세요.',
        when: DateTime.now().subtract(const Duration(days: 2)),
        sendNow: true,
        status: 'sent',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _toolbar(),
          const SizedBox(height: 14),
          Expanded(child: _mode == 0 ? _clubTable() : _broadcastTable()),
        ],
      ),
    );
  }

  // ── 상단: 모드 + 추가 버튼 (항상 보임) ───────────────────
  Widget _toolbar() {
    return Row(
      children: [
        _pill(0, '모임 자동 푸시', Icons.groups_rounded),
        const SizedBox(width: 8),
        _pill(1, '본사 전체 발송', Icons.campaign_rounded),
        const Spacer(),
        if (_mode == 0)
          _primaryBtn(
            icon: Icons.add_rounded,
            label: '푸시 종류 추가',
            onTap: () => _openClubEditor(),
          )
        else
          _primaryBtn(
            icon: Icons.add_rounded,
            label: '새 발송 추가',
            onTap: () => _openBroadcastEditor(),
          ),
      ],
    );
  }

  Widget _pill(int i, String label, IconData icon) {
    final on = _mode == i;
    return Material(
      color: on ? AdminColors.accent : Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: () => setState(() => _mode = i),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: on ? AdminColors.accent : AdminColors.cardBorder,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 16,
                  color: on ? Colors.white : AdminColors.textSecond),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: on ? Colors.white : AdminColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _primaryBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      style: ElevatedButton.styleFrom(
        backgroundColor: AdminColors.accent,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ── 모임 자동 푸시 테이블 ────────────────────────────────
  Widget _clubTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminColors.cardBorder),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: const BoxDecoration(
              color: Color(0xFFF0FDF4),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              border: Border(bottom: BorderSide(color: AdminColors.cardBorder)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: AdminColors.accent),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '모임 이벤트용 자동 푸시 · 대상/시간/문구를 본사에서 설정합니다',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AdminColors.accent,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _tableHeader(const [
            (3, '알림 종류'),
            (2, '발송 대상'),
            (2, '발송 시간'),
            (1, '사용'),
            (2, ''),
          ]),
          Expanded(
            child: ListView.builder(
              itemCount: _clubTypes.length,
              itemBuilder: (_, i) {
                final t = _clubTypes[i];
                return Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: i.isEven ? Colors.white : const Color(0xFFF8FAFC),
                    border: const Border(
                        bottom: BorderSide(color: AdminColors.divider)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(t.name,
                            style: AdminTextStyles.tableCell
                                .copyWith(fontWeight: FontWeight.w700),
                            overflow: TextOverflow.ellipsis),
                      ),
                      Expanded(
                        flex: 2,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: AdminBadge(
                            label: t.audience.label,
                            color: _audienceColor(t.audience),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: AdminBadge(
                            label: t.timing.label,
                            color: AdminColors.statusInfo,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Switch.adaptive(
                          value: t.enabled,
                          activeTrackColor: AdminColors.accent,
                          onChanged: (v) {
                            setState(() {
                              _clubTypes[i] = t.copyWith(enabled: v);
                            });
                          },
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () => _openClubEditor(existing: t),
                            icon: const Icon(Icons.edit_outlined, size: 16),
                            label: const Text('수정',
                                style: TextStyle(fontWeight: FontWeight.w700)),
                            style: TextButton.styleFrom(
                              foregroundColor: AdminColors.accent,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── 본사 전체 발송 테이블 ────────────────────────────────
  Widget _broadcastTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminColors.cardBorder),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: const BoxDecoration(
              color: Color(0xFFFFF7ED),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              border: Border(bottom: BorderSide(color: AdminColors.cardBorder)),
            ),
            child: const Row(
              children: [
                Icon(Icons.campaign_outlined,
                    size: 16, color: AdminColors.statusWarn),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '앱 가입 회원 전체 대상 · 모임 자동 푸시와 별개로 본사가 직접 발송합니다',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFB45309),
                    ),
                  ),
                ),
              ],
            ),
          ),
          _tableHeader(const [
            (4, '제목'),
            (3, '대상'),
            (3, '발송 시간'),
            (2, '상태'),
            (2, ''),
          ]),
          Expanded(
            child: _broadcasts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('아직 발송이 없습니다',
                            style: TextStyle(
                                color: AdminColors.textHint, fontSize: 14)),
                        const SizedBox(height: 12),
                        _primaryBtn(
                          icon: Icons.add_rounded,
                          label: '새 발송 추가',
                          onTap: () => _openBroadcastEditor(),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _broadcasts.length,
                    itemBuilder: (_, i) {
                      final b = _broadcasts[i];
                      final (stLabel, stColor) = switch (b.status) {
                        'sending' => ('발송중', AdminColors.statusInfo),
                        'scheduled' => ('예약', AdminColors.statusWarn),
                        'sent' => ('완료', AdminColors.statusOk),
                        _ => (b.status, AdminColors.textHint),
                      };
                      return Container(
                        height: 56,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color:
                              i.isEven ? Colors.white : const Color(0xFFF8FAFC),
                          border: const Border(
                              bottom:
                                  BorderSide(color: AdminColors.divider)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 4,
                              child: Text(b.title,
                                  style: AdminTextStyles.tableCell
                                      .copyWith(fontWeight: FontWeight.w700),
                                  overflow: TextOverflow.ellipsis),
                            ),
                            const Expanded(
                              flex: 3,
                              child: Text('앱 가입 회원 전체',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: AdminColors.textSecond)),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                b.sendNow && b.status != 'scheduled'
                                    ? '즉시 · ${_fmt(b.when)}'
                                    : _fmt(b.when),
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: AdminColors.textSecond),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: AdminBadge(
                                    label: stLabel, color: stColor),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: b.status == 'sent'
                                      ? null
                                      : () =>
                                          _openBroadcastEditor(existing: b),
                                  icon: const Icon(Icons.edit_outlined,
                                      size: 16),
                                  label: const Text('수정',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700)),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AdminColors.accent,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _tableHeader(List<(int, String)> cols) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: const Color(0xFFF8FAFC),
      child: Row(
        children: [
          for (final c in cols)
            Expanded(
              flex: c.$1,
              child: Text(c.$2, style: AdminTextStyles.tableHeader),
            ),
        ],
      ),
    );
  }

  Color _audienceColor(PushAudienceKind k) => switch (k) {
        PushAudienceKind.allMembers => AdminColors.statusInfo,
        PushAudienceKind.attendees => AdminColors.statusWarn,
        PushAudienceKind.specificMember => AdminColors.accent,
      };

  String _fmt(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final mi = d.minute.toString().padLeft(2, '0');
    return '${d.year}.$mm.$dd $hh:$mi';
  }

  // ── 모임 푸시 추가/수정 다이얼로그 ───────────────────────
  Future<void> _openClubEditor({HqPushType? existing}) async {
    final isNew = existing == null;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final titleCtrl =
        TextEditingController(text: existing?.defaultTitle ?? '');
    final bodyCtrl = TextEditingController(text: existing?.defaultBody ?? '');
    final detailCtrl =
        TextEditingController(text: existing?.audienceDetail ?? '');
    var audience = existing?.audience ?? PushAudienceKind.allMembers;
    var timing = existing?.timing ?? PushTimingKind.immediate;
    var enabled = existing?.enabled ?? true;

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return Dialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AdminColors.accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.notifications_active,
                                color: AdminColors.accent, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              isNew ? '푸시 종류 추가' : '푸시 종류 수정',
                              style: AdminTextStyles.sectionTitle,
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _dlgLabel('알림 종류 이름'),
                              const SizedBox(height: 6),
                              TextField(
                                controller: nameCtrl,
                                decoration: _dlgDeco('예: D-1 리마인더'),
                              ),
                              const SizedBox(height: 14),
                              _dlgLabel('발송 대상'),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: PushAudienceKind.values.map((k) {
                                  final on = audience == k;
                                  return ChoiceChip(
                                    label: Text(k.label),
                                    selected: on,
                                    selectedColor:
                                        AdminColors.accent.withValues(alpha: 0.15),
                                    labelStyle: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: on
                                          ? AdminColors.accent
                                          : AdminColors.textSecond,
                                    ),
                                    onSelected: (_) =>
                                        setLocal(() => audience = k),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                audience.description,
                                style: const TextStyle(
                                    fontSize: 11, color: AdminColors.textHint),
                              ),
                              if (audience ==
                                  PushAudienceKind.specificMember) ...[
                                const SizedBox(height: 8),
                                TextField(
                                  controller: detailCtrl,
                                  decoration:
                                      _dlgDeco('세부 수신자 (예: 신청자 본인 / 총무)'),
                                ),
                              ],
                              const SizedBox(height: 14),
                              _dlgLabel('발송 시간'),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                children: PushTimingKind.values.map((k) {
                                  final on = timing == k;
                                  return ChoiceChip(
                                    label: Text(k.label),
                                    selected: on,
                                    selectedColor: AdminColors.statusInfo
                                        .withValues(alpha: 0.15),
                                    labelStyle: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: on
                                          ? AdminColors.statusInfo
                                          : AdminColors.textSecond,
                                    ),
                                    onSelected: (_) =>
                                        setLocal(() => timing = k),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                timing.description,
                                style: const TextStyle(
                                    fontSize: 11, color: AdminColors.textHint),
                              ),
                              const SizedBox(height: 14),
                              _dlgLabel('푸시 내용'),
                              const SizedBox(height: 6),
                              TextField(
                                controller: titleCtrl,
                                maxLength: 50,
                                decoration: _dlgDeco('제목'),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: bodyCtrl,
                                maxLines: 3,
                                maxLength: 200,
                                decoration: _dlgDeco('본문'),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Text('사용',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700)),
                                  const Spacer(),
                                  Switch.adaptive(
                                    value: enabled,
                                    activeTrackColor: AdminColors.accent,
                                    onChanged: (v) =>
                                        setLocal(() => enabled = v),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                side: const BorderSide(
                                    color: AdminColors.cardBorder),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                              child: const Text('취소',
                                  style: TextStyle(fontWeight: FontWeight.w700)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: () {
                                if (nameCtrl.text.trim().isEmpty ||
                                    titleCtrl.text.trim().isEmpty ||
                                    bodyCtrl.text.trim().isEmpty) {
                                  return;
                                }
                                Navigator.pop(ctx, true);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AdminColors.accent,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                              child: Text(isNew ? '추가' : '저장',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (ok != true || !mounted) {
      nameCtrl.dispose();
      titleCtrl.dispose();
      bodyCtrl.dispose();
      detailCtrl.dispose();
      return;
    }

    setState(() {
      if (isNew) {
        _clubTypes.add(HqPushType(
          id: 'push_${DateTime.now().millisecondsSinceEpoch}',
          name: nameCtrl.text.trim(),
          channel: '푸시',
          audience: audience,
          timing: timing,
          audienceDetail: detailCtrl.text.trim(),
          defaultTitle: titleCtrl.text.trim(),
          defaultBody: bodyCtrl.text.trim(),
          enabled: enabled,
        ));
      } else {
        final i = _clubTypes.indexWhere((x) => x.id == existing.id);
        if (i >= 0) {
          _clubTypes[i] = existing.copyWith(
            name: nameCtrl.text.trim(),
            audience: audience,
            timing: timing,
            audienceDetail: detailCtrl.text.trim(),
            defaultTitle: titleCtrl.text.trim(),
            defaultBody: bodyCtrl.text.trim(),
            enabled: enabled,
          );
        }
      }
    });

    nameCtrl.dispose();
    titleCtrl.dispose();
    bodyCtrl.dispose();
    detailCtrl.dispose();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isNew ? '푸시 종류가 추가되었습니다.' : '푸시 종류가 수정되었습니다.'),
        backgroundColor: AdminColors.statusOk,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── 본사 전체 발송 추가/수정 다이얼로그 ─────────────────
  Future<void> _openBroadcastEditor({HqBroadcastJob? existing}) async {
    final isNew = existing == null;
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final bodyCtrl = TextEditingController(text: existing?.body ?? '');
    var sendNow = existing?.sendNow ?? true;
    var when = existing?.when ?? DateTime.now().add(const Duration(hours: 1));

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return Dialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520, maxHeight: 560),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AdminColors.statusWarn
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.campaign_rounded,
                                color: AdminColors.statusWarn, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              isNew ? '새 본사 전체 발송' : '본사 전체 발송 수정',
                              style: AdminTextStyles.sectionTitle,
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: AdminColors.statusWarn
                                  .withValues(alpha: 0.4)),
                        ),
                        child: const Text(
                          '발송 대상 고정: 앱 가입 회원 전체 (모임과 무관)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFB45309),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _dlgLabel('발송 시간'),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  ChoiceChip(
                                    label: const Text('즉시 발송'),
                                    selected: sendNow,
                                    selectedColor: AdminColors.accent
                                        .withValues(alpha: 0.15),
                                    labelStyle: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: sendNow
                                          ? AdminColors.accent
                                          : AdminColors.textSecond,
                                    ),
                                    onSelected: (_) =>
                                        setLocal(() => sendNow = true),
                                  ),
                                  const SizedBox(width: 8),
                                  ChoiceChip(
                                    label: const Text('예약 발송'),
                                    selected: !sendNow,
                                    selectedColor: AdminColors.statusInfo
                                        .withValues(alpha: 0.15),
                                    labelStyle: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: !sendNow
                                          ? AdminColors.statusInfo
                                          : AdminColors.textSecond,
                                    ),
                                    onSelected: (_) =>
                                        setLocal(() => sendNow = false),
                                  ),
                                ],
                              ),
                              if (!sendNow) ...[
                                const SizedBox(height: 8),
                                OutlinedButton.icon(
                                  onPressed: () async {
                                    final date = await showDatePicker(
                                      context: ctx,
                                      initialDate: when,
                                      firstDate: DateTime.now(),
                                      lastDate: DateTime.now()
                                          .add(const Duration(days: 30)),
                                    );
                                    if (date == null) return;
                                    if (!ctx.mounted) return;
                                    final time = await showTimePicker(
                                      context: ctx,
                                      initialTime:
                                          TimeOfDay.fromDateTime(when),
                                    );
                                    if (time == null) return;
                                    setLocal(() {
                                      when = DateTime(
                                        date.year,
                                        date.month,
                                        date.day,
                                        time.hour,
                                        time.minute,
                                      );
                                    });
                                  },
                                  icon: const Icon(Icons.schedule, size: 16),
                                  label: Text(_fmt(when)),
                                ),
                              ],
                              const SizedBox(height: 14),
                              _dlgLabel('내용'),
                              const SizedBox(height: 6),
                              TextField(
                                controller: titleCtrl,
                                maxLength: 50,
                                decoration: _dlgDeco('제목'),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: bodyCtrl,
                                maxLines: 4,
                                maxLength: 200,
                                decoration: _dlgDeco('본문'),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                              child: const Text('취소',
                                  style: TextStyle(fontWeight: FontWeight.w700)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: () {
                                if (titleCtrl.text.trim().isEmpty ||
                                    bodyCtrl.text.trim().isEmpty) {
                                  return;
                                }
                                Navigator.pop(ctx, true);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AdminColors.accent,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                              child: Text(
                                isNew
                                    ? (sendNow ? '발송 추가' : '예약 추가')
                                    : '저장',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (ok != true || !mounted) {
      titleCtrl.dispose();
      bodyCtrl.dispose();
      return;
    }

    final job = HqBroadcastJob(
      id: existing?.id ?? 'bc_${DateTime.now().millisecondsSinceEpoch}',
      title: titleCtrl.text.trim(),
      body: bodyCtrl.text.trim(),
      when: sendNow ? DateTime.now() : when,
      sendNow: sendNow,
      status: sendNow ? 'sending' : 'scheduled',
    );

    setState(() {
      if (isNew) {
        _broadcasts.insert(0, job);
      } else {
        final i = _broadcasts.indexWhere((x) => x.id == existing.id);
        if (i >= 0) _broadcasts[i] = job;
      }
    });

    titleCtrl.dispose();
    bodyCtrl.dispose();

    if (sendNow) {
      await Future.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
      setState(() {
        final i = _broadcasts.indexWhere((x) => x.id == job.id);
        if (i >= 0) {
          _broadcasts[i] = _broadcasts[i].copyWith(status: 'sent');
        }
      });
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(sendNow
            ? '앱 가입 회원 전체에게 발송을 시작했습니다.'
            : '본사 전체 발송이 예약되었습니다.'),
        backgroundColor: AdminColors.statusOk,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _dlgLabel(String t) => Text(
        t,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: AdminColors.textSecond,
        ),
      );

  InputDecoration _dlgDeco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 13, color: AdminColors.textHint),
        filled: true,
        fillColor: AdminColors.contentBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AdminColors.cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AdminColors.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AdminColors.accent, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      );
}
