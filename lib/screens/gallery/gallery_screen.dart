import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/club_model.dart';
import '../../providers/club_provider.dart';
import '../../theme/app_theme.dart';
import '../schedule/round_photo_widgets.dart';

// ════════════════════════════════════════════════════════════
//  GalleryScreen — 모임 사진 갤러리 (네이버 밴드 스타일)
//  · 상단: 전체 사진 4×3 그리드 미리보기 + "전체보기" 토글
//  · 하단: 라운드별 폴더 뷰
// ════════════════════════════════════════════════════════════
class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen>
    with AutomaticKeepAliveClientMixin {
  /// 최근 사진 미리보기: 4열 × 3줄
  static const int _previewRows = 3;
  static const int _cols = 4;
  static const int _previewCount = _cols * _previewRows; // 12

  @override
  bool get wantKeepAlive => true;

  /// 사진·일정 id가 같을 때 Consumer 재빌드로 깜빡이지 않게 하는 시그니처
  static String _gallerySignature(ClubProvider p) {
    final photos = p.clubPhotos;
    final schedules = p.schedules;
    final photoPart = photos
        .map((x) => '${x.id}:${x.imageUrl.length}:${x.caption ?? ''}')
        .join(',');
    final schedPart =
        schedules.map((s) => '${s.id}:${s.displayTitle}').join(',');
    return '${photos.length}|$photoPart|$schedPart';
  }

  /// 같은 제목·같은(또는 ±1일) 날짜 일정이 여러 개면 앨범 하나로 합친다.
  /// UTC/로컬 변환으로 하루 밀린 중복 일정을 흡수한다.
  List<_GalleryAlbum> _buildAlbums(
    List<RoundSchedule> schedules,
    List<RoundPhoto> allPhotos,
  ) {
    final byTitle = <String, List<RoundSchedule>>{};
    for (final s in schedules) {
      (byTitle[s.displayTitle.trim()] ??= []).add(s);
    }

    final albums = <_GalleryAlbum>[];
    for (final entry in byTitle.entries) {
      final sorted = List<RoundSchedule>.from(entry.value)
        ..sort((a, b) => a.roundDate.compareTo(b.roundDate));

      final clusters = <List<RoundSchedule>>[];
      for (final s in sorted) {
        final day = DateTime(
            s.roundDate.year, s.roundDate.month, s.roundDate.day);
        if (clusters.isEmpty) {
          clusters.add([s]);
          continue;
        }
        final last = clusters.last;
        final lastDay = DateTime(last.last.roundDate.year,
            last.last.roundDate.month, last.last.roundDate.day);
        final diff = day.difference(lastDay).inDays.abs();
        if (diff <= 1) {
          last.add(s);
        } else {
          clusters.add([s]);
        }
      }

      for (final group in clusters) {
        final ids = group.map((s) => s.id).toSet();
        final photos = allPhotos
            .where((p) => ids.contains(p.scheduleId))
            .toList()
          ..sort((a, b) => b.takenAt.compareTo(a.takenAt));

        group.sort((a, b) {
          final pa = photos.where((p) => p.scheduleId == a.id).length;
          final pb = photos.where((p) => p.scheduleId == b.id).length;
          if (pa != pb) return pb.compareTo(pa);
          if (a.responses.length != b.responses.length) {
            return b.responses.length.compareTo(a.responses.length);
          }
          return b.id.compareTo(a.id);
        });

        final canonical = group.first;
        final d = canonical.roundDate;
        final folderId =
            '${entry.key}|${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
        albums.add(_GalleryAlbum(
          schedule: canonical,
          photos: photos,
          folderId: folderId,
        ));
      }
    }

    albums.sort(
        (a, b) => b.schedule.roundDate.compareTo(a.schedule.roundDate));
    return albums;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Selector<ClubProvider, String>(
      selector: (_, p) => _gallerySignature(p),
      builder: (context, _, __) {
        final provider = context.read<ClubProvider>();
        final allPhotos = provider.clubPhotos;
        final albums = _buildAlbums(provider.schedules, allPhotos);

        return Scaffold(
          backgroundColor: AppColors.background,
          body: allPhotos.isEmpty && albums.isEmpty
              ? const _EmptyGallery(hasPastSchedules: false)
              : CustomScrollView(
                  slivers: [
                    if (allPhotos.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: _SectionHeader(
                          title: '전체 사진',
                          count: allPhotos.length,
                          trailing: allPhotos.isNotEmpty
                              ? GestureDetector(
                                  onTap: () =>
                                      _openAllPhotos(context, allPhotos),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '전체보기',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Icon(
                                        Icons.chevron_right_rounded,
                                        size: 16,
                                        color: AppColors.primary,
                                      ),
                                    ],
                                  ),
                                )
                              : null,
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: _buildAllPhotosGrid(allPhotos),
                      ),
                    ],
                    if (albums.isNotEmpty)
                      SliverToBoxAdapter(
                        child: _SectionHeader(
                          title: '라운딩별 앨범',
                          count: albums.length,
                        ),
                      ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final album = albums[index];
                          return _RoundFolder(
                            key: ValueKey(album.folderId),
                            schedule: album.schedule,
                            photos: album.photos,
                            onOpen: () => _openAlbum(context, album),
                          );
                        },
                        childCount: albums.length,
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  ],
                ),
        );
      },
    );
  }

  // ── 전체 사진 그리드 빌드 (최근 3줄만) ──
  Widget _buildAllPhotosGrid(List<RoundPhoto> allPhotos) {
    final displayPhotos = allPhotos.take(_previewCount).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      child: Column(
        children: [
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: _cols,
              crossAxisSpacing: 3,
              mainAxisSpacing: 3,
            ),
            itemCount: displayPhotos.length,
            itemBuilder: (context, index) {
              return _PhotoTile(
                photo: displayPhotos[index],
                onTap: () => _openPhoto(context, allPhotos,
                    allPhotos.indexOf(displayPhotos[index])),
              );
            },
          ),
          if (allPhotos.isNotEmpty)
            GestureDetector(
              onTap: () => _openAllPhotos(context, allPhotos),
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 3),
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.photo_library_outlined,
                        size: 16, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(
                      '전체보기 (${allPhotos.length}장)',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right_rounded,
                        size: 16, color: AppColors.primary),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  void _openPhoto(
      BuildContext context, List<RoundPhoto> photos, int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            _PhotoViewerScreen(photos: photos, initialIndex: index),
      ),
    );
  }

  void _openAllPhotos(BuildContext context, List<RoundPhoto> photos) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _AllPhotosScreen(photos: photos),
      ),
    );
  }

  void _openAlbum(BuildContext context, _GalleryAlbum album) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _RoundAlbumScreen(album: album),
      ),
    );
  }
}

