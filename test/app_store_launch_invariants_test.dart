import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golf_rounder/app/app_startup_host.dart';
import 'package:golf_rounder/screens/startup/startup_loading_screen.dart';

void main() {
  testWidgets('시작 로딩 화면에 오류/실패 문구가 없다', (tester) async {
    await tester.pumpWidget(const StartupLoadingScreen());
    expect(find.textContaining('오류'), findsNothing);
    expect(find.textContaining('실패'), findsNothing);
    expect(find.textContaining('Error'), findsNothing);
    expect(find.textContaining('Firebase'), findsNothing);
    expect(find.text('ROUNDER 시작 중…'), findsOneWidget);
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
}
