/**
 * schedule_screen: 일정 갤러리 삭제 후 UI 갱신 (CRLF-safe).
 */
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

function findUnique(snippet, label) {
  const i = src.indexOf(snippet);
  if (i < 0) {
    console.error('FAIL missing:', label);
    process.exit(1);
  }
  if (src.indexOf(snippet, i + 1) >= 0) {
    console.error('FAIL not unique:', label);
    process.exit(1);
  }
  return i;
}

// Patch open viewer call site
const viewerOld = `builder: (_) => _SchedulePhotoViewer(photos: photos, initialIndex: index),`;
const viewerNew = `builder: (_) => _SchedulePhotoViewer(${nl}          scheduleId: schedule.id,${nl}          photos: photos,${nl}          initialIndex: index,${nl}        ),`;
findUnique(viewerOld, 'viewer ctor');
src = src.replace(viewerOld, viewerNew);
console.log('OK viewer open');

const albumOld = `        builder: (_) => _SchedulePhotoAlbumScreen(
          title: schedule.displayTitle,
          photos: photos,
        ),`;
const albumNew = `        builder: (_) => _SchedulePhotoAlbumScreen(
          scheduleId: schedule.id,
          title: schedule.displayTitle,
          photos: photos,
        ),`;
// normalize albumOld to file newlines
const albumOldNl = albumOld.replace(/\n/g, nl);
const albumNewNl = albumNew.replace(/\n/g, nl);
findUnique(albumOldNl, 'album open');
src = src.replace(albumOldNl, albumNewNl);
console.log('OK album open');

const startMark = '// ── 일정 라운딩 사진첩 (전체보기) ──';
const endMark =
  '// ────────────────────────────────────────────────────────────' +
  nl +
  '//  조편성 진입 카드';
const start = findUnique(startMark, 'album start');
const end = src.indexOf(endMark, start);
if (end < 0) {
  console.error('FAIL end mark');
  process.exit(1);
}

