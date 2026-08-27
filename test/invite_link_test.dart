import 'package:flutter_test/flutter_test.dart';
import 'package:golf_rounder/config/invite_links.dart';
import 'package:golf_rounder/models/user_model.dart';

void main() {
  InviteToken token() => InviteToken(
        token: 'inv_1',
        clubId: 'club_a',
        clubName: '한남골프회',
        inviterName: '로이',
        inviterId: 'u1',
      );

  test('초대 웹 링크는 우리 호스팅이고 남의 rounder.app이 아니다', () {
    final url = token().webUrl;
    expect(url, startsWith('${InviteLinks.webOrigin}/invite'));
    expect(url, contains('token=inv_1'));
    expect(url, contains('club=club_a'));
    expect(url, contains(Uri.encodeQueryComponent('한남골프회')));
    expect(url.contains('://rounder.app'), isFalse);
    expect(url.contains('www.rounder.app'), isFalse);
  });

  test('https 초대 경로를 우리 도메인에서만 인정한다', () {
    expect(
      InviteLinks.isInviteHttps(
        Uri.parse('https://rounder-f6019.web.app/invite?token=1'),
      ),
      isTrue,
    );
    expect(
      InviteLinks.isInviteHttps(
        Uri.parse('https://rounder.app/invite?token=1'),
      ),
      isFalse,
    );
  });

  test('Play 스토어 referrer에서 초대 딥링크를 복원한다', () {
    final uri = InviteLinks.uriFromPlayReferrer(
      'token=inv_1&club=club_a&name=%ED%95%9C%EB%82%A8%EA%B3%A8%ED%94%84%ED%9A%8C&inviter=%EB%A1%9C%EC%9D%B4',
    );
    expect(uri, isNotNull);
    expect(uri!.scheme, 'rounder');
    expect(uri.host, 'invite');
    expect(uri.queryParameters['token'], 'inv_1');
    expect(uri.queryParameters['club'], 'club_a');
    expect(uri.queryParameters['name'], '한남골프회');
  });

  test('Play 스토어 설치 URL에 초대 referrer가 들어간다', () {
    final url = InviteLinks.playStoreUrl(inviteQuery: {
      'token': 'inv_1',
      'club': 'club_a',
    });
    expect(url, contains('referrer='));
    expect(url, contains(Uri.encodeComponent('token=inv_1')));
  });
}
