import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_client.dart';
import 'config.dart';

class AuthResult {
  const AuthResult({
    this.error,
    this.requiresVerification = false,
    this.email,
  });

  final String? error;
  final bool requiresVerification;
  final String? email;

  bool get success => error == null && !requiresVerification;
}

class AuthStore extends ChangeNotifier {
  AuthStore(this.api, this.storage);

  final ApiClient api;
  final FlutterSecureStorage storage;

  bool loading = true;
  bool authenticated = false;
  Map<String, dynamic>? user;

  Future<void> bootstrap() async {
    final remember = await storage.read(key: 'remember_me') == '1';

    if (!remember) {
      await storage.delete(key: 'auth_token');
      api.setSessionToken(null);
      loading = false;
      authenticated = false;
      notifyListeners();
      return;
    }

    final token = await storage.read(key: 'auth_token');

    if (token == null || token.isEmpty) {
      loading = false;
      authenticated = false;
      notifyListeners();
      return;
    }

    api.setSessionToken(token);

    try {
      final response = await api.get(AppConfig.mePath);
      user = Map<String, dynamic>.from(response.data['user'] ?? {});
      authenticated = true;
    } catch (_) {
      await storage.delete(key: 'auth_token');
      api.setSessionToken(null);
      authenticated = false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<AuthResult> login(
    String email,
    String password, {
    required bool rememberMe,
  }) async {
    loading = true;
    notifyListeners();

    try {
      final response = await api.post(
        AppConfig.loginPath,
        data: {
          'email': email.trim(),
          'password': password,
          'device_name': 'NSales Native Mobile',
        },
      );

      await _acceptAuthentication(
        response.data,
        rememberMe: rememberMe,
      );

      return const AuthResult();
    } catch (error) {
      if (api.errorCode(error) == 'EMAIL_VERIFICATION_REQUIRED') {
        final data = api.errorData(error);

        return AuthResult(
          requiresVerification: true,
          email: data['email']?.toString() ?? email.trim(),
        );
      }

      return AuthResult(error: api.messageFromError(error));
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<String?> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
  }) async {
    loading = true;
    notifyListeners();

    try {
      await api.post(
        AppConfig.registerPath,
        data: {
          'name': name.trim(),
          'email': email.trim(),
          'password': password,
          'password_confirmation': passwordConfirmation,
        },
      );

      return null;
    } catch (error) {
      return api.messageFromError(error);
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<String?> verifyRegistration({
    required String email,
    required String otp,
    required bool rememberMe,
  }) async {
    loading = true;
    notifyListeners();

    try {
      final response = await api.post(
        AppConfig.registerVerifyOtpPath,
        data: {
          'email': email.trim(),
          'otp': otp.trim(),
          'device_name': 'NSales Native Mobile',
        },
      );

      await _acceptAuthentication(
        response.data,
        rememberMe: rememberMe,
      );

      return null;
    } catch (error) {
      return api.messageFromError(error);
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<String?> resendRegistrationOtp(String email) async {
    try {
      await api.post(
        AppConfig.registerResendOtpPath,
        data: {'email': email.trim()},
      );

      return null;
    } catch (error) {
      return api.messageFromError(error);
    }
  }

  Future<String?> requestPasswordReset(String email) async {
    loading = true;
    notifyListeners();

    try {
      await api.post(
        AppConfig.forgotPasswordPath,
        data: {'email': email.trim()},
      );

      return null;
    } catch (error) {
      return api.messageFromError(error);
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<({String? error, String? resetToken})> verifyPasswordResetOtp({
    required String email,
    required String otp,
  }) async {
    loading = true;
    notifyListeners();

    try {
      final response = await api.post(
        AppConfig.forgotPasswordVerifyOtpPath,
        data: {
          'email': email.trim(),
          'otp': otp.trim(),
        },
      );

      return (
        error: null,
        resetToken: response.data['reset_token']?.toString(),
      );
    } catch (error) {
      return (
        error: api.messageFromError(error),
        resetToken: null,
      );
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<String?> resendPasswordResetOtp(String email) async {
    try {
      await api.post(
        AppConfig.forgotPasswordResendOtpPath,
        data: {'email': email.trim()},
      );

      return null;
    } catch (error) {
      return api.messageFromError(error);
    }
  }

  Future<String?> resetPassword({
    required String email,
    required String resetToken,
    required String password,
    required String passwordConfirmation,
  }) async {
    loading = true;
    notifyListeners();

    try {
      await api.post(
        AppConfig.resetPasswordPath,
        data: {
          'email': email.trim(),
          'reset_token': resetToken,
          'password': password,
          'password_confirmation': passwordConfirmation,
        },
      );

      return null;
    } catch (error) {
      return api.messageFromError(error);
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Merges changed profile fields (name, photo_url...) so every screen updates at once.
  void updateUser(Map<String, dynamic> changes) {
    user = {...?user, ...changes};
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      await api.post(AppConfig.logoutPath);
    } catch (_) {
      // Always clear the local session.
    }

    await storage.delete(key: 'auth_token');
    await storage.delete(key: 'remember_me');

    api.setSessionToken(null);
    user = null;
    authenticated = false;
    notifyListeners();
  }

  Future<void> _acceptAuthentication(
    dynamic data, {
    required bool rememberMe,
  }) async {
    final token = data['token']?.toString();

    if (token == null || token.isEmpty) {
      throw StateError('The server did not return an authentication token.');
    }

    api.setSessionToken(token);

    await storage.write(key: 'auth_token', value: token);
    await storage.write(
      key: 'remember_me',
      value: rememberMe ? '1' : '0',
    );

    user = Map<String, dynamic>.from(data['user'] ?? {});
    authenticated = true;
  }
}
