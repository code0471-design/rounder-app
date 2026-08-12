const fs = require('fs');
const path = require('path');

const file = path.join(
  __dirname,
  '..',
  'lib/screens/admin/admin_notifications_screen.dart',
);
let src = fs.readFileSync(file, 'utf8');

const start = src.indexOf(
  '// ────────────────────────────────────────────────────────────\n//  Push Notification Tab',
);
const end = src.indexOf('// ── Helper Models');
if (start < 0 || end < 0) {
  console.error('markers not found', start, end);
  process.exit(1);
}

const replacement = `// ────────────────────────────────────────────────────────────
//  Push Notification Tab — 본사 푸시 종류 / 대상·시간·내용 / 미리보기
// ────────────────────────────────────────────────────────────
class _PushNotificationTab extends StatefulWidget {
  const _PushNotificationTab();

  @override
  State<_PushNotificationTab> createState() => _PushNotificationTabState();
}

class _PushNotificationTabState extends State<_PushNotificationTab> {
  late List<HqPushType> _types;
  String? _selectedId;
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _types = List<HqPushType>.from(AdminCatalog.hqPushTypes);
    _selectedId = _types.isEmpty ? null : _types.first.id;
    _loadSelectedIntoForm();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  HqPushType? get _selected {
    for (final t in _types) {
      if (t.id == _selectedId) return t;
    }
    return null;
  }

  void _loadSelectedIntoForm() {
    final t = _selected;
    if (t == null) return;
    _titleCtrl.text = t.defaultTitle;
    _bodyCtrl.text = t.defaultBody;
  }

  void _select(String id) {
    _commitFormToSelected();
    setState(() {
      _selectedId = id;
      _loadSelectedIntoForm();
    });
  }

  void _commitFormToSelected() {
    final t = _selected;
    if (t == null) return;
    final i = _types.indexWhere((x) => x.id == t.id);
    if (i < 0) return;
    _types[i] = t.copyWith(
      defaultTitle: _titleCtrl.text.trim(),
      defaultBody: _bodyCtrl.text.trim(),
    );
  }

  void _toggleEnabled(bool v) {
    final t = _selected;
    if (t == null) return;
    setState(() {
      final i = _types.indexWhere((x) => x.id == t.id);
      if (i >= 0) _types[i] = t.copyWith(enabled: v);
    });
  }

  void _save() {
    _commitFormToSelected();
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('본사 푸시 종류 설정이 저장되었습니다.'),
        backgroundColor: AdminColors.statusOk,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildAudienceLegend(),
          const SizedBox(height: 12),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 4, child: _buildTypeList()),
                const SizedBox(width: 14),
                Expanded(flex: 4, child: _buildConfigPanel()),
                const SizedBox(width: 14),
                Expanded(flex: 3, child: _buildPreviewPanel()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudienceLegend() {
    Widget chip(PushAudienceKind k, Color c) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: c.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              k.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: c,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              k.description,
              style: const TextStyle(
                fontSize: 11,
                color: AdminColors.textSecond,
                height: 1.3,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '발송 대상 · 시간 기준',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AdminColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                  child: chip(
                      PushAudienceKind.allMembers, AdminColors.statusInfo)),
              const SizedBox(width: 8),
              Expanded(
                  child: chip(
                      PushAudienceKind.attendees, AdminColors.statusWarn)),
              const SizedBox(width: 8),
              Expanded(
                  child: chip(PushAudienceKind.specificMember,
                      AdminColors.accent)),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '발송 시간: 등록 즉시  ·  D-1 10시',
            style: TextStyle(fontSize: 11, color: AdminColors.textHint),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeList() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                const Expanded(
                  child: Text('본사 푸시 종류',
                      style: AdminTextStyles.sectionTitle),
                ),
                AdminBadge(
                  label: '활성 \${_types.where((t) => t.enabled).length}',
                  color: AdminColors.statusOk,
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Text(
              '본사에서 설정한 알림 종류 리스트입니다. 항목을 선택해 대상·시간·내용을 확인하세요.',
              style: TextStyle(fontSize: 11, color: AdminColors.textHint),
            ),
          ),
          const Divider(height: 1, color: AdminColors.cardBorder),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 14),
              itemCount: _types.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _typeTile(_types[i]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _typeTile(HqPushType t) {
    final selected = t.id == _selectedId;
    return Material(
      color: selected
          ? AdminColors.accent.withValues(alpha: 0.06)
          : AdminColors.contentBg,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _select(t.id),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? AdminColors.accent : Colors.transparent,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      t.name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AdminColors.textPrimary,
                      ),
                    ),
                  ),
                  AdminBadge(
                    label: t.enabled ? 'ON' : 'OFF',
                    color: t.enabled
                        ? AdminColors.statusOk
                        : AdminColors.textHint,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _miniChip(t.audience.label, _audienceColor(t.audience)),
                  _miniChip(t.timing.label, AdminColors.statusInfo),
                  _miniChip(t.channel, AdminColors.textSecond),
                ],
              ),
              if (t.audience == PushAudienceKind.specificMember &&
                  t.audienceDetail.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  t.audienceDetail,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AdminColors.textHint,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _audienceColor(PushAudienceKind k) => switch (k) {
        PushAudienceKind.allMembers => AdminColors.statusInfo,
        PushAudienceKind.attendees => AdminColors.statusWarn,
        PushAudienceKind.specificMember => AdminColors.accent,
      };

  Widget _miniChip(String label, Color c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: c,
        ),
      ),
    );
  }

  Widget _buildConfigPanel() {
    final t = _selected;
    if (t == null) {
      return Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AdminColors.cardBorder),
        ),
        child: const Text('왼쪽에서 푸시 종류를 선택하세요',
            style: TextStyle(color: AdminColors.textHint)),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                const Expanded(
                  child:
                      Text('발송 설정', style: AdminTextStyles.sectionTitle),
                ),
                const Text('사용',
                    style: TextStyle(
                        fontSize: 12, color: AdminColors.textSecond)),
                const SizedBox(width: 6),
                Switch.adaptive(
                  value: t.enabled,
                  activeColor: AdminColors.accent,
                  onChanged: _toggleEnabled,
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AdminColors.cardBorder),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AdminColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _fieldLabel('발송 대상'),
                  const SizedBox(height: 8),
                  _infoCard(
                    title: t.audience.label,
                    body: t.audience.description,
                    detail: t.audienceDetail,
                    color: _audienceColor(t.audience),
                  ),
                  if (t.audience == PushAudienceKind.specificMember) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AdminColors.accent.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: AdminColors.accent.withValues(alpha: 0.25)),
                      ),
                      child: const Text(
                        '표시 팁: 리스트에는 「해당 회원」으로 통일하고, 아래에 수신자 역할만 적어 구분합니다. (예: 신청자 본인 / 총무 / 미납 회원)',
                        style: TextStyle(
                          fontSize: 11,
                          color: AdminColors.textSecond,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  _fieldLabel('발송 시간'),
                  const SizedBox(height: 8),
                  _infoCard(
                    title: t.timing.label,
                    body: t.timing.description,
                    color: AdminColors.statusInfo,
                  ),
                  const SizedBox(height: 18),
                  _fieldLabel('내용'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _titleCtrl,
                    onChanged: (_) => setState(() {}),
                    maxLength: 50,
                    decoration: _inputDecoration('푸시 제목'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _bodyCtrl,
                    onChanged: (_) => setState(() {}),
                    maxLines: 5,
                    maxLength: 200,
                    decoration: _inputDecoration('푸시 본문 ({{변수}} 사용 가능)'),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.save_rounded, size: 16),
                      label: const Text('설정 저장',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AdminColors.accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fieldLabel(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AdminColors.textSecond,
        ),
      );

  Widget _infoCard({
    required String title,
    required String body,
    String detail = '',
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            style: const TextStyle(
              fontSize: 12,
              color: AdminColors.textSecond,
              height: 1.4,
            ),
          ),
          if (detail.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '세부: \$detail',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AdminColors.textPrimary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPreviewPanel() {
    final t = _selected;
    final title = _titleCtrl.text.trim().isEmpty
        ? (t?.defaultTitle ?? '알림 제목')
        : _titleCtrl.text.trim();
    final body = _bodyCtrl.text.trim().isEmpty
        ? (t?.defaultBody ?? '내용 미리보기')
        : _bodyCtrl.text.trim();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Text('미리보기', style: AdminTextStyles.sectionTitle),
          ),
          const Divider(height: 1, color: AdminColors.cardBorder),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Column(
                children: [
                  const Text(
                    '사용자 기기에 표시되는 푸시',
                    style:
                        TextStyle(fontSize: 12, color: AdminColors.textHint),
                  ),
                  const SizedBox(height: 14),
                  _phonePreview(title, body),
                  if (t != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AdminColors.contentBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AdminColors.cardBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _metaRow('종류', t.name),
                          const SizedBox(height: 6),
                          _metaRow('대상', t.audience.label),
                          if (t.audienceDetail.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            _metaRow('세부', t.audienceDetail),
                          ],
                          const SizedBox(height: 6),
                          _metaRow('시간', t.timing.label),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metaRow(String k, String v) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 36,
          child: Text(
            k,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AdminColors.textHint,
            ),
          ),
        ),
        Expanded(
          child: Text(
            v,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AdminColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _phonePreview(String title, String body) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F7),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5E5EA)),
      ),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('9:41',
                  style: TextStyle(
                      color: Color(0xFF1C1C1E),
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
              Row(children: [
                Icon(Icons.signal_cellular_alt,
                    color: Color(0xFF1C1C1E), size: 12),
                SizedBox(width: 3),
                Icon(Icons.wifi, color: Color(0xFF1C1C1E), size: 12),
                SizedBox(width: 3),
                Icon(Icons.battery_full, color: Color(0xFF1C1C1E), size: 12),
              ]),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const RounderAppIcon(size: 34),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ROUNDER',
                        style: TextStyle(
                          color: Color(0xFF636366),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        title,
                        style: const TextStyle(
                          color: Color(0xFF1C1C1E),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        body,
                        style: const TextStyle(
                          color: Color(0xFF3A3A3C),
                          fontSize: 12,
                          height: 1.35,
                        ),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint.isEmpty ? null : hint,
      hintStyle: const TextStyle(fontSize: 13, color: AdminColors.textHint),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AdminColors.cardBorder)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AdminColors.cardBorder)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AdminColors.accent)),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      filled: true,
      fillColor: AdminColors.contentBg,
      counterStyle:
          const TextStyle(fontSize: 11, color: AdminColors.textHint),
    );
  }
}

`;

// Fix escaped template literals that should be Dart string interpolation
const fixed = replacement
  .replace(
    "label: '활성 \\${_types.where((t) => t.enabled).length}'",
    "label: '활성 \${_types.where((t) => t.enabled).length}'",
  )
  .replace("'세부: \\$detail'", "'세부: \$detail'");

src = src.slice(0, start) + fixed + src.slice(end);
fs.writeFileSync(file, src, 'utf8');
console.log('OK push HQ types UI patched', fixed.length);
