import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/club_model.dart';
import '../theme/app_theme.dart';

/// 모임 이름 앞 사각 마크. 원클럽과 같은 80 기준 흰 바탕 + 1.5px 테두리.
class ClubCoverMark extends StatelessWidget {
  final Club club;
  final double size;

  const ClubCoverMark({
    super.key,
    required this.club,
    this.size = 80,
  });

  @override
  Widget build(BuildContext context) {
    final radius = (size * 0.175).clamp(8.0, 14.0);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: const Color(0xFF111827), width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius - 1),
        child: _image() ?? _fallback(),
      ),
    );
  }

  Widget? _image() {
    final url = club.imageUrl?.trim() ?? '';
    if (url.startsWith('data:image')) {
      try {
        return Image.memory(
          base64Decode(url.split(',').last),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback(),
        );
      } catch (_) {
        return _fallback();
      }
    }
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallback(),
      );
    }
    return null;
  }

  Widget _fallback() {
    return ColoredBox(
      color: Colors.white,
      child: Center(
        child: Icon(
          Icons.golf_course_rounded,
          size: size * 0.42,
          color: AppColors.primary,
        ),
      ),
    );
  }
}
