import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golf_rounder/config/business_info.dart';
import 'package:golf_rounder/screens/legal/service_about_screen.dart';
import 'package:golf_rounder/widgets/business_info_footer.dart';

void main() {
  testWidgets('사업자 정보에 포트원 필수 항목이 모두 보인다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: BusinessInfoFooter())),
    );

    expect(find.textContaining('상호명'), findsWidgets);
    expect(find.textContaining('사업자번호'), findsWidgets);
    expect(find.textContaining('대표자명'), findsWidgets);
    expect(find.textContaining('사업장주소지'), findsWidgets);
    expect(find.textContaining('전화번호'), findsWidgets);
    expect(find.textContaining(BusinessInfo.tradeName), findsWidgets);
    expect(find.textContaining(BusinessInfo.registrationNo), findsWidgets);
    expect(find.textContaining(BusinessInfo.ceo), findsWidgets);
    expect(find.textContaining(BusinessInfo.address), findsWidgets);
    expect(find.textContaining(BusinessInfo.phone), findsWidgets);
    expect(find.textContaining('070-4571-4169'), findsWidgets);
  });

  testWidgets('서비스 소개 페이지에 골프 모임 관리 안내가 있다', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ServiceAboutScreen()));

    expect(find.text('서비스 소개'), findsOneWidget);
    expect(find.textContaining('골프'), findsWidgets);
    expect(find.textContaining('도박'), findsOneWidget);
    expect(find.textContaining('상호명'), findsWidgets);
    expect(find.textContaining('사업자번호'), findsWidgets);
  });
}
