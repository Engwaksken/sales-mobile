import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nsales_native/core/api_client.dart';
import 'package:nsales_native/core/app_theme.dart';
import 'package:nsales_native/core/auth_store.dart';
import 'package:nsales_native/core/branding.dart';
import 'package:nsales_native/core/config.dart';
import 'package:nsales_native/main.dart';
import 'package:nsales_native/screens/forgot_password_screen.dart';
import 'package:nsales_native/screens/login_screen.dart';
import 'package:nsales_native/screens/password_reset_otp_screen.dart';
import 'package:nsales_native/screens/register_screen.dart';
import 'package:nsales_native/screens/reset_password_screen.dart';
import 'package:nsales_native/screens/verify_registration_screen.dart';
import 'package:nsales_native/widgets/auth_ui.dart';
import 'package:provider/provider.dart';

/// A reply from the stand-in server: status code and JSON body.
typedef Reply = (int, Map<String, dynamic>);

class FakeServer {
  FakeServer([this.respond]);

  final Reply? Function(RequestOptions request)? respond;
  final requests = <RequestOptions>[];

  Iterable<String> get paths => requests.map((r) => r.path);
}

/// Pumps [screen] with the app's providers. Unless [viaApp] is set it is
/// pushed on top of the sign-in screen, as it is in the real app.
Future<FakeServer> pumpAuth(
  WidgetTester tester,
  Widget? screen, {
  FakeServer? server,
  Size size = const Size(360, 640),
  double keyboard = 0,
  Brightness brightness = Brightness.light,
  double textScale = 1,
}) async {
  FlutterSecureStorage.setMockInitialValues({});
  server ??= FakeServer();

  tester.view.devicePixelRatio = 2;
  tester.view.physicalSize = size * 2;
  // Simulates the on-screen keyboard; MediaQuery.viewInsets comes from here.
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard * 2);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);

  const storage = FlutterSecureStorage();
  final api = ApiClient(storage);
  api.dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) {
      server!.requests.add(options);
      final reply = server.respond?.call(options) ?? (200, <String, dynamic>{});
      handler.resolve(Response(
        requestOptions: options,
        statusCode: reply.$1,
        data: reply.$2,
      ));
    },
  ));
  final auth = AuthStore(api, storage)..loading = false;
  final branding = BrandingStore(api, storage);

  final app = screen == null
      ? const NSalesApp()
      : MaterialApp(
          theme: ThemeData(
            useMaterial3: true,
            brightness: brightness,
            colorScheme: ColorScheme.fromSeed(
              seedColor: branding.primary,
              brightness: brightness,
            ),
          ),
          home: const _Root(),
        );

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: api),
        ChangeNotifierProvider<AuthStore>.value(value: auth),
        ChangeNotifierProvider<BrandingStore>.value(value: branding),
        ChangeNotifierProvider<ThemeModeStore>(create: (_) => ThemeModeStore(const FlutterSecureStorage())),
      ],
      child: app,
    ),
  );
  if (screen != null) {
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(MaterialPageRoute(builder: (_) => screen));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }
  await tester.pump();
  return server;
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) => const Scaffold(body: SizedBox());
}

/// Lets Dio's timeout timers run out so the test ends cleanly.
Future<void> drainTimers(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 35));
}

Finder field(String label) => find.widgetWithText(TextFormField, label);

