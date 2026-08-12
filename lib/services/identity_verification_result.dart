/// 본인인증 결과 (포트원 / 개발용 mock 공통)
class IdentityVerificationResult {
  final bool success;
  final String? name;
  final String? phone;
  final String? identityVerificationId;
  final String? errorMessage;
  final bool usedMock;

  const IdentityVerificationResult({
    required this.success,
    this.name,
    this.phone,
    this.identityVerificationId,
    this.errorMessage,
    this.usedMock = false,
  });

  factory IdentityVerificationResult.failure(String message) =>
      IdentityVerificationResult(success: false, errorMessage: message);

  factory IdentityVerificationResult.mock({
    required String name,
    required String phone,
  }) =>
      IdentityVerificationResult(
        success: true,
        name: name,
        phone: phone,
        identityVerificationId: 'mock_${DateTime.now().millisecondsSinceEpoch}',
        usedMock: true,
      );
}
