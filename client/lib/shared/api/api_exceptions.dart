class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? errorCode;
  final dynamic details;

  const ApiException({
    required this.message,
    this.statusCode,
    this.errorCode,
    this.details,
  });

  @override
  String toString() => 'ApiException(status: $statusCode, code: $errorCode, message: $message)';
}

class UnauthorizedException extends ApiException {
  const UnauthorizedException({String message = 'Unauthorized or session expired', dynamic details})
      : super(message: message, statusCode: 401, errorCode: 'UNAUTHORIZED', details: details);
}

class ForbiddenException extends ApiException {
  const ForbiddenException({String message = 'Access forbidden for current role', dynamic details})
      : super(message: message, statusCode: 403, errorCode: 'FORBIDDEN', details: details);
}

class NotFoundException extends ApiException {
  const NotFoundException({String message = 'Resource not found', dynamic details})
      : super(message: message, statusCode: 404, errorCode: 'NOT_FOUND', details: details);
}

class ConflictException extends ApiException {
  const ConflictException({String message = 'Resource conflict or concurrent modification', dynamic details})
      : super(message: message, statusCode: 409, errorCode: 'CONFLICT', details: details);
}

class ValidationException extends ApiException {
  const ValidationException({String message = 'Validation error', dynamic details})
      : super(message: message, statusCode: 422, errorCode: 'VALIDATION_ERROR', details: details);
}

class NetworkException extends ApiException {
  const NetworkException({String message = 'Network connection failed. Please check your connectivity.'})
      : super(message: message, statusCode: null, errorCode: 'NETWORK_ERROR');
}