Future<void> tapPrimary(WidgetTester tester) async {
  final button = find.byType(AuthPrimaryButton);
  await tester.ensureVisible(button);
  await tester.pump();
  await tester.tap(button);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

final screens = <String, Widget Function()>{
  'login': () => const LoginScreen(),
  'register': () => const RegisterScreen(),
  'forgot password': () => const ForgotPasswordScreen(),
  'reset code': () => const PasswordResetOtpScreen(email: 'jo@example.com'),
  'new password': () => const ResetPasswordScreen(
        email: 'jo@example.com',
        resetToken: 'token',
      ),
  'verify email': () => const VerifyRegistrationScreen(
        email: 'jo@example.com',
        rememberMe: true,
      ),
};

void main() {
  group('sign in', () {
    testWidgets('shows the title, fields and actions', (tester) async {
      await pumpAuth(tester, null);

      expect(find.text('Sign in to your account'), findsOneWidget);
      expect(field('Email address'), findsOneWidget);
      expect(field('Password'), findsOneWidget);
      expect(find.text('Forgot password?'), findsOneWidget);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
      await tester.pump();
      expect(find.text('Create an account'), findsOneWidget);
      expect(find.byTooltip('Show password'), findsOneWidget);
      // The admin's system name sits in the header.
      expect(find.text(kBrandNameForTest), findsOneWidget);
      await drainTimers(tester);
    });

    testWidgets('an empty submit shows inline messages and sends nothing',
        (tester) async {
      final server = await pumpAuth(tester, null);
      await tapPrimary(tester);

      expect(find.text('Enter your email address.'), findsOneWidget);
      expect(find.text('Enter your password.'), findsOneWidget);
      expect(server.paths, isNot(contains(AppConfig.loginPath)));

      await tester.enterText(field('Email address'), 'not-an-email');
      await tester.pump();
      expect(
        find.text('Enter a valid email address, like name@example.com.'),
        findsOneWidget,
      );
      await drainTimers(tester);
    });

    testWidgets('a rejected sign-in keeps the form and shows the server error',
        (tester) async {
      final server = await pumpAuth(
        tester,
        null,
        server: FakeServer((request) => request.path == AppConfig.loginPath
            ? (422, {'message': 'These credentials do not match our records.'})
            : null),
      );

      await tester.enterText(field('Email address'), 'jo@example.com');
      await tester.enterText(field('Password'), 'wrong-pass');
      await tapPrimary(tester);
      await tester.pump(const Duration(milliseconds: 50));

      expect(server.paths, contains(AppConfig.loginPath));
      expect(server.requests.last.data, {
        'email': 'jo@example.com',
        'password': 'wrong-pass',
        'device_name': 'NSales Native Mobile',
      });
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(
        find.text('These credentials do not match our records.'),
        findsOneWidget,
      );
      expect(find.text('jo@example.com'), findsOneWidget);
      await drainTimers(tester);
    });

    testWidgets('an unverified account goes to email verification',
        (tester) async {
      await pumpAuth(
        tester,
        null,
        server: FakeServer((request) => request.path == AppConfig.loginPath
            ? (403, {
                'code': 'EMAIL_VERIFICATION_REQUIRED',
                'email': 'jo@example.com',
              })
            : null),
      );

      await tester.enterText(field('Email address'), 'jo@example.com');
      await tester.enterText(field('Password'), 'Secret123');
      await tapPrimary(tester);
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(VerifyRegistrationScreen), findsOneWidget);
      expect(find.text('Verify your email'), findsOneWidget);
      await drainTimers(tester);
    });
  });

  group('create account', () {
    testWidgets('validates every field and rates the password',
        (tester) async {
      final server = await pumpAuth(tester, const RegisterScreen());

      expect(find.text('Create your account'), findsOneWidget);
      for (final label in [
        'Full name',
        'Email address',
        'Password',
        'Confirm password',
      ]) {
        expect(field(label), findsOneWidget, reason: label);
      }

      await tapPrimary(tester);
      expect(find.text('Enter your full name.'), findsOneWidget);
      expect(find.text('Enter your email address.'), findsOneWidget);
      expect(find.text('Create a password.'), findsOneWidget);
      expect(find.text('Confirm your password.'), findsOneWidget);
      expect(server.paths, isNot(contains(AppConfig.registerPath)));

      await tester.enterText(field('Password'), 'abcdefgh');
      await tester.pump();
      expect(
        find.text('Include both upper and lowercase letters.'),
        findsOneWidget,
      );
      expect(find.text('Weak'), findsOneWidget);

      await tester.enterText(field('Password'), 'Abcdefgh1234');
      await tester.enterText(field('Confirm password'), 'Abcdefgh123');
      await tester.pump();
      expect(find.text('Strong'), findsOneWidget);
      expect(find.text("The passwords don't match."), findsOneWidget);
      await drainTimers(tester);
    });

    testWidgets('sends the same fields and moves to verification',
        (tester) async {
      final server = await pumpAuth(tester, const RegisterScreen());

      await tester.enterText(field('Full name'), ' Jo Doe ');
      await tester.enterText(field('Email address'), 'jo@example.com');
      await tester.enterText(field('Password'), 'Secret123');
      await tester.enterText(field('Confirm password'), 'Secret123');
      await tapPrimary(tester);
      await tester.pump(const Duration(milliseconds: 400));

      expect(server.requests.last.path, AppConfig.registerPath);
      expect(server.requests.last.data, {
        'name': 'Jo Doe',
        'email': 'jo@example.com',
        'password': 'Secret123',
        'password_confirmation': 'Secret123',
      });
      expect(find.byType(VerifyRegistrationScreen), findsOneWidget);
      await drainTimers(tester);
    });
  });

  group('password recovery', () {
    testWidgets('asks for an email, then moves to the code step',
        (tester) async {
      final server = await pumpAuth(tester, const ForgotPasswordScreen());

      expect(find.text('Reset your password'), findsOneWidget);
      expect(find.text('Back to sign in'), findsOneWidget);
      await tapPrimary(tester);
      expect(find.text('Enter your email address.'), findsOneWidget);

      await tester.enterText(field('Email address'), 'jo@example.com');
      await tapPrimary(tester);
      await tester.pump(const Duration(milliseconds: 400));

      expect(server.requests.last.path, AppConfig.forgotPasswordPath);
      expect(find.byType(PasswordResetOtpScreen), findsOneWidget);
      expect(find.text('STEP 2 OF 3'), findsOneWidget);
      await drainTimers(tester);
    });

    testWidgets('the code field takes digits only and submits at six',
        (tester) async {
      final server = await pumpAuth(
        tester,
        const PasswordResetOtpScreen(email: 'jo@example.com'),
        server: FakeServer(
          (request) =>
              request.path == AppConfig.forgotPasswordVerifyOtpPath
                  ? (200, {'reset_token': 'abc'})
                  : null,
        ),
      );

      expect(find.text('Check your email'), findsOneWidget);
      await tapPrimary(tester);
      expect(find.text('Enter the 6-digit code.'), findsOneWidget);

      final otp = field('Verification code');
      await tester.enterText(otp, '12a4');
      await tester.pump();
      expect(find.text('124'), findsOneWidget);

      await tester.enterText(otp, '123456');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(server.requests.last.path, AppConfig.forgotPasswordVerifyOtpPath);
      expect(server.requests.last.data, {
        'email': 'jo@example.com',
        'otp': '123456',
      });
      expect(find.byType(ResetPasswordScreen), findsOneWidget);
      await drainTimers(tester);
    });

    testWidgets('a wrong code shows the server message inline',
        (tester) async {
      await pumpAuth(
        tester,
        const VerifyRegistrationScreen(email: 'jo@example.com', rememberMe: true),
        server: FakeServer(
          (request) => request.path == AppConfig.registerVerifyOtpPath
              ? (422, {'message': 'The code is invalid or has expired.'})
              : null,
        ),
      );

      await tester.enterText(field('Verification code'), '654321');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('The code is invalid or has expired.'), findsOneWidget);
      expect(find.byType(VerifyRegistrationScreen), findsOneWidget);
      await drainTimers(tester);
    });

    testWidgets('new password is validated before it is sent',
        (tester) async {
      final server = await pumpAuth(
        tester,
        const ResetPasswordScreen(email: 'jo@example.com', resetToken: 'tok'),
      );

      expect(find.text('Set a new password'), findsOneWidget);
      await tapPrimary(tester);
      expect(find.text('Create a password.'), findsOneWidget);
      expect(find.text('Confirm your password.'), findsOneWidget);
      expect(server.paths, isNot(contains(AppConfig.resetPasswordPath)));
      await drainTimers(tester);
    });
  });

  group('layout', () {
    for (final entry in screens.entries) {
      testWidgets('${entry.key} fits 360x640 with the keyboard open',
          (tester) async {
        await pumpAuth(tester, entry.value(), keyboard: 280);

        final context = tester.element(find.byType(AuthScaffold));
        expect(MediaQuery.viewInsetsOf(context).bottom, 280);

        // The submit button stays reachable by scrolling.
        await tester.ensureVisible(find.byType(AuthPrimaryButton));
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(
          tester.getSize(find.byType(AuthPrimaryButton)).height,
          greaterThanOrEqualTo(52),
        );
        await drainTimers(tester);
      });

      testWidgets('${entry.key} renders in dark mode with large text',
          (tester) async {
        await pumpAuth(
          tester,
          entry.value(),
          brightness: Brightness.dark,
          textScale: 1.3,
        );
        await tester.tap(find.byType(AuthPrimaryButton), warnIfMissed: false);
        await tester.pump();
        expect(tester.takeException(), isNull);
        await drainTimers(tester);
      });
    }

    testWidgets('the form is capped at 440px wide on tablets', (tester) async {
      await pumpAuth(tester, const RegisterScreen(), size: const Size(1024, 768));

      expect(
        tester.getSize(find.byType(AuthPrimaryButton)).width,
        lessThanOrEqualTo(kAuthMaxWidth),
      );
      await drainTimers(tester);
    });
  });

  group('contrast helpers', () {
    test('text on the brand colour is white on dark brands', () {
      expect(onBrandColor(const Color(0xFF0F766E)), Colors.white);
      expect(onBrandColor(const Color(0xFFFDE047)), isNot(Colors.white));
    });

    test('a pale brand colour is darkened for links on white', () {
      final accent = readableBrand(const Color(0xFFFDE047), Colors.white);
      expect(accent.computeLuminance(), lessThan(.2));
    });
  });
}

/// The default system name the app ships with (overridden by the admin).
final kBrandNameForTest = BrandingStore(
  ApiClient(const FlutterSecureStorage()),
  const FlutterSecureStorage(),
).siteName;
