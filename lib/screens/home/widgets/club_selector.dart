import 'package:flutter/material.dart';
import '../../../models/club_model.dart';
import '../../../theme/app_theme.dart';

class ClubSelector extends StatelessWidget {
  final List<Club> clubs;
  final int selectedIndex;
  final Function(int) onClubSelected;

  const ClubSelector({
    super.key,
    required this.clubs,
    required this.selectedIndex,
    required this.onClubSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 8),
          child: Text(
            '내 모임',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: clubs.length + 1,
            itemBuilder: (context, index) {
              if (index == clubs.length) {
                return _buildAddButton(context);
              }
              return _buildClubItem(context, clubs[index], index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildClubItem(BuildContext context, Club club, int index) {
    final isSelected = index == selectedIndex;
    return GestureDetector(
      onTap: () => onClubSelected(index),
      child: Container(
        width: 68,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.2),
                border: isSelected
                    ? Border.all(color: AppColors.accent, width: 2.5)
                    : null,
              ),
              child: Center(
                child: Text(
                  _getClubEmoji(club.name),
                  style: const TextStyle(fontSize: 22),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              club.name.length > 5
                  ? '${club.name.substring(0, 5)}...'
                  : club.name,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.7),
                fontSize: 10,
                fontWeight:
                    isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddButton(BuildContext context) {
    return Container(
      width: 68,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.4),
                width: 1.5,
                strokeAlign: BorderSide.strokeAlignInside,
              ),
              color: Colors.white.withValues(alpha: 0.1),
            ),
            child: Icon(
              Icons.add,
              color: Colors.white.withValues(alpha: 0.7),
              size: 22,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '모임 추가',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _getClubEmoji(String name) {
    if (name.contains('강남')) return '🏌️';
    if (name.contains('시흘') || name.contains('CC')) return '⛳';
    if (name.contains('주말')) return '🏆';
    if (name.contains('총무')) return '👑';
    return '⛳';
  }
}
