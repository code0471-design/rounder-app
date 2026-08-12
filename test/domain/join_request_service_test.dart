import 'package:flutter_test/flutter_test.dart';
import 'package:golf_rounder/domain/services/join_request_service.dart';

void main() {
  group('JoinRequestService', () {
    test('canSubmit returns true when not member and no pending', () {
      expect(
        JoinRequestService.canSubmit(isMember: false, hasPendingRequest: false),
        isTrue,
      );
    });

    test('canSubmit returns false when already member', () {
      expect(
        JoinRequestService.canSubmit(isMember: true, hasPendingRequest: false),
        isFalse,
      );
    });

    test('canSubmit returns false when pending request exists', () {
      expect(
        JoinRequestService.canSubmit(isMember: false, hasPendingRequest: true),
        isFalse,
      );
    });

    test('isAdminRole recognizes executive roles', () {
      expect(JoinRequestService.isAdminRole('회장'), isTrue);
      expect(JoinRequestService.isAdminRole('부회장'), isTrue);
      expect(JoinRequestService.isAdminRole('총무'), isTrue);
      expect(JoinRequestService.isAdminRole('일반'), isFalse);
    });
  });
}
