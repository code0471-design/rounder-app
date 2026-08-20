const fs = require('fs');
const path = require('path');

const file = path.join(
  __dirname,
  '..',
  'lib',
  'screens',
  'schedule',
  'schedule_screen.dart',
);

let src = fs.readFileSync(file, 'utf8');
const nl = src.includes('\r\n') ? '\r\n' : '\n';

const oldAppBar =
  `      appBar: AppBar(${nl}` +
  `        backgroundColor: Colors.black,${nl}` +
  `        iconTheme: const IconThemeData(color: Colors.white),${nl}` +
  `        title: Text(${nl}` +
  `          '\${_current + 1} / \${widget.photos.length}',${nl}` +
  `          style: const TextStyle(color: Colors.white, fontSize: 14),${nl}` +
  `        ),${nl}` +
  `        centerTitle: true,${nl}` +
  `      ),`;

if (!src.includes(oldAppBar)) {
  if (src.includes('provider.isOwnPhoto(photo)')) {
    console.log('schedule photo viewer already patched');
    process.exit(0);
  }
  console.error('appBar marker missing');
  process.exit(1);
}

const newAppBar =
  `      appBar: AppBar(${nl}` +
  `        backgroundColor: Colors.black,${nl}` +
  `        iconTheme: const IconThemeData(color: Colors.white),${nl}` +
  `        title: Text(${nl}` +
  `          '\${_current + 1} / \${widget.photos.length}',${nl}` +
  `          style: const TextStyle(color: Colors.white, fontSize: 14),${nl}` +
  `        ),${nl}` +
  `        centerTitle: true,${nl}` +
  `        actions: [${nl}` +
  `          Consumer<ClubProvider>(${nl}` +
  `            builder: (ctx, provider, _) {${nl}` +
  `              if (!provider.isOwnPhoto(photo)) return const SizedBox.shrink();${nl}` +
  `              return Row(${nl}` +
  `                mainAxisSize: MainAxisSize.min,${nl}` +
  `                children: [${nl}` +
  `                  IconButton(${nl}` +
  `                    icon: const Icon(Icons.edit_outlined, color: Colors.white70),${nl}` +
  `                    onPressed: () => _editCaption(ctx, provider, photo),${nl}` +
  `                  ),${nl}` +
  `                  IconButton(${nl}` +
  `                    icon: const Icon(Icons.delete_outline, color: Colors.white70),${nl}` +
  `                    onPressed: () => _confirmDelete(ctx, provider, photo),${nl}` +
  `                  ),${nl}` +
  `                ],${nl}` +
  `              );${nl}` +
  `            },${nl}` +
  `          ),${nl}` +
  `        ],${nl}` +
  `      ),`;

src = src.replace(oldAppBar, newAppBar);

const insertBefore =
  `class _SchedulePhotoViewerState extends State<_SchedulePhotoViewer> {${nl}` +
  `  late PageController _controller;${nl}` +
  `  late int _current;`;

const methods =
  `class _SchedulePhotoViewerState extends State<_SchedulePhotoViewer> {${nl}` +
  `  late PageController _controller;${nl}` +
  `  late int _current;${nl}` +
  `${nl}` +
  `  Future<void> _editCaption(${nl}` +
  `      BuildContext context, ClubProvider provider, RoundPhoto photo) async {${nl}` +
  `    final ctrl = TextEditingController(text: photo.caption ?? '');${nl}` +
  `    final ok = await showDialog<bool>(${nl}` +
  `      context: context,${nl}` +
  `      builder: (dialogCtx) => AlertDialog(${nl}` +
  `        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),${nl}` +
  `        title: const Text('사진 설명 수정'),${nl}` +
  `        content: TextField(${nl}` +
  `          controller: ctrl,${nl}` +
  `          maxLines: 3,${nl}` +
  `          autofocus: true,${nl}` +
  `          decoration: const InputDecoration(border: OutlineInputBorder()),${nl}` +
  `        ),${nl}` +
  `        actions: [${nl}` +
  `          TextButton(${nl}` +
  `              onPressed: () => Navigator.pop(dialogCtx, false),${nl}` +
  `              child: const Text('취소')),${nl}` +
  `          TextButton(${nl}` +
  `              onPressed: () => Navigator.pop(dialogCtx, true),${nl}` +
  `              child: const Text('저장')),${nl}` +
  `        ],${nl}` +
  `      ),${nl}` +
  `    );${nl}` +
  `    if (ok == true) {${nl}` +
  `      provider.updatePhotoCaption(photo.id, ctrl.text);${nl}` +
  `      if (mounted) setState(() {});${nl}` +
  `    }${nl}` +
  `  }${nl}` +
  `${nl}` +
  `  Future<void> _confirmDelete(${nl}` +
  `      BuildContext context, ClubProvider provider, RoundPhoto photo) async {${nl}` +
  `    final ok = await showDialog<bool>(${nl}` +
  `      context: context,${nl}` +
  `      builder: (dialogCtx) => AlertDialog(${nl}` +
  `        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),${nl}` +
  `        title: const Text('사진 삭제'),${nl}` +
  `        content: const Text('이 사진을 삭제할까요?'),${nl}` +
  `        actions: [${nl}` +
  `          TextButton(${nl}` +
  `              onPressed: () => Navigator.pop(dialogCtx, false),${nl}` +
  `              child: const Text('취소')),${nl}` +
  `          TextButton(${nl}` +
  `              onPressed: () => Navigator.pop(dialogCtx, true),${nl}` +
  `              child: const Text('삭제',${nl}` +
  `                  style: TextStyle(color: AppColors.danger))),${nl}` +
  `        ],${nl}` +
  `      ),${nl}` +
  `    );${nl}` +
  `    if (ok == true) {${nl}` +
  `      final deleted = provider.deletePhoto(photo.id);${nl}` +
  `      if (!mounted) return;${nl}` +
  `      if (deleted) Navigator.pop(context);${nl}` +
  `    }${nl}` +
  `  }`;

if (!src.includes(insertBefore)) {
  console.error('state class marker missing');
  process.exit(1);
}
if (!src.includes('_editCaption(ctx, provider, photo)')) {
  // methods not yet; only if appBar was applied
}
src = src.replace(insertBefore, methods);

fs.writeFileSync(file, src, 'utf8');
console.log('patched schedule photo viewer own edit/delete');
