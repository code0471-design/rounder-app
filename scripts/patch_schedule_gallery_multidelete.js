/**
 * schedule gallery: multi-select delete + always return to album list after delete.
 * UTF-8 Node only.
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

const startMark = '// ── 일정 라운딩 사진첩 (전체보기) ──';
const endMark =
  '// ────────────────────────────────────────────────────────────' +
  nl +
  '//  조편성 진입 카드';
const start = src.indexOf(startMark);
const end = src.indexOf(endMark, start);
if (start < 0 || end < 0) {
  console.error('FAIL bounds');
  process.exit(1);
}

const replacement = `// ── 일정 라운딩 사진첩 (전체보기) ──
class _SchedulePhotoAlbumScreen extends StatefulWidget {
  final String scheduleId;
  final String title;
  final List<RoundPhoto> photos;
  const _SchedulePhotoAlbumScreen({
    required this.scheduleId,
    required this.title,
    required this.photos,
  });

  @override
  State<_SchedulePhotoAlbumScreen> createState() =>
      _SchedulePhotoAlbumScreenState();
}

class _SchedulePhotoAlbumScreenState extends State<_SchedulePhotoAlbumScreen> {
  bool _selecting = false;
  final Set<String> _selected = <String>{};

  void _toggleSelectMode() {
    setState(() {
      _selecting = !_selecting;
      if (!_selecting) _selected.clear();
    });
  }

  void _toggleId(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
  }

  Future<void> _deleteSelected(ClubProvider provider, List<RoundPhoto> live) async {
    final targets = live
        .where((p) => _selected.contains(p.id) && provider.canDeletePhoto(p))
        .map((p) => p.id)
        .toList();
    if (targets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('삭제할 수 있는 사진이 없습니다'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('사진 삭제'),
        content: Text('선택한 \${targets.length}장을 삭제할까요?'),
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
    if (ok != true || !mounted) return;
    final n = provider.deletePhotos(targets);
    if (!mounted) return;
    setState(() {
      _selected.clear();
      _selecting = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(n > 0 ? '\$n장 삭제했습니다' : '삭제하지 못했습니다'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ClubProvider>(
      builder: (context, provider, _) {
        final live = provider.photosOf(widget.scheduleId);
        final canBulk = live.any(provider.canDeletePhoto);
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: Icon(
                _selecting ? Icons.close : Icons.arrow_back_ios_new,
                size: 18,
                color: AppColors.textPrimary,
              ),
              onPressed: () {
                if (_selecting) {
                  _toggleSelectMode();
                } else {
                  Navigator.pop(context);
                }
              },
            ),
            title: Text(
              _selecting
                  ? '선택 \${_selected.length}장'
                  : '\${widget.title} · \${live.length}장',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            actions: [
              if (live.isNotEmpty && canBulk)
                TextButton(
                  onPressed: _toggleSelectMode,
                  child: Text(
                    _selecting ? '취소' : '선택',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              if (_selecting && _selected.isNotEmpty)
                TextButton(
                  onPressed: () => _deleteSelected(provider, live),
                  child: const Text(
                    '삭제',
                    style: TextStyle(
                      color: AppColors.danger,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
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
                    final selected = _selected.contains(photo.id);
                    return GestureDetector(
                      onTap: () {
                        if (_selecting) {
                          if (!provider.canDeletePhoto(photo)) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('이 사진은 삭제할 수 없습니다'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                            return;
                          }
                          _toggleId(photo.id);
                          return;
                        }
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => _SchedulePhotoViewer(
                              scheduleId: widget.scheduleId,
                              photos: live,
                              initialIndex: index,
                            ),
                          ),
                        );
                      },
                      onLongPress: () {
                        if (!provider.canDeletePhoto(photo)) return;
                        if (!_selecting) {
                          setState(() {
                            _selecting = true;
                            _selected
                              ..clear()
                              ..add(photo.id);
                          });
                        } else {
                          _toggleId(photo.id);
                        }
                      },
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: RoundPhotoView(imageUrl: photo.imageUrl),
                          ),
                          if (_selecting)
                            Positioned(
                              top: 6,
                              right: 6,
                              child: Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: selected
                                      ? AppColors.primary
                                      : Colors.black45,
                                  border: Border.all(
                                      color: Colors.white, width: 1.5),
                                ),
                                child: selected
                                    ? const Icon(Icons.check,
                                        size: 14, color: Colors.white)
                                    : null,
                              ),
                            ),
                        ],
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
    // 삭제 후 목록(앨범)으로 복귀
    Navigator.pop(context);
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
console.log('Done');
