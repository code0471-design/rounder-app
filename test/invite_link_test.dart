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
}
