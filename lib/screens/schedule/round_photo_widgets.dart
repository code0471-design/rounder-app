import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../models/club_model.dart';
import '../../providers/club_provider.dart';
import '../../services/photo_compress_service.dart';
import '../../theme/app_theme.dart';

/// 한 번에 고를 수 있는 최대 장수. 원클럽과 같은 값.
const int roundPhotoMaxPickCount = PhotoCompressService.maxPickCount;

/// 여러 장 선택. Firestore 문서 한도 내로 들어가도록 압축.
///
/// 반환: (data URI 목록, 20장 초과 여부)
/// 초과 여부는 호출부가 얼럿을 띄우는 데 쓴다 — 예전엔 제한도 안내도 없었다.
Future<(List<String>, bool)> pickRoundPhotoDataUrls() async {
  final (jpegs, exceeded) = await PhotoCompressService.pickAndCompress();
  if (jpegs.isEmpty) return (const <String>[], exceeded);
  final out = <String>[
    for (final bytes in jpegs) 'data:image/jpeg;base64,${base64Encode(bytes)}',
  ];
  return (out, exceeded);
}

Future<String?> pickRoundPhotoDataUrl() async {
  final (list, _) = await pickRoundPhotoDataUrls();
  if (list.isEmpty) return null;
  return list.first;
}

/// 20장 초과 안내. 원클럽과 같은 문구를 쓴다.
Future<void> showRoundPhotoLimitAlert(BuildContext context) => showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('사진 선택 제한'),
        content: const Text(
          '한 번에 $roundPhotoMaxPickCount장까지 선택할 수 있습니다.\n'
          '$roundPhotoMaxPickCount장만 가져왔습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('확인'),
          ),
        ],
      ),
    );

class RoundPhotoView extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;
  final Widget? error;

  /// data URI 디코드 결과 캐시 — Consumer 재빌드 때 깜빡임 방지
  static final Map<String, Uint8List> _dataUrlCache = {};
  static const int _cacheMax = 48;

  const RoundPhotoView({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.error,
  });

  static Uint8List _cachedBytes(String dataUrl) {
    final key = '${dataUrl.length}_${dataUrl.hashCode}';
    final hit = _dataUrlCache[key];
    if (hit != null) return hit;
    final bytes = base64Decode(dataUrl.split(',').last);
    if (_dataUrlCache.length >= _cacheMax) {
      _dataUrlCache.remove(_dataUrlCache.keys.first);
    }
    _dataUrlCache[key] = bytes;
    return bytes;
  }

  @override
  Widget build(BuildContext context) {
    final fallback = error ??
        Container(
          color: AppColors.divider,
          child: const Icon(Icons.broken_image_outlined,
              color: AppColors.textSecondary),
        );

    if (imageUrl.startsWith('data:image')) {
      try {
        return Image.memory(
          _cachedBytes(imageUrl),
          fit: fit,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => fallback,
        );
      } catch (_) {
        return fallback;
      }
    }
    if (imageUrl.startsWith('http')) {
      return Image.network(
        imageUrl,
        fit: fit,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => fallback,
      );
    }
    if (!kIsWeb && imageUrl.isNotEmpty) {
      return Image.file(
        File(imageUrl),
        fit: fit,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => fallback,
      );
    }
    return fallback;
  }
}

class PhotoUploadSheet extends StatefulWidget {
  final RoundSchedule schedule;
  final ClubProvider provider;
  final String? initialDataUrl;
  final List<String>? initialDataUrls;

  const PhotoUploadSheet({
    super.key,
    required this.schedule,
    required this.provider,
    this.initialDataUrl,
    this.initialDataUrls,
  });

  @override
  State<PhotoUploadSheet> createState() => _PhotoUploadSheetState();
}

class _PhotoUploadSheetState extends State<PhotoUploadSheet> {
  final _captionCtrl = TextEditingController();
  late List<String> _pickedUrls;
  bool _picking = false;

  @override
  void initState() {
    super.initState();
    final fromList = widget.initialDataUrls ?? const <String>[];
    final fromSingle = widget.initialDataUrl;
    _pickedUrls = [
      ...fromList.where((u) => u.trim().isNotEmpty),
      if (fromSingle != null &&
          fromSingle.trim().isNotEmpty &&
          !fromList.contains(fromSingle))
        fromSingle,
    ];
  }

  @override
  void dispose() {
    _captionCtrl.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final (dataUrls, exceeded) = await pickRoundPhotoDataUrls();
      if (!mounted || dataUrls.isEmpty) return;
      if (exceeded) {
        await showRoundPhotoLimitAlert(context);
        if (!mounted) return;
      }
      setState(() {
        // 새로 고른 사진으로 교체 (여러 장 재선택)
        _pickedUrls = List<String>.from(dataUrls);
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사진을 불러오지 못했습니다')),
      );
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _removeAt(int index) {
    setState(() => _pickedUrls.removeAt(index));
  }

  void _upload() {
    if (_pickedUrls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('갤러리에서 사진을 먼저 선택해 주세요')),
      );
      return;
    }
    final count = _pickedUrls.length;
    widget.provider.addPhotos(
      scheduleId: widget.schedule.id,
      imageUrls: List<String>.from(_pickedUrls),
      caption: _captionCtrl.text,
    );
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(count == 1 ? '사진이 업로드되었습니다' : '사진 $count장이 업로드되었습니다'),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.add_photo_alternate_rounded, color: AppColors.primary),
              SizedBox(width: 10),
              Text('사진 업로드',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 16),
          Material(
            color: const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: _picking ? null : _pick,
              borderRadius: BorderRadius.circular(12),
              child: Ink(
                height: _pickedUrls.isEmpty ? 140 : null,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.divider),
                ),
                child: _picking
                    ? const SizedBox(
                        height: 140,
                        child: Center(
                            child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : _pickedUrls.isEmpty
                        ? const SizedBox(
                            height: 140,
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.photo_library_outlined,
                                      size: 32, color: AppColors.textSecondary),
                                  SizedBox(height: 6),
                                  Text(
                                    '갤러리에서 사진 선택 (여러 장 가능)',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : Padding(
                            padding: const EdgeInsets.all(8),
                            child: GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _pickedUrls.length,
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 6,
                                mainAxisSpacing: 6,
                              ),
                              itemBuilder: (context, index) {
                                return Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: RoundPhotoView(
                                        imageUrl: _pickedUrls[index],
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    Positioned(
                                      top: 2,
                                      right: 2,
                                      child: Material(
                                        color: Colors.black54,
                                        shape: const CircleBorder(),
                                        child: InkWell(
                                          customBorder: const CircleBorder(),
                                          onTap: () => _removeAt(index),
                                          child: const Padding(
                                            padding: EdgeInsets.all(4),
                                            child: Icon(Icons.close,
                                                size: 14, color: Colors.white),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _picking ? null : _pick,
              icon: const Icon(Icons.photo_library_outlined, size: 18),
              label: Text(_pickedUrls.isEmpty
                  ? '갤러리에서 여러 장 선택'
                  : '다시 선택 (${_pickedUrls.length}장)'),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _captionCtrl,
            decoration: InputDecoration(
              hintText: '사진 설명을 입력하세요 (선택, 전체 공통)',
              hintStyle: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _upload,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(44),
              ),
              child: Text(_pickedUrls.length <= 1
                  ? '업로드'
                  : '${_pickedUrls.length}장 업로드'),
            ),
          ),
        ],
      ),
    );
  }
}
