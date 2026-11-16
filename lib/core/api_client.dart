import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'config.dart';

class ApiClient {
  ApiClient(this.storage) {
    dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 30),
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = sessionToken ?? await storage.read(key: 'auth_token');

          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }

          handler.next(options);
        },
      ),
    );
  }

  final FlutterSecureStorage storage;
  late final Dio dio;

  String? sessionToken;

  void setSessionToken(String? token) {
    sessionToken = token;
  }

  bool isSuccessful(Response response) {
    final status = response.statusCode ?? 0;
    return status >= 200 && status < 300;
  }

  bool isMissingRouteResponse(Response response) {
    if (response.statusCode != 404) return false;

    final data = response.data;
    final text = data is Map
        ? '${data['message'] ?? ''}'
        : '$data';

    return text.toLowerCase().contains('route') ||
        text.toLowerCase().contains('not found');
  }

  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
  }) {
    return _send(() => dio.get(path, queryParameters: query));
  }

  Future<Response<dynamic>> post(
    String path, {
    Object? data,
  }) {
    return _send(() => dio.post(path, data: data));
  }

  Future<Response<dynamic>> put(String path, {Object? data}) {
    return _send(() => dio.put(path, data: data));
  }

  Future<Response<dynamic>> patch(String path, {Object? data}) {
    return _send(() => dio.patch(path, data: data));
  }

  Future<Response<dynamic>> delete(String path) {
    return _send(() => dio.delete(path));
  }

  /// Runs a request and turns any non-2xx reply into a [DioException].
  Future<Response<dynamic>> _send(
    Future<Response<dynamic>> Function() request,
  ) async {
    final response = await request();

    if (!isSuccessful(response)) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
      );
    }

    return response;
  }

  Future<bool> authApiAvailable() async {
    try {
      final response = await dio.get(
        AppConfig.healthPath,
        options: Options(
          receiveTimeout: const Duration(seconds: 8),
        ),
      );

      return isSuccessful(response);
    } catch (_) {
      return false;
    }
  }

  /// A short, plain-language message for any request error, safe to show to users.
  String messageFromError(Object error) {
    if (error is! DioException) return _generic;

    final response = error.response;
    if (response == null) {
      return switch (error.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout =>
          'The server is taking too long to respond. Check your connection and try again.',
        DioExceptionType.cancel => 'The request was cancelled.',
        DioExceptionType.badCertificate =>
          "We couldn't make a secure connection. Check your network and try again.",
        _ => 'No internet connection. Check your Wi-Fi or mobile data and try again.',
      };
    }

    final status = response.statusCode ?? 0;
    final data = response.data;
    final serverMessage = data is Map ? '${data['message'] ?? ''}'.trim() : '';
    final fieldError = _firstFieldError(data);

    if (status >= 500) {
      return status == 503
          ? 'The system is under maintenance. Please try again in a few minutes.'
          : 'Something went wrong on our side. Please try again in a moment.';
    }

    switch (status) {
      case 401:
        return _usable(serverMessage, const ['Unauthenticated.'])
            ?? 'Your session has ended. Please sign in again.';
      case 403:
        return _usable(serverMessage, const ['This action is unauthorized.', 'Forbidden'])
            ?? 'You do not have permission to do this.';
      case 404:
        if (isMissingRouteResponse(response)) {
          return "This feature isn't available yet. Please update the app or try again later.";
        }
        return _usable(serverMessage, const []) ?? 'That record was not found. It may have been deleted.';
      case 413:
        return 'That file is too large. Choose a smaller file or photo and try again.';
      case 419:
        return 'Your session expired. Please try again.';
      case 422:
        return fieldError ?? _usable(serverMessage, const []) ?? 'Please check the details you entered and try again.';
      case 429:
        return 'Too many attempts. Please wait a minute and try again.';
    }

    return _usable(serverMessage, const []) ?? fieldError ?? _generic;
  }

  static const _generic = 'Something went wrong. Please try again.';

  /// The server's own message, unless it is one of Laravel's generic defaults.
  String? _usable(String message, List<String> generic) {
    if (message.isEmpty || generic.contains(message)) return null;
    // Laravel's "route not found" text and similar technical notes are not for users.
    final lower = message.toLowerCase();
    if (lower.contains('sqlstate') ||
        lower.contains('exception') ||
        lower.contains('route [') ||
        lower.contains('no query results') ||
        lower.contains(r'app\models')) {
      return null;
    }
    return message;
  }

  String? _firstFieldError(dynamic data) {
    if (data is! Map || data['errors'] is! Map) return null;
    final errors = data['errors'] as Map;
    if (errors.isEmpty) return null;
    final value = errors.values.first;
    if (value is List) return value.isEmpty ? null : value.first.toString();
    return value.toString();
  }

  String? errorCode(Object error) {
    if (error is DioException && error.response?.data is Map) {
      return (error.response!.data as Map)['code']?.toString();
    }

    return null;
  }

  Map<String, dynamic> errorData(Object error) {
    if (error is DioException && error.response?.data is Map) {
      return Map<String, dynamic>.from(error.response!.data as Map);
    }

    return {};
  }
}
