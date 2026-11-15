class AppConfig {
  static const String apiOrigin = 'https://nsales.kemmytech.com';
  static const String apiBaseUrl = '$apiOrigin/api/mobile';

  static const String appName = 'NSales';
  static const String currency = 'UGX';
  static const String logoAsset = 'assets/icons/logo.png';

  static const String loginPath = '/login';
  static const String registerPath = '/register';
  static const String registerVerifyOtpPath = '/register/verify-otp';
  static const String registerResendOtpPath = '/register/resend-otp';

  static const String forgotPasswordPath = '/forgot-password';
  static const String forgotPasswordVerifyOtpPath =
      '/forgot-password/verify-otp';
  static const String forgotPasswordResendOtpPath =
      '/forgot-password/resend-otp';
  static const String resetPasswordPath = '/reset-password';

  static const String mePath = '/me';
  static const String logoutPath = '/logout';
  static const String healthPath = '/health';
}
