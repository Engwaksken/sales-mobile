import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:dio/dio.dart';

import 'api_client.dart';
import 'biometric_auth.dart';
import 'config.dart';

class AuthResult {
  const AuthResult({
    this.error,
    this.requiresVerification = false,
    this.email,
    this.biometricNotice,
  });

  final String? error;
  final bool requiresVerification;
  final String? email;

  /// Set after a successful sign-in when biometric sign-in was asked for:
  /// whether it was turned on, or why not. Null when nothing needs saying.
  final String? biometricNotice;

  bool get success => error == null && !requiresVerification;
}

class AuthStore extends ChangeNotifier {
  AuthStore(this.api, this.storage, [BiometricAuth? biometrics]) : biometrics = biometrics ?? BiometricAuth();

  final ApiClient api;
  final FlutterSecureStorage storage;
  final BiometricAuth biometrics;

  bool loading = true;
  bool authenticated = false;
  Map<String, dynamic>? user;

  // Biometric sign-in. The phone keeps its own token for it (separate from the
  // password session) in secure storage, released only after a fingerprint or
  // face check. Signing out keeps it; turning the feature off revokes it.
  static const _bioToken = 'biometric_token';
  static const _bioEmail = 'biometric_email';
  static const _bioName = 'biometric_name';
  static const _bioDevice = 'NSales Native Mobile (biometric sign-in)';

  /// The phone has a fingerprint or face enrolled.
  bool biometricAvailable = false;

  /// "fingerprint" or "face", for button and message text.
  String biometricLabel = 'fingerprint';

  /// Biometric sign-in is turned on, for [biometricEmail].
  bool biometricEnabled = false;
  String? biometricEmail;
  String? biometricName;

  /// The sign-in screen offers the biometric prompt by itself once per launch.
  bool biometricAutoPromptUsed = false;

  Future<void> loadBiometrics() async {
    biometricAvailable = await biometrics.isAvailable();
    if (biometricAvailable) biometricLabel = await biometrics.label();
    final token = await storage.read(key: _bioToken);
    biometricEnabled = token != null && token.isNotEmpty;
    biometricEmail = biometricEnabled ? await storage.read(key: _bioEmail) : null;
    biometricName = biometricEnabled ? await storage.read(key: _bioName) : null;
    notifyListeners();
  }

  /// Checks the fingerprint, then signs in with the stored biometric token.
  /// Returns an error message, or null on success or a deliberate cancel.
  Future<String?> signInWithBiometrics() async {
    final token = await storage.read(key: _bioToken);
    if (token == null || token.isEmpty) {
      await _forgetBiometrics();
      return 'Sign in with your password to turn on $biometricLabel sign-in.';
    }

    final outcome = await biometrics.authenticate('Sign in to your account');
    if (outcome != BiometricOutcome.success) {
      return BiometricAuth.messageFor(outcome, biometricLabel);
    }

    loading = true;
    notifyListeners();
    try {
      api.setSessionToken(token);
      final response = await api.get(AppConfig.mePath);
      user = Map<String, dynamic>.from(response.data['user'] ?? {});
      await storage.write(key: 'auth_token', value: token);
      // Ask for the fingerprint again next time the app opens.
      await storage.write(key: 'remember_me', value: '0');
      authenticated = true;
      return null;
    } catch (error) {
      api.setSessionToken(null);
      final status = error is DioException ? error.response?.statusCode : null;
      if (status == 401) {
        // Revoked on the server, e.g. after a password change or reset.
        await _forgetBiometrics();
        return '${_capitalised(biometricLabel)} sign-in has expired. Sign in with your password to turn it back on.';
      }
      return api.messageFromError(error);
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Turns biometric sign-in on for [email]: confirms the fingerprint, then
  /// asks the server for a token dedicated to it. Returns an error message,
  /// or null on success. A cancelled fingerprint check returns ''.
  Future<String?> enableBiometrics({required String email, required String password}) async {
    final outcome = await biometrics.authenticate('Confirm your $biometricLabel to turn on $biometricLabel sign-in');
    if (outcome != BiometricOutcome.success) {
      return BiometricAuth.messageFor(outcome, biometricLabel) ?? '';
    }

    try {
      final response = await api.post(
        AppConfig.loginPath,
        data: {'email': email.trim(), 'password': password, 'device_name': _bioDevice},
      );
      final token = response.data['token']?.toString();
      if (token == null || token.isEmpty) return 'The server did not return a sign-in token. Please try again.';

      await _revokeBiometricToken();
      final account = Map<String, dynamic>.from(response.data['user'] ?? {});
      await storage.write(key: _bioToken, value: token);
      await storage.write(key: _bioEmail, value: email.trim());
      await storage.write(key: _bioName, value: account['name']?.toString() ?? '');
      biometricEnabled = true;
      biometricEmail = email.trim();
      biometricName = account['name']?.toString();
      notifyListeners();
      return null;
    } catch (error) {
      return api.messageFromError(error);
    }
  }

  Future<void> disableBiometrics() async {
    await _revokeBiometricToken();
    await _forgetBiometrics();
  }

  /// Revokes the stored biometric token on the server, unless it is the
  /// session in use right now (revoking that would sign the person out).
  Future<void> _revokeBiometricToken() async {
    final token = await storage.read(key: _bioToken);
    if (token == null || token.isEmpty || token == api.sessionToken) return;
    try {
      await api.post(AppConfig.logoutPath, bearerToken: token);
    } catch (_) {
      // Already gone or offline; forgetting it locally is what matters.
    }
  }

  Future<void> _forgetBiometrics() async {
    await storage.delete(key: _bioToken);
    await storage.delete(key: _bioEmail);
    await storage.delete(key: _bioName);
    biometricEnabled = false;
    biometricEmail = null;
    biometricName = null;
    notifyListeners();
  }

  static String _capitalised(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  Future<void> bootstrap() async {
    await loadBiometrics();
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
    bool enableBiometrics = false,
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

      String? notice;
      if (enableBiometrics) {
        final problem = await this.enableBiometrics(email: email, password: password);
        notice = problem == null
            ? '${_capitalised(biometricLabel)} sign-in is on. Use it next time you sign in.'
            : problem.isEmpty
                ? null
                : "$problem You can turn on $biometricLabel sign-in later in My profile.";
      }

      return AuthResult(biometricNotice: notice);
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
    final bioToken = await storage.read(key: _bioToken);
    // A session opened with biometrics uses the biometric token itself; keep
    // it valid so the next biometric sign-in still works.
    if (api.sessionToken == null || api.sessionToken != bioToken) {
      try {
        await api.post(AppConfig.logoutPath);
      } catch (_) {
        // Always clear the local session.
      }
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
