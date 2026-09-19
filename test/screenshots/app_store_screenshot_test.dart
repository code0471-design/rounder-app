import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golf_rounder/di/app_dependencies.dart';
import 'package:golf_rounder/models/club_model.dart';
import 'package:golf_rounder/providers/auth_provider.dart';
import 'package:golf_rounder/providers/club_provider.dart';
import 'package:golf_rounder/screens/auth/login_screen.dart';
import 'package:golf_rounder/screens/finance/finance_screen.dart';
import 'package:golf_rounder/screens/members/members_screen.dart';
import 'package:golf_rounder/screens/my_clubs/my_clubs_screen.dart';
import 'package:golf_rounder/screens/schedule/schedule_screen.dart';
import 'package:golf_rounder/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App Store용 실 Flutter UI 스크린샷 (기기 없이 생성).
/// 실행: flutter test test/screenshots/app_store_screenshot_test.dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const iphone = Size(1290, 2796);
  const ipad = Size(2048, 2732);

  late AuthProvider auth;
  late ClubProvider clubs;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    AppDependencies.instance.init(offlineMock: true);
    auth = AuthProvider();
    await auth.loginAsync('010-1234-5678');
    clubs = ClubProvider();
    await clubs.switchUser(auth.currentUser!.id);
    final ok = await clubs.createClub(
      name: '라운더 골프모임',
      region: '서울',
      industry: '골프',
      teamCount: 4,
      myRole: '회장,총무',
      description: '친목 골프 모임',
    );
    expect(ok, isTrue);
    final clubId = clubs.selectedClub.id;
    clubs.selectClubById(clubId);

    final names = ['김민수', '이서연', '박준호', '최유진', '정하늘'];
    for (var i = 0; i < names.length; i++) {
      clubs.addMember(
        Member(
          id: Member.rosterId(clubId, 'u$i'),
          name: names[i],
          gender: i.isEven ? '남' : '여',
          memberType: '정회원',
          role: '정회원',
          handicap: 10.0 + i,
          joinDate: DateTime.now().subtract(Duration(days: 30 * (i + 1))),
          phone: '010-1111-000$i',
          status: '활성',
        ),
      );
    }

    final soon = DateTime.now().add(const Duration(days: 7));
    clubs.addSchedule(
      RoundSchedule(
        id: 'sch_shot_1',
        clubId: clubId,
        title: '9월 월례회',
        roundDate: soon,
        teeTime: '07:30',
        courseName: '남서울CC',
        courseAddress: '경기도',
        teamCount: 4,
        createdBy: '홍길동',
        notice: '복장 규정 준수',
      ),
    );
    clubs.addSchedule(
      RoundSchedule(
        id: 'sch_shot_2',
        clubId: clubId,
        title: '친선 라운드',
        roundDate: soon.add(const Duration(days: 14)),
        teeTime: '08:00',
        courseName: '레이크사이드CC',
        teamCount: 3,
        createdBy: '홍길동',
      ),
    );
  });

  Future<void> capture(
    WidgetTester tester, {
    required String fileName,
    required Size size,
    required Widget child,
  }) async {
    final view = tester.view;
    view.physicalSize = size;
    view.devicePixelRatio = 1.0;
    addTearDown(() {
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<ClubProvider>.value(value: clubs),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.theme,
          home: MediaQuery(
            data: MediaQueryData(size: size),
            child: RepaintBoundary(
              key: const ValueKey('shot'),
              child: child,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('shot')),
    );
    final image = await boundary.toImage(pixelRatio: 1.0);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    expect(bytes, isNotNull);

    final dir = Directory('store_screenshots');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    // ignore: avoid_print
    print('Wrote ${file.path} (${file.lengthSync()} bytes)');
  }

  testWidgets('iPhone 6.7 screenshots', (tester) async {
    await capture(
      tester,
      fileName: 'iphone_01_login.png',
      size: iphone,
      child: const LoginScreen(),
    );
    await capture(
      tester,
      fileName: 'iphone_02_my_clubs.png',
      size: iphone,
      child: const MyClubsScreen(),
    );
    await capture(
      tester,
      fileName: 'iphone_03_schedule.png',
      size: iphone,
      child: const ScheduleScreen(),
    );
    await capture(
      tester,
      fileName: 'iphone_04_members.png',
      size: iphone,
      child: const MembersScreen(),
    );
    await capture(
      tester,
      fileName: 'iphone_05_finance.png',
      size: iphone,
      child: const FinanceScreen(),
    );
  }, timeout: const Timeout(Duration(minutes: 3)));

  testWidgets('iPad 12.9 screenshots', (tester) async {
    await capture(
      tester,
      fileName: 'ipad_01_login.png',
      size: ipad,
      child: const LoginScreen(),
    );
    await capture(
      tester,
      fileName: 'ipad_02_my_clubs.png',
      size: ipad,
      child: const MyClubsScreen(),
    );
    await capture(
      tester,
      fileName: 'ipad_03_schedule.png',
      size: ipad,
      child: const ScheduleScreen(),
    );
    await capture(
      tester,
      fileName: 'ipad_04_members.png',
      size: ipad,
      child: const MembersScreen(),
    );
    await capture(
      tester,
      fileName: 'ipad_05_finance.png',
      size: ipad,
      child: const FinanceScreen(),
    );
  }, timeout: const Timeout(Duration(minutes: 3)));
}
