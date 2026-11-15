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

  String messageFromError(Object error) {
    if (error is DioException) {
      final response = error.response;
      final data = response?.data;

      if (response?.statusCode == 403) {
        final message = data is Map ? '${data['message'] ?? ''}' : '';
        return message.isNotEmpty && message != 'This action is unauthorized.'
            ? message
            : 'You do not have permission to do this.';
      }

      if (response?.statusCode == 404 && !isMissingRouteResponse(response!)) {
        final message = data is Map ? '${data['message'] ?? ''}' : '';
        return message.isNotEmpty ? message : 'That record was not found.';
      }

      if (response?.statusCode == 404) {
        final requestPath = error.requestOptions.path;

        return 'The NSales mobile API endpoint "$requestPath" is not enabled '
            'on the server yet. Update the Laravel mobile API routes, clear '
            'Laravel route cache, then try again.';
      }

      if (response?.statusCode == 419) {
        return 'The request was rejected by the web CSRF layer. The native '
            'app must use the /api/mobile endpoints, not the website form routes.';
      }

      if (data is Map && data['message'] != null) {
        return data['message'].toString();
      }

      if (data is Map && data['errors'] is Map) {
        final errors = data['errors'] as Map;

        if (errors.isNotEmpty) {
          final value = errors.values.first;

          if (value is List && value.isNotEmpty) {
            return value.first.toString();
          }

          return value.toString();
        }
      }

      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout) {
        return 'The NSales server took too long to respond.';
      }

      if (error.type == DioExceptionType.connectionError) {
        return 'Unable to connect to NSales. Check your internet connection.';
      }
    }

    return 'Something went wrong. Please try again.';
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
