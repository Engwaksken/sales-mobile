import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nsales_native/core/api_client.dart';
import 'package:nsales_native/core/auth_store.dart';
import 'package:nsales_native/core/biometric_auth.dart';
import 'package:nsales_native/core/branding.dart';
import 'package:nsales_native/core/config.dart';
import 'package:nsales_native/screens/login_screen.dart';
import 'package:provider/provider.dart';

/// Stands in for the phone's fingerprint reader.
class FakeBiometrics extends BiometricAuth {
  FakeBiometrics({this.available = true, this.outcome = BiometricOutcome.success});

  bool available;
  BiometricOutcome outcome;
  int prompts = 0;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<String> label() async => 'fingerprint';

  @override
  Future<BiometricOutcome> authenticate(String reason) async {
    prompts++;
    return outcome;
  }
}

typedef Reply = (int, Map<String, dynamic>);

class Harness {
  Harness(this.auth, this.requests, this.storage);

  final AuthStore auth;
  final List<RequestOptions> requests;
  final FlutterSecureStorage storage;

  Iterable<String> get paths => requests.map((r) => r.path);
}

const _user = {'id': 1, 'name': 'Jane Akello', 'email': 'jane@example.com', 'role': 'customer'};

Future<Harness> setUpAuth({
  Map<String, String> stored = const {},
  FakeBiometrics? biometrics,
  Reply Function(RequestOptions r)? respond,
}) async {
  FlutterSecureStorage.setMockInitialValues(Map.of(stored));
  const storage = FlutterSecureStorage();
  final requests = <RequestOptions>[];
  final api = ApiClient(storage);
  var issued = 0;
  api.dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
    requests.add(options);
    final reply = respond?.call(options) ??
        (options.path == AppConfig.loginPath
            ? (200, {'token': 'token-${++issued}', 'user': _user})
            : (200, {'user': _user}));
    handler.resolve(Response(requestOptions: options, statusCode: reply.$1, data: reply.$2));
  }));
  final auth = AuthStore(api, storage, biometrics ?? FakeBiometrics());
  await auth.bootstrap();
  return Harness(auth, requests, storage);
}

Future<void> pumpLogin(WidgetTester tester, Harness h) async {
  final api = h.auth.api;
  await tester.pumpWidget(MultiProvider(
    providers: [
      Provider<ApiClient>.value(value: api),
      ChangeNotifierProvider<AuthStore>.value(value: h.auth),
      ChangeNotifierProvider<BrandingStore>(create: (_) => BrandingStore(api, h.storage)),
    ],
    child: MaterialApp(
      home: Consumer<AuthStore>(
        builder: (_, auth, _) => auth.authenticated ? const Scaffold(body: Text('HOME')) : const LoginScreen(),
      ),
    ),
  ));
  await tester.pump();
  await tester.pump();
}

Future<void> tapText(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text));
  await tester.pump();
  await tester.tap(find.text(text));
}

/// Lets Dio's timeout timers run out so the test ends cleanly.
Future<void> drain(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 35));
}

const _enabled = {
  'biometric_token': 'bio-token',
  'biometric_email': 'jane@example.com',
  'biometric_name': 'Jane Akello',
};

