import 'package:flutter/material.dart';

/// 푸시/사이드바용 — 글씨·사각 박스 없는 골프공 아이콘만
class RounderAppIcon extends StatelessWidget {
  final double size;
  final Color? backgroundColor;

  const RounderAppIcon({
    super.key,
    this.size = 36,
    this.backgroundColor,
  });

  /// 텍스트 없는 정사각 앱 아이콘 (흰 배경은 ClipOval로 원형만 남김)
  static const assetPath = 'assets/icons/app_icon.png';

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: ColoredBox(
          color: backgroundColor ?? Colors.white,
          child: Image.asset(
            assetPath,
            width: size,
            height: size,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
            errorBuilder: (_, __, ___) => ColoredBox(
              color: const Color(0xFF1B4D3E),
              child: Icon(
                Icons.sports_golf,
                size: size * 0.55,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