class _GalleryAlbum {
  final RoundSchedule schedule;
  final List<RoundPhoto> photos;
  final String folderId;

  const _GalleryAlbum({
    required this.schedule,
    required this.photos,
    required this.folderId,
  });
}

/// 전체 사진 그리드 화면 (전체보기)
class _AllPhotosScreen extends StatelessWidget {
  final List<RoundPhoto> photos;

  const _AllPhotosScreen({required this.photos});

  @override
  Widget build(BuildContext context) {
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
          '전체 사진 · ${photos.length}장',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 4,
          mainAxisSpacing: 4,
        ),
        itemCount: photos.length,
        itemBuilder: (context, index) {
          return _PhotoTile(
            photo: photos[index],
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => _PhotoViewerScreen(
                    photos: photos,
                    initialIndex: index,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  섹션 헤더
// ════════════════════════════════════════════════════════════
class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final Widget? trailing;

  const _SectionHeader({
    required this.title,
    required this.count,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    // gal-section-title: 3px bar + 제목 + 카운트 배지
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
      child: Row(
        children: [
          // 3px 수직 바
          Container(
            width: 3, height: 14,
            decoration: BoxDecoration(
              color: AppColors.sageDeep,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'NanumGothic',
              fontSize: 17, fontWeight: FontWeight.w500,
              color: AppColors.sageDarker,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.cream2,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                fontSize: 10, fontWeight: FontWeight.w700,
                color: AppColors.sageDeep, letterSpacing: 0.5,
              ),
            ),
          ),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  라운드별 앨범 행 — 탭하면 사진첩 화면으로 이동
// ════════════════════════════════════════════════════════════
class _RoundFolder extends StatelessWidget {
  final RoundSchedule schedule;
  final List<RoundPhoto> photos;
  final VoidCallback onOpen;

  const _RoundFolder({
    super.key,
    required this.schedule,
    required this.photos,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: _buildFolderThumb(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      schedule.displayTitle,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatDate(schedule.roundDate),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.mintBadge,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  '${photos.length}장',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFolderThumb() {
    if (photos.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: RoundPhotoView(
          imageUrl: photos.first.imageUrl,
          fit: BoxFit.cover,
          error: const Center(
            child: Icon(Icons.photo_album_outlined,
                color: AppColors.primary, size: 22),
          ),
        ),
      );
    }
    return const Center(
      child: Icon(Icons.photo_album_outlined,
          color: AppColors.primary, size: 22),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
  }
}

/// 라운딩별 사진첩 (모임명 탭 진입)
class _RoundAlbumScreen extends StatelessWidget {
  final _GalleryAlbum album;

  const _RoundAlbumScreen({required this.album});

  @override
  Widget build(BuildContext context) {
    final photos = album.photos;
    final d = album.schedule.roundDate;
    final dateLabel =
        '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';

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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              album.schedule.displayTitle,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              '$dateLabel · ${photos.length}장',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
      body: photos.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.photo_album_outlined,
                      size: 48, color: AppColors.textSecondary),
                  SizedBox(height: 12),
                  Text('아직 사진이 없습니다',
                      style: TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              itemCount: photos.length,
              itemBuilder: (context, index) {
                return _PhotoTile(
                  photo: photos[index],
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => _PhotoViewerScreen(
                          photos: photos,
                          initialIndex: index,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  사진 타일
// ════════════════════════════════════════════════════════════
class _PhotoTile extends StatelessWidget {
  final RoundPhoto photo;
  final VoidCallback onTap;

  const _PhotoTile({required this.photo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Hero(
        tag: 'photo_${photo.id}',
        child: Container(
          key: ValueKey('thumb_${photo.id}'),
          decoration: const BoxDecoration(
            color: AppColors.divider,
          ),
          child: RoundPhotoView(
            imageUrl: photo.imageUrl,
            fit: BoxFit.cover,
            error: const Center(
              child: Icon(Icons.broken_image_outlined,
                  color: AppColors.textSecondary),
            ),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  빈 갤러리 상태
// ════════════════════════════════════════════════════════════
class _EmptyGallery extends StatelessWidget {
  final bool hasPastSchedules;
  const _EmptyGallery({required this.hasPastSchedules});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.photo_library_outlined,
                size: 40, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          const Text('아직 사진이 없습니다',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Text(
            hasPastSchedules
                ? '일정 상세에서 사진을 올려 보세요!'
                : '라운딩 일정에서 사진을 올려 추억을 기록하세요!',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 13, color: AppColors.textSecondary, height: 1.5),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  사진 뷰어 (풀스크린 슬라이더)
// ════════════════════════════════════════════════════════════
class _PhotoViewerScreen extends StatefulWidget {
  final List<RoundPhoto> photos;
  final int initialIndex;

  const _PhotoViewerScreen(
      {required this.photos, required this.initialIndex});

  @override
  State<_PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<_PhotoViewerScreen> {
  late PageController _pageController;
  late int _current;
  late List<RoundPhoto> _photos;
  bool _showInfo = true;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _photos = List<RoundPhoto>.from(widget.photos);
    _pageController = PageController(initialPage: _current);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photo = _photos[_current];

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── 이미지 슬라이더 ──
          GestureDetector(
            onTap: () => setState(() => _showInfo = !_showInfo),
            child: PageView.builder(
              controller: _pageController,
              itemCount: _photos.length,
              onPageChanged: (i) => setState(() => _current = i),
              itemBuilder: (_, i) {
                final p = _photos[i];
                return Hero(
                  tag: 'photo_${p.id}',
                  child: InteractiveViewer(
                    child: RoundPhotoView(
                      imageUrl: p.imageUrl,
                      fit: BoxFit.contain,
                      error: const Center(
                        child: Icon(Icons.broken_image_outlined,
                            color: Colors.white30, size: 60),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // ── 상단 앱바 ──
          AnimatedOpacity(
            opacity: _showInfo ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.7),
                    Colors.transparent,
                  ],
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back,
                            color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Text(
                          '${_current + 1} / ${_photos.length}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                      Consumer<ClubProvider>(
                        builder: (_, provider, __) {
                          final isOwn = provider.isOwnPhoto(photo);
                          if (!isOwn) return const SizedBox(width: 48);
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined,
                                    color: Colors.white70),
                                onPressed: () =>
                                    _editCaption(context, provider, photo),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: Colors.white70),
                                onPressed: () =>
                                    _confirmDelete(context, provider, photo),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── 하단 캡션 & 정보 ──
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AnimatedOpacity(
              opacity: _showInfo ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.75),
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
                            height: 1.4),
                      ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.person_outline,
                            color: Colors.white60, size: 13),
                        const SizedBox(width: 4),
                        Text(
                          photo.uploaderName,
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 12),
                        ),
                        const SizedBox(width: 12),
                        const Icon(Icons.schedule,
                            color: Colors.white60, size: 13),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(photo.takenAt),
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 12),
                        ),
                      ],
                    ),
                    if (widget.photos.length > 1) ...[
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          widget.photos.length.clamp(0, 10),
                          (i) => Container(
                            width: i == _current ? 16 : 6,
                            height: 6,
                            margin:
                                const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              color: i == _current
                                  ? Colors.white
                                  : Colors.white38,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
  }

  Future<void> _editCaption(
      BuildContext context, ClubProvider provider, RoundPhoto photo) async {
    final ctrl = TextEditingController(text: photo.caption ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('사진 설명 수정',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '설명을 입력하세요',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('저장',
                  style: TextStyle(color: AppColors.primary))),
        ],
      ),
    );
    if (ok == true) {
      provider.updatePhotoCaption(photo.id, ctrl.text);
      if (!mounted) return;
      final idx = provider.clubPhotos.indexWhere((p) => p.id == photo.id);
      setState(() {
        if (idx != -1) _photos[_current] = provider.clubPhotos[idx];
      });
    }
  }

  Future<void> _confirmDelete(
      BuildContext context, ClubProvider provider, RoundPhoto photo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('사진 삭제',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: const Text('이 사진을 삭제하시겠습니까?\n삭제 후 복구할 수 없습니다.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('삭제',
                  style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (confirmed == true) {
      final ok = provider.deletePhoto(photo.id);
      if (!context.mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('본인이 올린 사진만 삭제할 수 있습니다'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      Navigator.pop(context);
    }
  }
}
