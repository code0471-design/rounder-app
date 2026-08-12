import 'package:flutter/material.dart';

/// ROUNDER 공식 로고 — 투명 PNG 전용 (화이트 박스 없음)
class RounderLogo extends StatelessWidget {
  static const assetPath = 'assets/images/KakaoTalk_20260724_132326103.png';
  static const transparentAssetPath =
      'assets/images/rounder_logo_transparent.png';
  static const verticalAssetPath =
      'assets/images/rounder_intro_logo.png';
  static const verticalFallbackAssetPath =
      'assets/images/KakaoTalk_20260724_131658153.png';
  static const verticalTransparentAssetPath =
      'assets/images/rounder_logo_vertical_transparent.png';
  static const headerAssetPath = 'assets/images/rounder_logo_header.png';

  final double height;
  final double? width;
  final VoidCallback? onTap;

  /// 딥그린(#1B4D3E) 헤더용
  final bool forHeader;

  /// 화이트(#FFFFFF) 헤더용 — 크롭된 투명 PNG
  final bool forWhiteHeader;

  /// 인트로용 세로형 로고
  final bool vertical;

  const RounderLogo({
    super.key,
    this.height = 36,
    this.width,
    this.onTap,
    this.forHeader = false,
    this.forWhiteHeader = false,
    this.vertical = false,
  });

  String get _assetPath {
    // 세로형: 골프공 디테일 포함 원본 (transparent 버전은 링만 있음)
    if (vertical) return verticalAssetPath;
    if (forWhiteHeader) return transparentAssetPath;
    if (forHeader) return headerAssetPath;
    return assetPath;
  }

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      _assetPath,
      height: height,
      width: width,
      fit: BoxFit.contain,
      alignment: vertical ? Alignment.center : Alignment.centerLeft,
      filterQuality: FilterQuality.high,
      gaplessPlayback: true,
      isAntiAlias: true,
      excludeFromSemantics: true,
      errorBuilder: (_, __, ___) {
        final fallback = vertical
            ? verticalFallbackAssetPath
            : (forHeader ? headerAssetPath : assetPath);
        return Image.asset(
          fallback,
          height: height,
          width: width,
          fit: BoxFit.contain,
          alignment: vertical ? Alignment.center : Alignment.centerLeft,
          filterQuality: FilterQuality.high,
        );
      },
    );

    final logo = ClipRect(
      child: vertical
          ? SizedBox(
              height: height,
              width: width,
              child: Center(child: image),
            )
          : SizedBox(
              height: height,
              child: image,
            ),
    );

    if (onTap == null) return logo;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.deferToChild,
      child: logo,
    );
  }
}
