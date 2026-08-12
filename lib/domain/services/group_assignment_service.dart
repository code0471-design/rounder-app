import 'dart:math' as math;

import '../../models/club_model.dart';

/// 조편성 자동 배정 입력
class GroupAssignmentInput {
  final List<AssignGroup> groups;
  final List<Member> unassigned;
  final List<AutoAssignOption> options;
  final Map<String, int> prevGroupOf;
  final Map<String, List<String>> companionIdsByMember;
  final bool keepManual;

  const GroupAssignmentInput({
    required this.groups,
    required this.unassigned,
    required this.options,
    this.prevGroupOf = const {},
    this.companionIdsByMember = const {},
    this.keepManual = true,
  });
}

/// 조편성 자동 배정 알고리즘 (규칙 복합 적용)
class GroupAssignmentService {
  const GroupAssignmentService();

  List<AssignGroup> autoAssign(GroupAssignmentInput input) {
    final groups = input.groups
        .map(
          (g) => g.copyWithSlots(List<GroupSlot>.from(g.slots)),
        )
        .toList();
    var pool = List<Member>.from(input.unassigned);
    final opts = input.options.toSet();

    if (!input.keepManual) {
      for (var gi = 0; gi < groups.length; gi++) {
        groups[gi] = groups[gi].copyWithSlots(
          List.generate(groups[gi].slots.length, (_) => const GroupSlot()),
        );
      }
    }

    if (opts.contains(AutoAssignOption.pairGuestReferrer)) {
      pool = _assignGuestReferrerPairs(groups, pool);
    }

    if (opts.contains(AutoAssignOption.pairCompanions)) {
      pool = _assignCompanionGroups(
        groups,
        pool,
        input.companionIdsByMember,
      );
    }

    pool = _fillRemaining(
      groups: groups,
      pool: pool,
      options: opts,
      prevGroupOf: input.prevGroupOf,
    );

    return groups;
  }

  List<Member> _assignGuestReferrerPairs(
    List<AssignGroup> groups,
    List<Member> pool,
  ) {
    final remaining = List<Member>.from(pool);
    final guests = remaining
        .where((m) => m.memberType == '게스트' && m.referrerId != null)
        .toList();

    for (final guest in guests) {
      if (!remaining.any((m) => m.id == guest.id)) continue;
      final referrerId = guest.referrerId!;
      Member? referrer = remaining.cast<Member?>().firstWhere(
            (m) => m?.id == referrerId,
            orElse: () => null,
          );
      referrer ??= _findAssignedMember(groups, referrerId);

      if (referrer == null) continue;

      final placed = _placeMembersInSameGroup(
        groups,
        [guest, if (remaining.any((m) => m.id == referrer!.id)) referrer],
      );
      if (placed) {
        remaining.removeWhere((m) => m.id == guest.id);
        remaining.removeWhere((m) => m.id == referrerId);
      }
    }
    return remaining;
  }

  List<Member> _assignCompanionGroups(
    List<AssignGroup> groups,
    List<Member> pool,
    Map<String, List<String>> companionMap,
  ) {
    final remaining = List<Member>.from(pool);
    final visited = <String>{};

    for (final member in List<Member>.from(remaining)) {
      if (visited.contains(member.id)) continue;
      final component = _companionComponent(member.id, remaining, companionMap);
      for (final id in component) {
        visited.add(id);
      }
      if (component.length < 2) continue;

      final members = component
          .map((id) => remaining.cast<Member?>().firstWhere(
                (m) => m?.id == id,
                orElse: () => null,
              ))
          .whereType<Member>()
          .toList();
      if (members.length < 2) continue;

      if (_placeMembersInSameGroup(groups, members)) {
        remaining.removeWhere((m) => component.contains(m.id));
      }
    }
    return remaining;
  }

  List<String> _companionComponent(
    String startId,
    List<Member> pool,
    Map<String, List<String>> companionMap,
  ) {
    final poolIds = pool.map((m) => m.id).toSet();
    final queue = [startId];
    final component = <String>{};

    while (queue.isNotEmpty) {
      final id = queue.removeAt(0);
      if (!component.add(id)) continue;
      final companions = companionMap[id] ?? const [];
      for (final c in companions) {
        if (poolIds.contains(c) && !component.contains(c)) {
          queue.add(c);
        }
      }
      for (final entry in companionMap.entries) {
        if (entry.value.contains(id) &&
            poolIds.contains(entry.key) &&
            !component.contains(entry.key)) {
          queue.add(entry.key);
        }
      }
    }
    return component.toList();
  }

  bool _placeMembersInSameGroup(
    List<AssignGroup> groups,
    List<Member> members,
  ) {
    if (members.isEmpty) return false;

    int? bestGi;
    var bestEmpty = -1;
    for (var gi = 0; gi < groups.length; gi++) {
      final empty = groups[gi].slots.where((s) => s.isEmpty).length;
      if (empty >= members.length && empty > bestEmpty) {
        bestEmpty = empty;
        bestGi = gi;
      }
    }
    if (bestGi == null) return false;

    final slots = List<GroupSlot>.from(groups[bestGi!].slots);
    var mi = 0;
    for (var si = 0; si < slots.length && mi < members.length; si++) {
      if (slots[si].isEmpty) {
        slots[si] = GroupSlot.fromMember(members[mi++]);
      }
    }
    groups[bestGi] = groups[bestGi].copyWithSlots(slots);
    return mi == members.length;
  }

