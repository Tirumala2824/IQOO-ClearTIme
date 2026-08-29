abstract class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic details;

  const AppException(this.message, {this.code, this.details});

  @override
  String toString() => message;
}

class AppAuthException extends AppException {
  const AppAuthException(super.message, {super.code, super.details});
}

class AppAuthorizationException extends AppException {
  const AppAuthorizationException(
    super.message, {
    super.code = 'UNAUTHORIZED',
    super.details,
  });
}

class AppFamilyException extends AppException {
  const AppFamilyException(super.message, {super.code, super.details});
}

class AppInvitationException extends AppException {
  const AppInvitationException(super.message, {super.code, super.details});
}

class AppValidationException extends AppException {
  final Map<String, String>? fieldErrors;

  const AppValidationException(
    super.message, {
    this.fieldErrors,
    super.code = 'VALIDATION_ERROR',
  });
}

class AppNetworkException extends AppException {
  const AppNetworkException([
    super.message =
        'Unable to connect to the network. Please check your internet connection.',
  ]);
}

class AppDatabaseException extends AppException {
  const AppDatabaseException([
    super.message =
        'A secure database operation could not be completed. Please try again.',
  ]);
}
