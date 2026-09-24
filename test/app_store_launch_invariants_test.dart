import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golf_rounder/app/app_startup_host.dart';
import 'package:golf_rounder/screens/startup/startup_loading_screen.dart';
import 'package:golf_rounder/widgets/rounder_logo.dart';

void main() {
  testWidgets('시작 로딩 화면에 오류/실패 문구가 없다', (tester) async {
    await tester.pumpWidget(const StartupLoadingScreen());
    expect(find.textContaining('오류'), findsNothing);
    expect(find.textContaining('실패'), findsNothing);
    expect(find.textContaining('Error'), findsNothing);
    expect(find.textContaining('Firebase'), findsNothing);
    expect(find.textContaining('시작 중'), findsNothing);
    expect(find.textContaining('ROUNDER 시작'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(RounderLogo), findsOneWidget);
  });

  testWidgets('치명 화면은 예외 문자열을 그대로 보여 주지 않는다', (tester) async {
    await tester.pumpWidget(
      StartupFatalScreen(
        message: 'Exception: secret-review-token',
        onRetry: () {},
      ),
    );
    expect(find.textContaining('secret-review-token'), findsNothing);
    expect(find.textContaining('앱을 시작하지 못했습니다'), findsNothing);
    expect(find.text('연결이 지연되고 있습니다'), findsOneWidget);
  });

  testWidgets('위젯 예외가 나도 사용자에게 스택을 보여 주지 않는다', (tester) async {
    configureAppErrorHandlers();
    await tester.pumpWidget(
      MaterialApp(
        home: ErrorWidget.builder(
          FlutterErrorDetails(
            exception: StateError('secret-review-token'),
            library: 'widget library',
          ),
        ),
      ),
    );
    expect(find.textContaining('secret-review-token'), findsNothing);
    expect(find.textContaining('화면 렌더링 오류'), findsNothing);
    expect(find.textContaining('Exception'), findsNothing);
  });

  test('인트로는 가운데 로고를 띄운 뒤 자동로그인한다', () {
    final splash =
        File('lib/screens/splash/splash_screen.dart').readAsStringSync();
    expect(splash.contains('RounderLogo'), isTrue,
        reason: '인트로 로고를 빼면 시작 화면이 바로 지나간다');
    expect(splash.contains('milliseconds: 1800'), isTrue,
        reason: '로고는 최소 1.8초 보여 준다');
    expect(splash.contains('Future.wait'), isTrue,
        reason: '로고를 띄운 동안 자동로그인한다. 끝난 뒤 또 기다리지 않는다');
    expect(splash.contains('tryAutoLogin'), isTrue);
    expect(splash.contains('bootstrapForUser'), isFalse,
        reason: '인트로 뒤에 서버 부트스트랩을 또 기다리면 홈이 늦게 뜬다');
    expect(splash.contains('시작 중'), isFalse);
    final startup =
        File('lib/screens/startup/startup_loading_screen.dart').readAsStringSync();
    expect(startup.contains('RounderLogo'), isTrue);
    final provider =
        File('lib/providers/club_provider.dart').readAsStringSync();
    expect(provider.contains('unawaited(_afterSwitchUserCloud())'), isTrue,
        reason: '로그인 직후 서버 소속·ops 를 기다리면 홈이 늦게 뜬다');
    expect(provider.contains('await _alignMyClubsWithServer()'), isFalse,
        reason: '서버 소속을 기다리면 인트로 뒤 홈이 다시 늦어진다');
    expect(provider.contains('_claimClubsByPhone(authUserId)'), isTrue);
    final afterCloudStart = provider.indexOf('Future<void> _afterSwitchUserCloud()');
    final claimAt = provider.indexOf('await _claimClubsByPhone(authUserId);');
    expect(afterCloudStart, greaterThan(0));
    expect(claimAt, greaterThan(afterCloudStart),
        reason: '번호 소속 조회는 홈을 연 뒤에 해야 한다');
    final auth = File('lib/providers/auth_provider.dart').readAsStringSync();
    expect(auth.contains('unawaited(_hydrateRemoteSession(prefs, user))'), isTrue,
        reason: '자동로그인이 서버 번호 조회를 기다리면 인트로 뒤가 길다');
    final boot =
        File('lib/app/app_startup_bootstrap.dart').readAsStringSync();
    expect(boot.contains('unawaited(_warmServicesInBackground())'), isTrue,
        reason: '인트로에서 푸시·카탈로그·Auth 를 기다리면 홈이 다시 늦어진다');
    final runStart = boot.indexOf('static Future<AppStartupResult> run()');
    final warmStart = boot.indexOf('static Future<void> _warmServicesInBackground');
    expect(runStart, greaterThan(0));
    expect(warmStart, greaterThan(runStart));
    final runBody = boot.substring(runStart, warmStart);
    expect(runBody.contains('await Future.wait'), isFalse,
        reason: '푸시 카탈로그는 홈을 연 뒤에 데운다');
    expect(runBody.contains('ensureStagingSession'), isFalse,
        reason: 'Auth 세션은 인트로에서 기다리지 않는다');
    final persist =
        File('lib/services/club_persistence.dart').readAsStringSync();
    expect(persist.contains('_coldStartPrefs'), isTrue,
        reason: '첫 실행에서 prefs.reload 하면 큰 번들을 디스크에서 또 읽는다');
  });
}
