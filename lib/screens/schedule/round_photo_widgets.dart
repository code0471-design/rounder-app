import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/club_model.dart';
import '../../providers/club_provider.dart';
import '../../theme/app_theme.dart';

Future<String?> pickRoundPhotoDataUrl() async {
  final picked = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: 1600,
    imageQuality: 85,
    requestFullMetadata: false,
  );
  if (picked == null) return null;
  final bytes = await picked.readAsBytes();
  return 'data:image/jpeg;base64,${base64Encode(bytes)}';
}

class RoundPhotoView extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;
  final Widget? error;

  const RoundPhotoView({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.error,
  });

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
        final b64 = imageUrl.split(',').last;
        return Image.memory(base64Decode(b64), fit: fit, errorBuilder: (_, __, ___) => fallback);
      } catch (_) {
        return fallback;
      }
    }
    if (imageUrl.startsWith('http')) {
      return Image.network(imageUrl, fit: fit, errorBuilder: (_, __, ___) => fallback);
    }
    if (!kIsWeb && imageUrl.isNotEmpty) {
      return Image.file(File(imageUrl), fit: fit, errorBuilder: (_, __, ___) => fallback);
    }
    return fallback;
  }
}

class PhotoUploadSheet extends StatefulWidget {
  final RoundSchedule schedule;
  final ClubProvider provider;
  final String? initialDataUrl;

  const PhotoUploadSheet({
    super.key,
    required this.schedule,
    required this.provider,
    this.initialDataUrl,
  });

  @override
  State<PhotoUploadSheet> createState() => _PhotoUploadSheetState();
}

class _PhotoUploadSheetState extends State<PhotoUploadSheet> {
  final _captionCtrl = TextEditingController();
  String? _pickedUrl;
  bool _picking = false;

  @override
  void initState() {
    super.initState();
    _pickedUrl = widget.initialDataUrl;
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
      final dataUrl = await pickRoundPhotoDataUrl();
      if (!mounted || dataUrl == null) return;
      setState(() => _pickedUrl = dataUrl);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사진을 불러오지 못했습니다')),
      );
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _upload() {
    if (_pickedUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('갤러리에서 사진을 먼저 선택해 주세요')),
      );
      return;
    }
    widget.provider.addPhoto(
      scheduleId: widget.schedule.id,
      caption: _captionCtrl.text,
      imageUrl: _pickedUrl,
    );
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(
      SnackBar(
        content: const Text('사진이 업로드되었습니다'),
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
                height: 140,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.divider),
                ),
                child: _picking
                    ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                    : _pickedUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: RoundPhotoView(
                                imageUrl: _pickedUrl!, fit: BoxFit.cover),
                          )
                        : const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.photo_library_outlined,
                                    size: 32, color: AppColors.textSecondary),
                                SizedBox(height: 6),
                                Text(
                                  '갤러리에서 사진 선택',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary),
                                ),
                              ],
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
              label: Text(_pickedUrl == null ? '갤러리에서 선택' : '다른 사진 선택'),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _captionCtrl,
            decoration: InputDecoration(
              hintText: '사진 설명을 입력하세요 (선택)',
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
              child: const Text('업로드'),
            ),
          ),
        ],
      ),
    );
  }
}
