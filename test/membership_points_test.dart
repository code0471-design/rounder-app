import 'package:flutter_test/flutter_test.dart';
import 'package:golf_rounder/di/app_dependencies.dart';
import 'package:golf_rounder/models/club_model.dart';
import 'package:golf_rounder/providers/auth_provider.dart';
import 'package:golf_rounder/providers/club_provider.dart';
import 'package:golf_rounder/services/club_data_codec.dart';
import 'package:golf_rounder/services/club_ops_sync.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 멤버십 포인트·랭킹 회귀 테스트.
///
/// 배경: "댓글을 썼는데 랭킹 포인트가 안 올라간다" 신고에서 출발했다.
/// 원인은 ① 공지 1건당 첫 댓글만 적립 ② 회비 정시납부 +5 미구현
/// ③ 원격 동기화가 로컬 포인트를 회원 키 단위로 통째 교체 — 세 갈래였다.
void main() {
  // ClubProvider 가 WidgetsBinding 을 참조한다.
  TestWidgetsFlutterBinding.ensureInitialized();

  // ══════════════════════════════════════════════════════
  //  1. 동기화 — 포인트는 이벤트 단위 합집합
  // ══════════════════════════════════════════════════════
  group('pointEvents 동기화가 포인트를 지우지 않는다', () {
    Map<String, dynamic> event({
      required String type,
      required int points,
      required String desc,
      required String date,
    }) =>
        {'type': type, 'points': points, 'desc': desc, 'date': date};

    test('원격이 오래됐어도 로컬에서 방금 적립한 포인트가 살아남는다', () {
      // 이게 "댓글 써도 포인트가 안 오른다"의 핵심 경로였다.
      // 예전 코드는 pe[k] = remote[k] 라서 로컬 신규 이벤트가 통째로 날아갔다.
      final merged = ClubOpsSync.mergePointEvents(
        local: {
          'm_a': [
            event(
                type: 'commentActivity',
                points: 2,
                desc: '공지 참여 (+2): 5월 공지',
                date: '2026-05-02T10:00:00.000'),
            event(
                type: 'commentActivity',
                points: 2,
                desc: '공지 참여 (+2): 6월 공지',
                date: '2026-06-01T10:00:00.000'),
          ],
        },
        remote: {
          'm_a': [
            event(
                type: 'commentActivity',
                points: 2,
                desc: '공지 참여 (+2): 5월 공지',
                date: '2026-05-02T10:00:00.000'),
          ],
        },
      );

      expect((merged['m_a'] as List).length, 2,
          reason: '원격에 없는 로컬 이벤트를 원격 우선으로 덮어써선 안 된다');
    });

    test('원격에만 있는 회원 이력도 유지된다', () {
      final merged = ClubOpsSync.mergePointEvents(
        local: {
          'm_a': [
            event(
                type: 'roundAttendance',
                points: 10,
                desc: 'A 참석',
                date: '2026-05-01T00:00:00.000'),
          ],
        },
        remote: {
          'm_b': [
            event(
                type: 'roundAttendance',
                points: 10,
                desc: 'B 참석',
                date: '2026-05-01T00:00:00.000'),
          ],
        },
      );

      expect(merged.keys, containsAll(['m_a', 'm_b']));
    });

    test('같은 이벤트는 자연키로 중복 제거된다', () {
      final same = event(
          type: 'duesOnTime',
          points: 5,
          desc: '5월 월회비 정시납부|dues:d1:2026-5',
          date: '2026-05-03T09:00:00.000');
      final merged = ClubOpsSync.mergePointEvents(
        local: {'m_a': [same]},
        remote: {'m_a': [Map<String, dynamic>.from(same)]},
      );

      expect((merged['m_a'] as List).length, 1);
    });

    test('원격이 비어 있어도 로컬 포인트가 지워지지 않는다', () {
      final merged = ClubOpsSync.mergePointEvents(
        local: {
          'm_a': [
            event(
                type: 'commentActivity',
                points: 2,
                desc: '공지 참여',
                date: '2026-05-01T00:00:00.000'),
          ],
        },
        remote: const <String, dynamic>{},
      );

      expect((merged['m_a'] as List).length, 1,
          reason: '회비·거래와 같은 정책 — 빈 원격이 로컬을 지우면 안 된다');
    });

    test('로컬이 비어 있어도 원격 포인트가 지워지지 않는다', () {
      final merged = ClubOpsSync.mergePointEvents(
        local: const <String, dynamic>{},
        remote: {
          'm_a': [
            event(
                type: 'commentActivity',
                points: 2,
                desc: '공지 참여',
                date: '2026-05-01T00:00:00.000'),
          ],
        },
      );

      expect((merged['m_a'] as List).length, 1,
          reason: '재설치 직후 push 가 원격 포인트를 날려선 안 된다');
    });

    test('회수(음수) 이벤트도 보존돼 순 포인트가 맞는다', () {
      // 회수는 삭제가 아니라 -5 를 덧붙이는 방식이라 합집합으로 안전하다.
      final merged = ClubOpsSync.mergePointEvents(
        local: {
          'm_a': [
            event(
                type: 'duesOnTime',
                points: 5,
                desc: '5월 정시납부|dues:d1:2026-5',
                date: '2026-05-03T09:00:00.000'),
            event(
                type: 'penalty',
                points: -5,
                desc: '5월 회비 납부 취소|dues:d1:2026-5',
                date: '2026-05-04T09:00:00.000'),
          ],
        },
        remote: {
          'm_a': [
            event(
                type: 'duesOnTime',
                points: 5,
                desc: '5월 정시납부|dues:d1:2026-5',
                date: '2026-05-03T09:00:00.000'),
          ],
        },
      );

      final events = (merged['m_a'] as List).cast<Map<String, dynamic>>();
      final net = events.fold<int>(0, (s, e) => s + (e['points'] as int));
      expect(net, 0, reason: '원격의 옛 +5 가 회수를 되돌리면 안 된다');
    });

    test('날짜순으로 정렬된다', () {
      final merged = ClubOpsSync.mergePointEvents(
        local: {
          'm_a': [
            event(
                type: 'commentActivity',
                points: 2,
                desc: '나중',
                date: '2026-06-01T00:00:00.000'),
          ],
        },
        remote: {
          'm_a': [
            event(
                type: 'commentActivity',
                points: 2,
                desc: '먼저',
                date: '2026-05-01T00:00:00.000'),
          ],
        },
      );

      final events = (merged['m_a'] as List).cast<Map<String, dynamic>>();
      expect(events.first['desc'], '먼저');
    });
  });

  // ══════════════════════════════════════════════════════
  //  2. 마감일 판정
  // ══════════════════════════════════════════════════════
  group('회비 마감일 판정', () {
    DuesSetting monthly({int? dueDay}) => DuesSetting(
          id: 'd_month',
          type: DuesType.monthly,
          amount: 50000,
          title: '월회비',
          createdAt: DateTime(2026, 1, 1),
          dueDayOfMonth: dueDay,
        );

    test('마감일 전 납부는 정시', () {
      final s = monthly(dueDay: 25);
      expect(s.isPaidOnTime(DateTime(2026, 5, 10), year: 2026, month: 5), isTrue);
    });

    test('마감일 당일 납부도 정시', () {
      final s = monthly(dueDay: 25);
      expect(s.isPaidOnTime(DateTime(2026, 5, 25), year: 2026, month: 5), isTrue);
    });

    test('마감일 다음 날은 연체', () {
      final s = monthly(dueDay: 25);
      expect(s.isPaidOnTime(DateTime(2026, 5, 26), year: 2026, month: 5), isFalse);
    });

    test('없는 날짜(2월 31일)는 말일로 보정한다', () {
      final s = monthly(dueDay: 31);
      expect(s.dueDateFor(year: 2026, month: 2), DateTime(2026, 2, 28));
      expect(s.isPaidOnTime(DateTime(2026, 2, 28), year: 2026, month: 2), isTrue);
    });

    test('마감일이 없으면 판정 불가 — null', () {
      final s = monthly();
      expect(s.isPaidOnTime(DateTime(2026, 5, 1), year: 2026, month: 5), isNull,
          reason: '판정 불가일 때 정시로 오인해 +5 를 주면 안 된다');
    });

    test('연회비는 dueDate 를 쓴다', () {
      final s = DuesSetting(
        id: 'd_year',
        type: DuesType.annual,
        amount: 300000,
        title: '연회비',
        createdAt: DateTime(2026, 1, 1),
        dueDate: DateTime(2026, 3, 31),
      );
      expect(s.isPaidOnTime(DateTime(2026, 3, 30)), isTrue);
      expect(s.isPaidOnTime(DateTime(2026, 4, 1)), isFalse);
    });
  });

  // ══════════════════════════════════════════════════════
  //  3. 적립 규칙 (실제 Provider 동작)
  // ══════════════════════════════════════════════════════
  group('포인트 적립 규칙', () {
    late ClubProvider clubs;
    late String clubId;
    late String myId;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      AppDependencies.instance.init(offlineMock: true);
      final auth = AuthProvider();
      await auth.loginAsync('010-1234-5678');
      clubs = ClubProvider();
      await clubs.switchUser(auth.currentUser!.id,
          displayName: auth.currentUser!.name);
      final ok = await clubs.createClub(
        name: '포인트 테스트 모임',
        region: '서울',
        industry: '골프',
        teamCount: 4,
        myRole: '회장,총무',
      );
      expect(ok, isTrue);
      clubId = clubs.selectedClub.id;
      clubs.selectClubById(clubId);
      myId = clubs.currentMember!.id;
    });

    int myPoints() => clubs.getMembershipPoints(myId);

    test('댓글마다 +2 — 같은 공지에 두 번 달면 +4', () {
      clubs.addAnnouncement(title: '5월 공지', content: '내용');
      final annId = clubs.announcements.first.id;

      final before = myPoints();

      expect(clubs.addAnnouncementComment(announcementId: annId, text: '첫 댓글'),
          isTrue);
      expect(myPoints() - before, 2);

      // 예전엔 여기서 0점이었다 → "댓글 썼는데 포인트가 안 오른다"
      expect(clubs.addAnnouncementComment(announcementId: annId, text: '둘째 댓글'),
          isTrue,
          reason: '두 번째 댓글도 포인트를 받아야 한다');
      expect(myPoints() - before, 4);

      clubs.addAnnouncementComment(announcementId: annId, text: '셋째 댓글');
      expect(myPoints() - before, 6);
    });

    test('없는 공지에 댓글을 달면 적립되지 않는다', () {
      final before = myPoints();
      expect(
          clubs.addAnnouncementComment(announcementId: 'nope', text: '유령 댓글'),
          isFalse);
      expect(myPoints(), before);
    });

    test('회비를 마감일 전에 납부하면 +5', () {
      clubs.addDuesSetting(DuesSetting(
        id: 'd1',
        type: DuesType.monthly,
        amount: 50000,
        title: '월회비',
        createdAt: DateTime(2026, 1, 1),
        clubId: clubId,
        dueDayOfMonth: 28,
      ));

      final before = myPoints();
      clubs.recordPayment(
        memberId: myId,
        memberName: clubs.currentMember!.name,
        duesSettingId: 'd1',
        amount: 50000,
        year: DateTime.now().year,
        month: 5,
      );

      expect(myPoints() - before, 5,
          reason: '화면이 안내하는 "회비 납부 +5 P" 가 실제로 적립돼야 한다');
    });

    test('마감일이 지난 납부는 0점', () {
      clubs.addDuesSetting(DuesSetting(
        id: 'd1',
        type: DuesType.monthly,
        amount: 50000,
        title: '월회비',
        createdAt: DateTime(2026, 1, 1),
        clubId: clubId,
        // 매월 1일 마감 → recordPayment 가 쓰는 '오늘 일자'는 대개 이후다
        dueDayOfMonth: 1,
      ));

      final before = myPoints();
      clubs.recordPayment(
        memberId: myId,
        memberName: clubs.currentMember!.name,
        duesSettingId: 'd1',
        amount: 50000,
        year: DateTime.now().year,
        month: 5,
      );

      final gained = myPoints() - before;
      // 1일에 실행되면 정시라 5점이 정상. 그 외 날짜는 연체라 0점.
      expect(gained, DateTime.now().day == 1 ? 5 : 0);
    });

    test('같은 회비·같은 달은 두 번 적립되지 않는다', () {
      clubs.addDuesSetting(DuesSetting(
        id: 'd1',
        type: DuesType.monthly,
        amount: 50000,
        title: '월회비',
        createdAt: DateTime(2026, 1, 1),
        clubId: clubId,
        dueDayOfMonth: 28,
      ));

      final before = myPoints();
      for (var i = 0; i < 3; i++) {
        clubs.recordPayment(
          memberId: myId,
          memberName: clubs.currentMember!.name,
          duesSettingId: 'd1',
          amount: 50000,
          year: DateTime.now().year,
          month: 5,
        );
      }

      expect(myPoints() - before, 5);
    });

    test('납부를 취소하면 포인트가 회수되고, 재납부하면 다시 적립된다', () {
      clubs.addDuesSetting(DuesSetting(
        id: 'd1',
        type: DuesType.monthly,
        amount: 50000,
        title: '월회비',
        createdAt: DateTime(2026, 1, 1),
        clubId: clubId,
        dueDayOfMonth: 28,
      ));
      final year = DateTime.now().year;

      final before = myPoints();
      clubs.recordPayment(
        memberId: myId,
        memberName: clubs.currentMember!.name,
        duesSettingId: 'd1',
        amount: 50000,
        year: year,
        month: DateTime.now().month,
      );
      expect(myPoints() - before, 5);

      clubs.cancelPayment(myId, 'd1',
          year: year, month: DateTime.now().month);
      expect(myPoints() - before, 0, reason: '납부를 되돌리면 포인트도 회수한다');

      clubs.recordPayment(
        memberId: myId,
        memberName: clubs.currentMember!.name,
        duesSettingId: 'd1',
        amount: 50000,
        year: year,
        month: DateTime.now().month,
      );
      expect(myPoints() - before, 5, reason: '재납부는 다시 적립돼야 한다');
    });

    test('납부 → 취소를 반복해도 포인트가 누적되지 않는다', () {
      clubs.addDuesSetting(DuesSetting(
        id: 'd1',
        type: DuesType.monthly,
        amount: 50000,
        title: '월회비',
        createdAt: DateTime(2026, 1, 1),
        clubId: clubId,
        dueDayOfMonth: 28,
      ));
      final year = DateTime.now().year;
      final month = DateTime.now().month;

      final before = myPoints();
      for (var i = 0; i < 5; i++) {
        clubs.recordPayment(
          memberId: myId,
          memberName: clubs.currentMember!.name,
          duesSettingId: 'd1',
          amount: 50000,
          year: year,
          month: month,
        );
        clubs.cancelPayment(myId, 'd1', year: year, month: month);
      }

      expect(myPoints() - before, 0, reason: '어뷰징 경로가 열려선 안 된다');
    });

    test('랭킹은 포인트 내림차순이고 나도 포함된다', () {
      clubs.addAnnouncement(title: '공지', content: 'x');
      final annId = clubs.announcements.first.id;
      for (var i = 0; i < 3; i++) {
        clubs.addAnnouncementComment(announcementId: annId, text: '댓글$i');
      }

      final ranking = clubs.memberPointsRanking;
      expect(ranking, isNotEmpty);
      expect(ranking.map((e) => e.key), contains(myId));
      for (var i = 1; i < ranking.length; i++) {
        expect(ranking[i - 1].value, greaterThanOrEqualTo(ranking[i].value));
      }
      expect(ranking.first.key, myId, reason: '유일한 적립자가 1위여야 한다');
    });

  });

  // ══════════════════════════════════════════════════════
  //  4. 영속화 — encode/decode 왕복
  // ══════════════════════════════════════════════════════
  test('포인트는 encode/decode 왕복에서 유지된다', () {
    // 여기서 빠지면 앱을 다시 켤 때 포인트가 사라진다.
    final bundle = ClubDataBundle(
      selectedClubIndex: 0,
      freshClubIds: const {},
      myClubs: const [],
      allClubs: const [],
      joinRequests: const [],
      members: const [],
      activities: const [],
      announcements: const [],
      appNotifications: const [],
      duesSettings: const [],
      duesPayments: const [],
      paymentRequests: const [],
      transactions: const [],
      schedules: const [],
      photos: const [],
      groupAssignments: const {},
      adApplications: const [],
      adNotifications: const [],
      sponsorApplications: const [],
      pointEvents: {
        'm_a': [
          MembershipPointEvent(
            type: MembershipPointType.commentActivity,
            points: 2,
            desc: '공지 참여 (+2): 5월 공지',
            date: DateTime(2026, 5, 2, 10),
          ),
          MembershipPointEvent(
            type: MembershipPointType.duesOnTime,
            points: 5,
            desc: '5월 월회비 정시납부|dues:d1:2026-5',
            date: DateTime(2026, 5, 3, 9),
          ),
          MembershipPointEvent(
            type: MembershipPointType.penalty,
            points: -5,
            desc: '5월 회비 납부 취소|dues:d1:2026-5',
            date: DateTime(2026, 5, 4, 9),
          ),
        ],
      },
      awardRecords: const [],
      thankYouMessages: const [],
      waitingList: const [],
      alimtalkSettings: const {},
    );

    final restored = ClubDataCodec.decode(ClubDataCodec.encode(bundle));
    final mine = restored.pointEvents['m_a'] ?? const <MembershipPointEvent>[];

    expect(mine.length, 3);
    expect(mine.fold<int>(0, (s, e) => s + e.points), 2);
    expect(mine.map((e) => e.type),
        containsAll([MembershipPointType.penalty, MembershipPointType.duesOnTime]),
        reason: '회수(음수) 이벤트 타입도 왕복돼야 순 포인트가 맞는다');
  });
}
