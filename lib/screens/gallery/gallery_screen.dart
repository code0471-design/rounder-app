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

class _GalleryScreenState extends State<GalleryScreen> {
  bool _showAllPhotos = false; // 전체보기 토글
  String? _expandedFolderId; // 펼쳐진 폴더 ID

  static const int _previewRows = 3;
  static const int _cols = 4;
  static const int _previewCount = _cols * _previewRows; // 12

  @override
  Widget build(BuildContext context) {
    return Consumer<ClubProvider>(
      builder: (context, provider, _) {
        final allPhotos = provider.clubPhotos;
        final albumSchedules = provider.schedules;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: allPhotos.isEmpty && albumSchedules.isEmpty
              ? const _EmptyGallery(hasPastSchedules: false)
              : CustomScrollView(
                  slivers: [
                    if (allPhotos.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: _SectionHeader(
                          title: '전체 사진',
                          count: allPhotos.length,
                          trailing: allPhotos.length > _previewCount
                              ? GestureDetector(
                                  onTap: () => setState(
                                      () => _showAllPhotos = !_showAllPhotos),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _showAllPhotos ? '접기' : '전체보기',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Icon(
                                        _showAllPhotos
                                            ? Icons.keyboard_arrow_up
                                            : Icons.keyboard_arrow_down,
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
                    if (albumSchedules.isNotEmpty)
                      SliverToBoxAdapter(
                        child: _SectionHeader(
                          title: '라운딩별 앨범',
                          count: albumSchedules.length,
                        ),
                      ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final schedule = albumSchedules[index];
                          final photos = allPhotos
                              .where((p) => p.scheduleId == schedule.id)
                              .toList();
                          final isExpanded =
                              _expandedFolderId == schedule.id;
                          return _RoundFolder(
                            schedule: schedule,
                            photos: photos,
                            isExpanded: isExpanded,
                            onToggle: () => setState(() {
                              _expandedFolderId =
                                  isExpanded ? null : schedule.id;
                            }),
                            onPhotoTap: (idx) =>
                                _openPhoto(context, photos, idx),
                          );
                        },
                        childCount: albumSchedules.length,
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  ],
                ),
        );
      },
    );
  }

  // ── 전체 사진 그리드 빌드 ──
  Widget _buildAllPhotosGrid(List<RoundPhoto> allPhotos) {
    final displayPhotos = _showAllPhotos
        ? allPhotos
        : allPhotos.take(_previewCount).toList();

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

          // "전체보기" 버튼 (접혀있고 더 있을 때)
          if (!_showAllPhotos && allPhotos.length > _previewCount)
            GestureDetector(
              onTap: () => setState(() => _showAllPhotos = true),
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
                      '전체 ${allPhotos.length}장 보기',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.keyboard_arrow_down,
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
//  라운드별 폴더 위젯 (네이버 밴드 스타일)
// ════════════════════════════════════════════════════════════
class _RoundFolder extends StatelessWidget {
  final RoundSchedule schedule;
  final List<RoundPhoto> photos;
  final bool isExpanded;
  final VoidCallback onToggle;
  final void Function(int index) onPhotoTap;

  const _RoundFolder({
    required this.schedule,
    required this.photos,
    required this.isExpanded,
    required this.onToggle,
    required this.onPhotoTap,
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
      child: Column(
        children: [
          // ── 폴더 헤더 ──
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(14),
              bottom: isExpanded
                  ? Radius.zero
                  : const Radius.circular(14),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
              child: Row(
                children: [
                  // 폴더 아이콘
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
                  // 제목 + 날짜
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
                  // 사진 수 배지 — 민트 캡슐
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
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
                  // 접기/펼치기 화살표
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.keyboard_arrow_down,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── 펼쳐진 사진 그리드 ──
          if (isExpanded) ...[
            Container(
              height: 1,
              color: AppColors.divider,
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 3,
                  mainAxisSpacing: 3,
                ),
                itemCount: photos.length,
                itemBuilder: (context, index) => _PhotoTile(
                  photo: photos[index],
                  onTap: () => onPhotoTap(index),
                ),
              ),
            ),
          ],
        ],
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
  bool _showInfo = true;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _pageController = PageController(initialPage: _current);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photo = widget.photos[_current];

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── 이미지 슬라이더 ──
          GestureDetector(
            onTap: () => setState(() => _showInfo = !_showInfo),
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.photos.length,
              onPageChanged: (i) => setState(() => _current = i),
              itemBuilder: (_, i) {
                final p = widget.photos[i];
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
                          '${_current + 1} / ${widget.photos.length}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                      Consumer<ClubProvider>(
                        builder: (_, provider, __) {
                          final isOwn =
                              photo.uploaderId == provider.currentUserId;
                          return isOwn
                              ? IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      color: Colors.white70),
                                  onPressed: () =>
                                      _confirmDelete(context, provider, photo),
                                )
                              : const SizedBox(width: 48);
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
      provider.deletePhoto(photo.id);
      if (context.mounted) Navigator.pop(context);
    }
  }
}
