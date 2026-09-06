import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/club_provider.dart';
import '../theme/app_theme.dart';

/// 일정 상세에 저장된 스코어·시상을 바로 보여 준다.
/// 스코어는 타수 낮은 순, 한 줄에 3명.
class ScoreAwardResultsPreview extends StatelessWidget {
  final String scheduleId;
  const ScoreAwardResultsPreview({super.key, required this.scheduleId});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ClubProvider>();
    final scoreRec = provider.roundScoreFor(scheduleId);
    final awards = provider.awardRecordsFor(scheduleId);
    final scores = scoreRec?.scores.entries.toList() ?? [];
    scores.sort((a, b) => a.value.compareTo(b.value));
    if (scores.isEmpty && awards.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (scores.isNotEmpty) ...[
            const Text(
              '스코어',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.inkSoft,
              ),
            ),
            const SizedBox(height: 8),
            _ScoreGrid(entries: scores, provider: provider),
          ],
          if (awards.isNotEmpty) ...[
            if (scores.isNotEmpty) const SizedBox(height: 12),
            const Text(
              '시상',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.inkSoft,
              ),
            ),
            const SizedBox(height: 8),
            ...awards.map((a) {
              final names = a.winnerNames.isNotEmpty
                  ? a.winnerNames.join(', ')
                  : a.winnerIds
                      .map((id) => provider.memberById(id)?.name ?? id)
                      .join(', ');
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Text(a.awardIcon, style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 6),
                    Text(
                      a.awardName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        names,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

class _ScoreGrid extends StatelessWidget {
  final List<MapEntry<String, int>> entries;
  final ClubProvider provider;
  const _ScoreGrid({required this.entries, required this.provider});

  @override
  Widget build(BuildContext context) {
    final best = entries.isEmpty ? null : entries.first.value;
    final rows = <Widget>[];
    for (var i = 0; i < entries.length; i += 3) {
      rows.add(
        Padding(
          padding: EdgeInsets.only(bottom: i + 3 < entries.length ? 8 : 0),
          child: Row(
            children: [
              for (var j = 0; j < 3; j++)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: j < 2 ? 6 : 0),
                    child: i + j < entries.length
                        ? _ScoreCell(
                            name: provider.memberById(entries[i + j].key)?.name ??
                                entries[i + j].key,
                            score: entries[i + j].value,
                            isBest: entries[i + j].value == best,
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
            ],
          ),
        ),
      );
    }
    return Column(children: rows);
  }
}

class _ScoreCell extends StatelessWidget {
  final String name;
  final int score;
  final bool isBest;
  const _ScoreCell({
    required this.name,
    required this.score,
    required this.isBest,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: isBest
            ? AppColors.accent.withValues(alpha: 0.12)
            : AppColors.cream2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isBest ? AppColors.accent : AppColors.sand,
        ),
      ),
      child: Column(
        children: [
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$score',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: isBest ? AppColors.goldDeep : AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}