  List<Member> _fillRemaining({
    required List<AssignGroup> groups,
    required List<Member> pool,
    required Set<AutoAssignOption> options,
    required Map<String, int> prevGroupOf,
  }) {
    if (pool.isEmpty) return pool;

    final remaining = List<Member>.from(pool);
    final rng = math.Random();

    if (options.contains(AutoAssignOption.balanceHandicap)) {
      remaining.sort(
        (a, b) => (b.handicap ?? 99).compareTo(a.handicap ?? 99),
      );
    } else {
      remaining.shuffle(rng);
    }

    final emptySlots = <({int gi, int si})>[];
    for (var gi = 0; gi < groups.length; gi++) {
      for (var si = 0; si < groups[gi].slots.length; si++) {
        if (groups[gi].slots[si].isEmpty) {
          emptySlots.add((gi: gi, si: si));
        }
      }
    }
    if (emptySlots.isEmpty) return remaining;

    final teamCount = groups.length;
    final draftOrder = <int>[];
    if (options.contains(AutoAssignOption.balanceHandicap)) {
      var round = 0;
      while (draftOrder.length < emptySlots.length) {
        final order = round.isEven
            ? List.generate(teamCount, (i) => i)
            : List.generate(teamCount, (i) => teamCount - 1 - i);
        for (final gi in order) {
          if (draftOrder.length < emptySlots.length) draftOrder.add(gi);
        }
        round++;
      }
    }

    var slotCursor = 0;
    while (remaining.isNotEmpty && slotCursor < emptySlots.length) {
      final targetGi = options.contains(AutoAssignOption.balanceHandicap)
          ? draftOrder[slotCursor % draftOrder.length]
          : emptySlots[slotCursor].gi;

      final slotIndex = emptySlots.indexWhere(
        (e) => e.gi == targetGi && groups[e.gi].slots[e.si].isEmpty,
      );
      if (slotIndex == -1) {
        slotCursor++;
        continue;
      }

      final slot = emptySlots[slotIndex];
      final picked = _pickBestMember(
        remaining: remaining,
        targetGi: slot.gi,
        groups: groups,
        options: options,
        prevGroupOf: prevGroupOf,
      );

      final gSlots = List<GroupSlot>.from(groups[slot.gi].slots);
      gSlots[slot.si] = GroupSlot.fromMember(picked);
      groups[slot.gi] = groups[slot.gi].copyWithSlots(gSlots);
      remaining.removeWhere((m) => m.id == picked.id);
      emptySlots.removeAt(slotIndex);
      slotCursor++;
    }

    return remaining;
  }

  Member _pickBestMember({
    required List<Member> remaining,
    required int targetGi,
    required List<AssignGroup> groups,
    required Set<AutoAssignOption> options,
    required Map<String, int> prevGroupOf,
  }) {
    Member? best;
    var bestScore = double.negativeInfinity;

    for (final m in remaining) {
      var score = rngJitter(m.id);

      if (options.contains(AutoAssignOption.balanceGender)) {
        score += _genderBalanceScore(m, groups[targetGi]);
      }
      if (options.contains(AutoAssignOption.balanceHandicap)) {
        score += _handicapBalanceScore(m, groups[targetGi]);
      }
      if (options.contains(AutoAssignOption.avoidLastMonth)) {
        score += _avoidPrevGroupScore(
          m,
          targetGi,
          groups,
          prevGroupOf,
        );
      }

      if (score > bestScore) {
        bestScore = score;
        best = m;
      }
    }
    return best ?? remaining.first;
  }

  double rngJitter(String id) =>
      id.hashCode % 100 / 1000; // 동점 시 안정적 타이브레이크

  double _genderBalanceScore(Member m, AssignGroup group) {
    final males =
        group.slots.where((s) => s.isFilled && s.gender == '남').length;
    final females =
        group.slots.where((s) => s.isFilled && s.gender == '여').length;
    if (m.gender == '남' && males > females) return -2;
    if (m.gender == '여' && females > males) return -2;
    return 3;
  }

  double _handicapBalanceScore(Member m, AssignGroup group) {
    final filled = group.slots.where((s) => s.isFilled && s.handicap != null);
    if (filled.isEmpty) return 2;
    final avg = filled.map((s) => s.handicap!).reduce((a, b) => a + b) /
        filled.length;
    final h = m.handicap ?? 99;
    if (h > avg) return 3; // 고수를 합계 높은 조에
    if (h < avg) return 2; // 초보를 합계 낮은 조에
    return 1;
  }

  double _avoidPrevGroupScore(
    Member m,
    int targetGi,
    List<AssignGroup> groups,
    Map<String, int> prevGroupOf,
  ) {
    if (!prevGroupOf.containsKey(m.id)) return 1;
    final prevGi = prevGroupOf[m.id]! - 1;
    if (prevGi == targetGi) return -5;

    var conflicts = 0;
    for (final s in groups[targetGi].slots) {
      if (!s.isFilled || s.memberId == null) continue;
      final otherPrev = prevGroupOf[s.memberId];
      if (otherPrev != null && otherPrev - 1 == targetGi) {
        final myPrev = prevGroupOf[m.id];
        if (myPrev == otherPrev) conflicts++;
      }
      if (prevGroupOf.containsKey(s.memberId) &&
          prevGroupOf[s.memberId] == prevGroupOf[m.id]) {
        conflicts++;
      }
    }
    return conflicts == 0 ? 4 : -conflicts.toDouble();
  }

  Member? _findAssignedMember(List<AssignGroup> groups, String memberId) {
    for (final g in groups) {
      for (final s in g.slots) {
        if (s.memberId == memberId) {
          return Member(
            id: memberId,
            name: s.memberName ?? '',
            gender: s.gender ?? '남',
            memberType: s.memberType ?? '정회원',
            role: '일반',
            handicap: s.handicap,
          );
        }
      }
    }
    return null;
  }
}
