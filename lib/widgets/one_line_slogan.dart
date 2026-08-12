import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// 화면 너비에 맞춰 한 줄로 축소되는 슬로건 (오버플로우 방지)
class OneLineSlogan extends StatelessWidget {
  final String text;
  final TextStyle style;
  final Alignment alignment;

  const OneLineSlogan({
    super.key,
    required this.text,
    this.style = const TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      color: AppColors.textOnDark,
      letterSpacing: -0.15,
      height: 1.0,
    ),
    this.alignment = Alignment.centerLeft,
  });

  @override
  Widget build(BuildContext context) {
    final lineHeight = (style.fontSize ?? 20) * (style.height ?? 1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          height: lineHeight + 1,
          width: constraints.maxWidth,
          child: ClipRect(
            child: Align(
              alignment: alignment,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: alignment,
                child: Text(
                  text,
                  maxLines: 1,
                  softWrap: false,
                  style: style.copyWith(height: 1.0),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
