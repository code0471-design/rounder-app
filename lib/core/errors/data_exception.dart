/// 데이터 계층 공통 예외
sealed class DataException implements Exception {
  const DataException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() =>
      cause == null ? 'DataException: $message' : 'DataException: $message ($cause)';
}

final class NetworkDataException extends DataException {
  const NetworkDataException(super.message, {super.cause});
}

final class NotFoundDataException extends DataException {
  const NotFoundDataException(super.message, {super.cause});
}

final class ParseDataException extends DataException {
  const ParseDataException(super.message, {super.cause});
}
