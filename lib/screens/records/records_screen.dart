import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class RecordsScreen extends StatelessWidget {
  const RecordsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('기록', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 최근 라운딩
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text('최근 라운딩',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          _buildRoundCard(
            date: '2024년 5월 11일',
            course: '레이크사이드CC',
            winner: '홍길동',
            score: '78타',
            awards: [
              {'name': '베스트 스코어', 'winner': '홍길동 (78타)'},
              {'name': '니어리스트', 'winner': '김철수 (홀4)'},
              {'name': '롱기스트', 'winner': '박민준 (홀7)'},
            ],
          ),
          const SizedBox(height: 12),
          _buildRoundCard(
            date: '2024년 4월 13일',
            course: '블루원CC',
            winner: '이영희',
            score: '82타',
            awards: [
              {'name': '베스트 스코어', 'winner': '이영희 (82타)'},
              {'name': '니어리스트', 'winner': '홍길동 (홀2)'},
              {'name': '롱기스트', 'winner': '강동원 (홀15)'},
            ],
          ),
          const SizedBox(height: 16),
          // 시즌 통계
          const Text('시즌 통계',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 6,
                ),
              ],
            ),
            child: Column(
              children: [
                _buildStatRow('🏆 시즌 MVP', '홍길동 (출석률 100%)'),
                const Divider(),
                _buildStatRow('📅 출석왕', '김철수 (12회)'),
                const Divider(),
                _buildStatRow('⛳ 베스트 스코어', '홍길동 (78타)'),
                const Divider(),
                _buildStatRow('📊 평균 타수', '88.4타'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoundCard({
    required String date,
    required String course,
    required String winner,
    required String score,
    required List<Map<String, String>> awards,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(date,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                    Text(course,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.gold,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.emoji_events, color: Colors.white, size: 14),
                      const SizedBox(width: 4),
                      Text('$winner $score',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: awards
                  .map((award) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: AppColors.gold,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(award['name']!,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary)),
                            const Spacer(),
                            Text(award['winner']!,
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          Text(value,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary)),
        ],
      ),
    );
  }
}
