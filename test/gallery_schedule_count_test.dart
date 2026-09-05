import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:golf_rounder/models/club_model.dart';

String _read(String relative) => File(relative).readAsStringSync();

RoundSchedule _schedule({
  required String id,
  required DateTime date,
  ScheduleStatus status = ScheduleStatus.upcoming,
}) {
  return RoundSchedule(
    id: id,
    clubId: 'c1',
    title: '테스트 라운딩 $id',
    roundDate: date,
    teeTime: '07:00',
    courseName: '테스트CC',
    teamCount: 2,
    status: status,
    createdBy: '총무',
  );
}

/// 일정 탭 '예정' 필터 (ClubProvider.upcomingSchedules 와 같은 조건)
bool _inUpcomingTab(RoundSchedule s) =>
    s.status == ScheduleStatus.upcoming && !s.isDateOver;

/// 일정 탭 '지난' 필터 (ClubProvider.pastSchedules 와 같은 조건)
bool _inPastTab(RoundSchedule s) => s.isPast;

void main() {
  final past = DateTime.now().subtract(const Duration(days: 30));
  final future = DateTime.now().add(const Duration(days: 30));

  group('일정 탭에 보이는 수 = 취소 아닌 일정 수', () {
    // 갤러리가 4개, 일정 탭이 3개로 어긋났던 버그의 핵심.
    // 예정/지난 두 탭이 취소만 빼고 나머지를 정확히 한 번씩 담아야 한다.
    test('취소만 두 탭 어디에도 안 나온다', () {
      final all = [
        _schedule(id: 's1', date: future),
        _schedule(id: 's2', date: past),
        _schedule(id: 's3', date: future, status: ScheduleStatus.done),
        _schedule(id: 's4', date: past, status: ScheduleStatus.cancelled),
        _schedule(id: 's5', date: future, status: ScheduleStatus.cancelled),
      ];

      final visible =
          all.where((s) => _inUpcomingTab(s) || _inPastTab(s)).toList();
      final notCancelled =
          all.where((s) => s.status != ScheduleStatus.cancelled).toList();

      expect(
        visible.map((s) => s.id).toSet(),
        notCancelled.map((s) => s.id).toSet(),
        reason: '갤러리가 이 집합과 다른 목록을 쓰면 개수가 어긋난다',
      );
      expect(visible.length, 3);
    });

    test('한 일정이 두 탭에 동시에 들어가지 않는다', () {
      final all = [
        _schedule(id: 's1', date: future),
        _schedule(id: 's2', date: past),
        _schedule(id: 's3', date: past, status: ScheduleStatus.done),
        _schedule(id: 's4', date: future, status: ScheduleStatus.done),
        _schedule(id: 's5', date: past, status: ScheduleStatus.cancelled),
      ];
      for (final s in all) {
        final inBoth = _inUpcomingTab(s) && _inPastTab(s);
        expect(inBoth, isFalse, reason: '${s.id} 가 중복 계산된다');
      }
    });

    test('날짜가 지난 예정 일정은 지난 탭으로만 간다', () {
      final s = _schedule(id: 's1', date: past);
      expect(_inUpcomingTab(s), isFalse);
      expect(_inPastTab(s), isTrue);
    });

    test('취소 일정은 날짜와 무관하게 숨는다', () {
      for (final date in [past, future]) {
        final s =
            _schedule(id: 's1', date: date, status: ScheduleStatus.cancelled);
        expect(_inUpcomingTab(s), isFalse);
        expect(_inPastTab(s), isFalse);
      }
    });
  });

  group('갤러리는 취소된 일정을 빼고 센다', () {
    final gallery = _read('lib/screens/gallery/gallery_screen.dart');
    final provider = _read('lib/providers/club_provider.dart');

    test('앨범을 activeSchedules 로 만든다', () {
      expect(gallery.contains('_buildAlbums(provider.activeSchedules'), isTrue);
      expect(
        gallery.contains('_buildAlbums(provider.schedules'),
        isFalse,
        reason: 'schedules 는 취소 포함이라 유령 앨범이 생긴다',
      );
    });

    test('activeSchedules / cancelledScheduleIds 가 정의돼 있다', () {
      expect(provider.contains('List<RoundSchedule> get activeSchedules'), isTrue);
      expect(provider.contains('Set<String> get cancelledScheduleIds'), isTrue);
      expect(
        provider.contains('s.status != ScheduleStatus.cancelled'),
        isTrue,
      );
    });

    test('전체 사진에서도 취소 일정 사진을 뺀다', () {
      // 앨범만 숨기고 '전체 사진' 그리드에 남으면 여전히 유령이다.
      final idx = provider.indexOf('get clubPhotos');
      expect(idx, greaterThan(0));
      final body = provider.substring(idx, idx + 900);
      expect(body.contains('cancelledIds'), isTrue);
      expect(body.contains('!cancelledIds.contains(p.scheduleId)'), isTrue);
      expect(body.contains('activeSchedules'), isTrue);
    });

    test('취소하면 갤러리가 다시 그려진다 (시그니처에 status 포함)', () {
      expect(gallery.contains(r'${s.status.name}'), isTrue);
      final idx = provider.indexOf('_galleryWatchSignature()');
      expect(idx, greaterThan(0));
      expect(provider.contains(r'${s.status.name}'), isTrue);
    });
  });

  group('일정 취소는 사진까지 정리한다', () {
    final provider = _read('lib/providers/club_provider.dart');

    test('취소 시 해당 일정 사진을 지운다', () {
      final idx = provider.indexOf('int cancelSchedule(');
      expect(idx, greaterThan(0));
      final body = provider.substring(idx, idx + 900);
      expect(body.contains('_purgeSchedulePhotos(scheduleId)'), isTrue);
    });

    test('사진 정리는 persist 보다 먼저 — 한 번의 push 로 같이 반영', () {
      final idx = provider.indexOf('int cancelSchedule(');
      final body = provider.substring(idx, idx + 900);
      final purgeAt = body.indexOf('_purgeSchedulePhotos');
      final persistAt = body.indexOf('_persistImmediately');
      expect(purgeAt, greaterThan(0));
      expect(persistAt, greaterThan(purgeAt),
          reason: 'persist 후에 지우면 삭제분이 이번 push 에 안 실린다');
    });

    test('원격 문서까지 지우고 tombstone 을 남긴다', () {
      // tombstone 이 없으면 watch/pull merge 가 사진을 되살린다.
      final idx = provider.indexOf('int _purgeSchedulePhotos(');
      expect(idx, greaterThan(0));
      final body = provider.substring(idx, idx + 1000);
      expect(body.contains('ClubOpsSync.markPhotoDeleted(p.id)'), isTrue);
      expect(body.contains('ClubOpsSync.deletePhotoDoc('), isTrue);
      expect(body.contains('_photos.removeWhere'), isTrue);
    });

    test('취소 확인 얼럿이 삭제될 사진 장수를 먼저 알린다', () {
      // 되돌릴 수 없는 삭제라 사전 경고가 없으면 안 된다.
      final schedule = _read('lib/screens/schedule/schedule_screen.dart');
      expect(schedule.contains('provider.schedulePhotoCount(schedule.id)'),
          isTrue);
      expect(schedule.contains('함께 삭제됩니다'), isTrue);
      expect(schedule.contains('되돌릴 수 없습니다'), isTrue);
    });

    test('취소 확정은 여전히 dialogCtx 먼저 pop', () {
      final schedule = _read('lib/screens/schedule/schedule_screen.dart');
      final start = schedule.indexOf('void _confirmCancel');
      final end = schedule.indexOf('String _fmtDate(DateTime d)', start);
      final fn = schedule.substring(start, end);
      expect(fn.contains('builder: (dialogCtx)'), isTrue);
      expect(fn.contains('Navigator.of(dialogCtx).pop()'), isTrue);
    });

    test('한글이 깨지지 않았다 (Node 패치 후 확인)', () {
      final schedule = _read('lib/screens/schedule/schedule_screen.dart');
      expect(schedule.contains('�'), isFalse);
      expect(schedule.contains('일정을 취소하시겠습니까?'), isTrue);
    });
  });

  group('동기화가 남은 사진을 지우지 않는다', () {
    final provider = _read('lib/providers/club_provider.dart');

    test('_exportBundle 은 필터된 getter 가 아니라 _photos 를 push 한다', () {
      // clubPhotos 는 화면용 필터(취소 제외)다. 이걸 push 에 쓰면
      // _pushPhotos 가 아직 살아 있어야 할 원격 문서까지 지운다.
      final idx = provider.indexOf('ClubDataBundle _exportBundle()');
      expect(idx, greaterThan(0));
      final body = provider.substring(idx, idx + 1400);
      expect(body.contains('photos: List<RoundPhoto>.from(_photos)'), isTrue);
      expect(
        body.contains('clubPhotos'),
        isFalse,
        reason: '여기에 clubPhotos 를 쓰면 의도 밖 사진까지 원격에서 삭제된다',
      );
    });
  });
}
