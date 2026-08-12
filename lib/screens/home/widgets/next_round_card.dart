import 'package:flutter/material.dart';
import '../../../models/club_model.dart';
import '../../../theme/app_theme.dart';
import 'package:intl/intl.dart';

class NextRoundCard extends StatelessWidget {
  final Club club;

  const NextRoundCard({super.key, required this.club});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // D-day 카드
        Expanded(
          flex: 3,
          child: _buildDDayCard(),
        ),
        const SizedBox(width: 12),
        // 날씨 카드
        Expanded(
          flex: 2,
          child: _buildWeatherCard(),
        ),
      ],
    );
  }

  Widget _buildDDayCard() {
    final days = club.daysUntilNextRound;
    final dDayText = days == 0 ? 'D-Day!' : 'D-$days';
    final dateText = club.nextRoundDate != null
        ? DateFormat('M월 d일 EEEE', 'ko').format(club.nextRoundDate!)
        : '일정 없음';

    return Container(
      height: 130,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryLight, AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // 배경 장식
          Positioned(
            right: -10,
            top: -10,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '다음 라운딩까지',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                // D-day 골드 배지
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const RadialGradient(
                        colors: [Color(0xFFFFD54F), AppColors.gold],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.gold.withValues(alpha: 0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        dDayText,
                        style: TextStyle(
                          color: const Color(0xFF3E2000),
                          fontSize: days > 9 ? 18 : 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dateText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (club.nextRoundCourse != null)
                      Text(
                        club.nextRoundCourse!,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 10,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherCard() {
    return Container(
      height: 130,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            '☀️',
            style: TextStyle(fontSize: 36),
          ),
          const SizedBox(height: 4),
          const Text(
            '맑음',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            '18°C',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '라운딩 당일',
            style: TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}
