import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nsales_native/core/api_client.dart';

void main() {
  final api = ApiClient(const FlutterSecureStorage());
  final options = RequestOptions(path: '/staff/sales');

  DioException reply(int status, [Object? data]) => DioException(
    requestOptions: options,
    response: Response(requestOptions: options, statusCode: status, data: data),
    type: DioExceptionType.badResponse,
  );

  test('no connection and timeouts read as plain language', () {
    expect(
      api.messageFromError(DioException(requestOptions: options, type: DioExceptionType.connectionError)),
      'No internet connection. Check your Wi-Fi or mobile data and try again.',
    );
    expect(
      api.messageFromError(DioException(requestOptions: options, type: DioExceptionType.receiveTimeout)),
      contains('taking too long'),
    );
  });

  test('server errors never show technical details', () {
    expect(api.messageFromError(reply(500, {'message': 'Server Error'})), 'Something went wrong on our side. Please try again in a moment.');
    expect(api.messageFromError(reply(503)), contains('maintenance'));
    expect(
      api.messageFromError(reply(404, {'message': r'No query results for model [App\Models\Sale] 5'})),
      'That record was not found. It may have been deleted.',
    );
    expect(api.messageFromError(reply(404, {'message': 'The route api/mobile/x could not be found.'})), contains("isn't available yet"));
    expect(api.messageFromError(reply(419)), 'Your session expired. Please try again.');
  });

  test('useful server messages and field errors still come through', () {
    expect(api.messageFromError(reply(422, {
      'message': 'The email field is required. (and 1 more error)',
      'errors': {'email': ['The email field is required.']},
    })), 'The email field is required.');
    expect(api.messageFromError(reply(403, {'message': 'This action is unauthorized.'})), 'You do not have permission to do this.');
    expect(api.messageFromError(reply(403, {'message': 'Only managers can void sales.'})), 'Only managers can void sales.');
    expect(api.messageFromError(reply(401, {'message': 'Unauthenticated.'})), 'Your session has ended. Please sign in again.');
    expect(api.messageFromError(reply(401, {'message': 'These credentials do not match our records.'})), 'These credentials do not match our records.');
    expect(api.messageFromError(reply(429)), contains('Too many attempts'));
    expect(api.messageFromError(StateError('x')), 'Something went wrong. Please try again.');
  });
}
