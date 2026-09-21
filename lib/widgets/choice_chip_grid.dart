import 'package:flutter/material.dart';

/// 지역·업종 칩. 한 줄에 4칸으로 맞춰 들쑥날쑥하지 않게 한다.
class ChoiceChipGrid extends StatelessWidget {
  static const columns = 4;

  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelected;
  final Color selectedColor;
  final Color selectedTextColor;
  final Color borderColor;
  final Color textColor;

  const ChoiceChipGrid({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.selectedColor = const Color(0xFF191F28),
    this.selectedTextColor = Colors.white,
    this.borderColor = const Color(0xFFE5E8EB),
    this.textColor = const Color(0xFF6B7684),
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 8.0;
        final cellW =
            (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final label in options)
              SizedBox(
                width: cellW,
                child: Material(
                  color: label == selected ? selectedColor : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    onTap: () => onSelected(label),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: label == selected
                              ? selectedColor
                              : borderColor,
                        ),
                      ),
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.2,
                          fontWeight: FontWeight.w600,
                          color: label == selected
                              ? selectedTextColor
                              : textColor,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
