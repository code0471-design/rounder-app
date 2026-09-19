import 'package:flutter_test/flutter_test.dart';
import 'package:golf_rounder/services/club_ops_sync.dart';

/// 댓글 수정·삭제가 동기화로 되돌아가면 안 된다.
/// (원격 공지로 통째 교체하던 경로 — 동기화가 살아나면 바로 터진다)
void main() {
  const clubId = 'c_test';

  Map<String, dynamic> announcement(List<Map<String, dynamic>> comments) => {
        'id': 'ann_1',
        'clubId': clubId,
        'title': '9월 공지',
        'comments': comments,
      };

  Map<String, dynamic> comment(String id, String text) => {
        'id': id,
        'authorId': 'm_creator_$clubId',
        'authorName': '안경헌',
        'text': text,
        'createdAt': '2026-09-19T10:00:00.000',
      };

  setUp(ClubOpsSync.resetAnnouncementTombstones);

  test('내가 고친 댓글은 원격 옛 문구로 돌아가지 않는다', () {
    final merged = ClubOpsSync.mergeAnnouncements(
      [announcement([comment('c1', '수정한 댓글')])],
      [announcement([comment('c1', '옛날 댓글')])],
      clubId,
    );
    final comments = (merged.single as Map)['comments'] as List;
    expect(comments.length, 1);
    expect((comments.single as Map)['text'], '수정한 댓글');
  });

  test('내가 지운 댓글은 원격에 남아 있어도 되살아나지 않는다', () {
    ClubOpsSync.markCommentDeleted('c2');
    final merged = ClubOpsSync.mergeAnnouncements(
      [announcement([comment('c1', '남길 댓글')])],
      [
        announcement([comment('c1', '남길 댓글'), comment('c2', '지운 댓글')])
      ],
      clubId,
    );
    final comments = (merged.single as Map)['comments'] as List;
    expect(comments.map((e) => (e as Map)['id']), ['c1']);
  });

  test('다른 사람이 단 새 댓글은 들어온다', () {
    final merged = ClubOpsSync.mergeAnnouncements(
      [announcement([comment('c1', '내 댓글')])],
      [
        announcement([comment('c1', '내 댓글'), comment('c9', '이정원 댓글')])
      ],
      clubId,
    );
    final comments = (merged.single as Map)['comments'] as List;
    expect(comments.map((e) => (e as Map)['id']), ['c1', 'c9']);
  });

  test('지운 공지는 원격에서 다시 안 들어온다', () {
    ClubOpsSync.markAnnouncementDeleted('ann_1');
    final merged = ClubOpsSync.mergeAnnouncements(
      const [],
      [announcement([comment('c1', '댓글')])],
      clubId,
    );
    expect(merged, isEmpty);
  });

  test('다른 모임 공지는 건드리지 않는다', () {
    final other = {'id': 'ann_other', 'clubId': 'c_other', 'comments': []};
    final merged = ClubOpsSync.mergeAnnouncements(
      [other, announcement([comment('c1', '내 댓글')])],
      [announcement([comment('c1', '내 댓글')])],
      clubId,
    );
    expect(merged.any((e) => (e as Map)['id'] == 'ann_other'), isTrue);
  });
}