void main() {
  group('sign-in screen', () {
    testWidgets('offers to turn on fingerprint sign-in when the phone supports it', (tester) async {
      final h = await setUpAuth();
      await pumpLogin(tester, h);
      expect(find.text('Use fingerprint next time'), findsOneWidget);
      expect(find.textContaining('with fingerprint'), findsNothing);
      await drain(tester);
    });

    testWidgets('says nothing about fingerprints on phones without one', (tester) async {
      final h = await setUpAuth(biometrics: FakeBiometrics(available: false));
      await pumpLogin(tester, h);
      expect(find.textContaining('fingerprint'), findsNothing);
      await drain(tester);
    });

    testWidgets('a password sign-in with the box ticked turns it on with its own token', (tester) async {
      final bio = FakeBiometrics();
      final h = await setUpAuth(biometrics: bio);
      await pumpLogin(tester, h);

      await tester.enterText(find.widgetWithText(TextFormField, 'Email address'), 'jane@example.com');
      await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'secret123');
      await tapText(tester, 'Sign in');
      await tester.pumpAndSettle();

      final logins = h.requests.where((r) => r.path == AppConfig.loginPath).toList();
      expect(logins, hasLength(2));
      expect(logins.last.data['device_name'], contains('biometric'));
      expect(bio.prompts, 1);
      expect(await h.storage.read(key: 'biometric_token'), 'token-2');
      expect(await h.storage.read(key: 'auth_token'), 'token-1');
      expect(find.text('HOME'), findsOneWidget);
      expect(find.text('Fingerprint sign-in is on. Use it next time you sign in.'), findsOneWidget);
      await drain(tester);
    });

    testWidgets('unticking the box signs in with the password only', (tester) async {
      final bio = FakeBiometrics();
      final h = await setUpAuth(biometrics: bio);
      await pumpLogin(tester, h);

      await tapText(tester, 'Use fingerprint next time');
      await tester.enterText(find.widgetWithText(TextFormField, 'Email address'), 'jane@example.com');
      await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'secret123');
      await tapText(tester, 'Sign in');
      await tester.pumpAndSettle();

      expect(h.requests.where((r) => r.path == AppConfig.loginPath), hasLength(1));
      expect(bio.prompts, 0);
      expect(h.auth.biometricEnabled, isFalse);
      await drain(tester);
    });

    testWidgets('when on, it asks for the fingerprint by itself and signs in', (tester) async {
      final bio = FakeBiometrics();
      final h = await setUpAuth(stored: _enabled, biometrics: bio);
      await pumpLogin(tester, h);
      await tester.pumpAndSettle();

      expect(bio.prompts, 1);
      final me = h.requests.singleWhere((r) => r.path == AppConfig.mePath);
      expect(me.headers['Authorization'], 'Bearer bio-token');
      expect(find.text('HOME'), findsOneWidget);
      await drain(tester);
    });

    testWidgets('cancelling the prompt leaves the button to try again', (tester) async {
      final bio = FakeBiometrics(outcome: BiometricOutcome.cancelled);
      final h = await setUpAuth(stored: _enabled, biometrics: bio);
      await pumpLogin(tester, h);
      await tester.pumpAndSettle();

      expect(find.text('Sign in as Jane with fingerprint'), findsOneWidget);
      expect(h.paths, isNot(contains(AppConfig.mePath)));

      bio.outcome = BiometricOutcome.success;
      await tapText(tester, 'Sign in as Jane with fingerprint');
      await tester.pumpAndSettle();
      expect(bio.prompts, 2);
      expect(find.text('HOME'), findsOneWidget);
      await drain(tester);
    });

    testWidgets('a revoked token turns it off and asks for the password', (tester) async {
      final h = await setUpAuth(
        stored: _enabled,
        respond: (r) => r.path == AppConfig.mePath ? (401, {'message': 'Unauthenticated.'}) : (200, {}),
      );
      await pumpLogin(tester, h);
      await tester.pumpAndSettle();

      expect(find.textContaining('Fingerprint sign-in has expired'), findsOneWidget);
      expect(h.auth.biometricEnabled, isFalse);
      expect(await h.storage.read(key: 'biometric_token'), isNull);
      expect(find.text('Use fingerprint next time'), findsOneWidget);
      await drain(tester);
    });
  });

  group('auth store', () {
    test('signing out of a fingerprint session keeps its token valid', () async {
      final h = await setUpAuth(stored: _enabled);
      expect(await h.auth.signInWithBiometrics(), isNull);
      await h.auth.logout();

      expect(h.paths, isNot(contains(AppConfig.logoutPath)));
      expect(await h.storage.read(key: 'biometric_token'), 'bio-token');
      expect(h.auth.authenticated, isFalse);
    });

    test('signing out of a password session still revokes that session', () async {
      final h = await setUpAuth(stored: _enabled);
      await h.auth.login('jane@example.com', 'secret123', rememberMe: true);
      await h.auth.logout();

      final logout = h.requests.singleWhere((r) => r.path == AppConfig.logoutPath);
      expect(logout.headers['Authorization'], 'Bearer token-1');
      expect(await h.storage.read(key: 'biometric_token'), 'bio-token');
    });

    test('turning it off revokes the biometric token on the server', () async {
      final h = await setUpAuth(stored: _enabled);
      await h.auth.login('jane@example.com', 'secret123', rememberMe: true);
      await h.auth.disableBiometrics();

      final revoke = h.requests.singleWhere((r) => r.path == AppConfig.logoutPath);
      expect(revoke.headers['Authorization'], 'Bearer bio-token');
      expect(h.auth.biometricEnabled, isFalse);
      expect(h.auth.authenticated, isTrue);
    });

    test('a locked-out reader explains what to do', () async {
      final h = await setUpAuth(stored: _enabled, biometrics: FakeBiometrics(outcome: BiometricOutcome.lockedOut));
      expect(await h.auth.signInWithBiometrics(), contains('Too many tries'));
      expect(h.auth.authenticated, isFalse);
    });
  });
}