const replacement = `// ── 일정 라운딩 사진첩 (전체보기) ──
class _SchedulePhotoAlbumScreen extends StatelessWidget {
  final String scheduleId;
  final String title;
  final List<RoundPhoto> photos;
  const _SchedulePhotoAlbumScreen({
    required this.scheduleId,
    required this.title,
    required this.photos,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ClubProvider>(
      builder: (context, provider, _) {
        final live = provider.photosOf(scheduleId);
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new,
                  size: 18, color: AppColors.textPrimary),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              '\$title · \${live.length}장',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          body: live.isEmpty
              ? const Center(
                  child: Text(
                    '사진이 없습니다',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 4,
                  ),
                  itemCount: live.length,
                  itemBuilder: (context, index) {
                    final photo = live[index];
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => _SchedulePhotoViewer(
                              scheduleId: scheduleId,
                              photos: live,
                              initialIndex: index,
                            ),
                          ),
                        );
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: RoundPhotoView(imageUrl: photo.imageUrl),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}

// ── 일정 내 사진 뷰어 ──
class _SchedulePhotoViewer extends StatefulWidget {
  final String scheduleId;
  final List<RoundPhoto> photos;
  final int initialIndex;
  const _SchedulePhotoViewer({
    required this.scheduleId,
    required this.photos,
    required this.initialIndex,
  });

  @override
  State<_SchedulePhotoViewer> createState() => _SchedulePhotoViewerState();
}

class _SchedulePhotoViewerState extends State<_SchedulePhotoViewer> {
  late PageController _controller;
  late int _current;
  late List<RoundPhoto> _photos;

  @override
  void initState() {
    super.initState();
    _photos = List<RoundPhoto>.from(widget.photos);
    _current = widget.initialIndex;
    if (_photos.isNotEmpty) {
      _current = _current.clamp(0, _photos.length - 1);
    } else {
      _current = 0;
    }
    _controller = PageController(initialPage: _current);
  }

  void _syncFromProvider(ClubProvider provider) {
    final live = provider.photosOf(widget.scheduleId);
    final prevId = (_photos.isNotEmpty && _current < _photos.length)
        ? _photos[_current].id
        : null;
    _photos = List<RoundPhoto>.from(live);
    if (_photos.isEmpty) {
      _current = 0;
      return;
    }
    var next =
        prevId == null ? 0 : _photos.indexWhere((p) => p.id == prevId);
    if (next < 0) {
      next = _current.clamp(0, _photos.length - 1);
    }
    _current = next;
  }

  Future<void> _editCaption(
      BuildContext context, ClubProvider provider, RoundPhoto photo) async {
    final ctrl = TextEditingController(text: photo.caption ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('사진 설명 수정'),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('취소')),
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: const Text('저장')),
        ],
      ),
    );
    if (ok == true) {
      provider.updatePhotoCaption(photo.id, ctrl.text);
      if (mounted) setState(() => _syncFromProvider(provider));
    }
  }

  Future<void> _confirmDelete(
      BuildContext context, ClubProvider provider, RoundPhoto photo) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('사진 삭제'),
        content: const Text('이 사진을 삭제할까요?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('취소')),
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: const Text('삭제',
                  style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (ok != true) return;
    final deleted = provider.deletePhoto(photo.id);
    if (!mounted) return;
    if (!deleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('사진을 삭제할 수 없습니다. 본인 사진이거나 운영진만 삭제할 수 있습니다'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _syncFromProvider(provider));
    if (_photos.isEmpty) {
      Navigator.pop(context);
      return;
    }
    if (_controller.hasClients) {
      _controller.jumpToPage(_current);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ClubProvider>(
      builder: (context, provider, _) {
        final live = provider.photosOf(widget.scheduleId);
        final liveKey = live.map((p) => p.id).join('|');
        final localKey = _photos.map((p) => p.id).join('|');
        if (liveKey != localKey) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() => _syncFromProvider(provider));
            if (_photos.isEmpty) {
              Navigator.pop(context);
            } else if (_controller.hasClients) {
              _controller.jumpToPage(_current);
            }
          });
        }
        if (_photos.isEmpty) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: SizedBox.shrink(),
          );
        }
        final safeIndex = _current.clamp(0, _photos.length - 1);
        final photo = _photos[safeIndex];
        return Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
            title: Text(
              '\${safeIndex + 1} / \${_photos.length}',
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            centerTitle: true,
            actions: [
              if (provider.canDeletePhoto(photo) || provider.isOwnPhoto(photo))
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (provider.isOwnPhoto(photo))
                      IconButton(
                        icon: const Icon(Icons.edit_outlined,
                            color: Colors.white70),
                        onPressed: () =>
                            _editCaption(context, provider, photo),
                      ),
                    if (provider.canDeletePhoto(photo))
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.white70),
                        onPressed: () =>
                            _confirmDelete(context, provider, photo),
                      ),
                  ],
                ),
            ],
          ),
          body: Stack(
            children: [
              PageView.builder(
                controller: _controller,
                itemCount: _photos.length,
                onPageChanged: (i) => setState(() => _current = i),
                itemBuilder: (_, i) => InteractiveViewer(
                  child: RoundPhotoView(
                    imageUrl: _photos[i].imageUrl,
                    fit: BoxFit.contain,
                    error: const Center(
                      child: Icon(Icons.broken_image_outlined,
                          color: Colors.white30, size: 60),
                    ),
                  ),
                ),
              ),
              if (photo.caption != null || photo.uploaderName.isNotEmpty)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.8),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(20, 30, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (photo.caption != null)
                          Text(
                            photo.caption!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        const SizedBox(height: 4),
                        Text(
                          '\${photo.uploaderName} · \${photo.takenAt.month}/\${photo.takenAt.day}',
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

`.replace(/\n/g, nl);

src = src.slice(0, start) + replacement + src.slice(end);
fs.writeFileSync(file, src, 'utf8');
console.log('Done', file);
