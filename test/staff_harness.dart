import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nsales_native/core/api_client.dart';
import 'package:nsales_native/core/app_theme.dart';
import 'package:nsales_native/core/auth_store.dart';
import 'package:nsales_native/core/staff_lookups.dart';
import 'package:provider/provider.dart';

/// A stand-in API that records every request and answers from [respond].
class StaffServer {
  StaffServer([this.respond]);

  final Object? Function(RequestOptions request)? respond;
  final requests = <RequestOptions>[];

  /// Query parameters of the requests made to [path], oldest first.
  List<Map<String, dynamic>> queriesFor(String path) =>
      [for (final r in requests) if (r.path == path) r.queryParameters];

  Map<String, dynamic> lastQuery(String path) => queriesFor(path).last;
}

/// One page of list rows in the API's paginated shape.
Map<String, dynamic> page(List<Map<String, dynamic>> rows) => {
      'data': rows,
      'meta': {'current_page': 1, 'last_page': 1},
    };

/// Lookups as an admin sees them, without a network round trip.
StaffLookups adminLookups(ApiClient api) => StaffLookups(api)
  ..loaded = true
  ..isAdmin = true
  ..branchId = 1
  ..branches = const [Option(1, 'Main Street'), Option(2, 'Kampala Road Wholesale and Retail Branch')]
  ..products = const [Option(10, 'Steel Bucket'), Option(11, 'Cement 50kg'), Option(12, 'Iron Sheets Gauge 28')]
  ..categories = const [Option(5, 'Hardware'), Option(6, 'Paint')];

/// Pumps [home] at phone size with the API, lookups and [theme] the staff app uses.
Future<StaffServer> pumpStaff(
  WidgetTester tester,
  Widget home, {
  StaffServer? server,
  Size size = const Size(360, 640),
  double textScale = 1,
  ThemeData? theme,
  TransitionBuilder? appBuilder,
}) async {
  server ??= StaffServer();
  tester.view.devicePixelRatio = 2;
  tester.view.physicalSize = size * 2;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);

  final api = ApiClient(const FlutterSecureStorage())..setSessionToken('t');
  api.dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
    server!.requests.add(options);
    handler.resolve(Response(
      requestOptions: options,
      statusCode: 200,
      data: server.respond?.call(options) ?? page(const []),
    ));
  }));

  await tester.pumpWidget(MultiProvider(
    providers: [
      Provider<ApiClient>.value(value: api),
      // Signed-in session as in the app; biometrics report unavailable in tests.
      ChangeNotifierProvider<AuthStore>(create: (_) => AuthStore(api, const FlutterSecureStorage())..loading = false),
      ChangeNotifierProvider<ThemeModeStore>(create: (_) => ThemeModeStore(const FlutterSecureStorage())),
      ChangeNotifierProvider<StaffLookups>.value(value: adminLookups(api)),
    ],
    child: MaterialApp(
      theme: theme ?? ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F766E))),
      builder: appBuilder,
      home: home,
    ),
  ));
  await tester.pumpAndSettle();
  return server;
}
