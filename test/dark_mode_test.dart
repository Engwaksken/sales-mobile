import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nsales_native/core/app_theme.dart';
import 'package:nsales_native/screens/dashboard_screen.dart';
import 'package:nsales_native/screens/profile_screen.dart';
import 'package:nsales_native/screens/staff/sales_screens.dart';
import 'package:provider/provider.dart';

import 'staff_harness.dart';

/// Set `DARK_SHOTS=folder` to also save PNG screenshots (with real fonts) for review.
final shots = Platform.environment['DARK_SHOTS'];

Future<void> loadFonts() async {
  final dir = Platform.environment['FLUTTER_FONTS'];
  if (dir == null) return;
  final loader = FontLoader('Roboto');
  for (final f in ['roboto-regular.ttf', 'roboto-medium.ttf', 'roboto-bold.ttf', 'roboto-black.ttf']) {
    final file = File('$dir/$f');
    if (file.existsSync()) loader.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
  }
  await loader.load();
  final icons = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.sublistView(File('$dir/materialicons-regular.otf').readAsBytesSync())));
  await icons.load();
}

ThemeData theme(Brightness b) {
  final t = buildAppTheme(const Color(0xFF1D2B72), b);
  return shots == null ? t : t.copyWith(textTheme: t.textTheme.apply(fontFamily: 'Roboto'));
}

Future<void> snap(WidgetTester tester, String name) async {
  if (shots == null) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('shot')));
  final image = await tester.runAsync(() => boundary.toImage(pixelRatio: 2));
  final bytes = await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.png));
  File('$shots/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
}

Object? rows(dynamic r) {
  if (r.path == '/dashboard') {
    return {
      'stats': [
        {'key': 'month_sales', 'label': 'Month Sales', 'value': 1250000, 'type': 'money', 'icon': 'trending_up', 'module': 'sales', 'filter': {}},
        {'key': 'pending_orders', 'label': 'Pending Orders', 'value': 4, 'type': 'number', 'icon': 'shopping_cart', 'module': 'orders', 'filter': {}},
      ],
      'charts': {
        'monthly': [for (final m in ['Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov']) {'label': m, 'sales': 100000, 'expenses': 40000}],
        'daily': [for (var i = 0; i < 7; i++) {'label': '${i + 1} Nov', 'value': i * 1000}],
      },
      'recent_sales': [],
      'recent_orders': [],
    };
  }
  if (r.path == '/profile') {
    return {'data': {'name': 'Grace Nakato', 'email': 'grace@example.com', 'role': 'cashier', 'role_label': 'Cashier', 'is_customer': false}};
  }
  return page([
    {'id': 1, 'invoice_no': 'INV-00120', 'customer_name': 'Jane Achieng', 'payment_status': 'paid', 'total_amount': 125000, 'sale_date': '2026-11-10'},
    {'id': 2, 'invoice_no': 'INV-00121', 'customer_name': 'Walk-in', 'payment_status': 'partial', 'total_amount': 130000, 'sale_date': '2026-11-11'},
    {'id': 3, 'invoice_no': 'INV-00122', 'customer_name': 'Jane Achieng', 'payment_status': 'pending', 'total_amount': 135000, 'sale_date': '2026-11-12'},
  ]);
}

void main() {
  setUpAll(loadFonts);

  final screens = <String, Widget Function()>{
    'dashboard': () => const Scaffold(body: DashboardScreen()),
    'sales': () => Scaffold(appBar: AppBar(title: const Text('Sales')), body: const SalesScreen(initialStatus: 'paid')),
    'profile': () => const ProfileScreen(),
  };

  for (final b in [Brightness.dark, Brightness.light]) {
    for (final entry in screens.entries) {
      testWidgets('${entry.key} renders in ${b.name} mode', (tester) async {
        await pumpStaff(
          tester,
          entry.value(),
          server: StaffServer(rows),
          size: const Size(360, 760),
          theme: theme(b),
          appBuilder: (context, child) => RepaintBoundary(key: const ValueKey('shot'), child: child),
        );
        expect(tester.takeException(), isNull);
        expect(Theme.of(tester.element(find.byType(Scaffold).first)).brightness, b);
        await snap(tester, '${entry.key}-${b.name}');
      });
    }
  }

  testWidgets('the Appearance setting switches and remembers the theme mode', (tester) async {
    await pumpStaff(tester, const ProfileScreen(), server: StaffServer(rows), size: const Size(360, 1200));
    final store = Provider.of<ThemeModeStore>(tester.element(find.byType(ProfileScreen)), listen: false);
    expect(store.mode, ThemeMode.system);

    await tester.ensureVisible(find.text('Dark'));
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(store.mode, ThemeMode.dark);
    expect(find.text('Applies on this phone only.'), findsOneWidget);
  });

  test('dark theme lifts a navy brand colour so it stays visible', () {
    final dark = buildAppTheme(const Color(0xFF1D2B72), Brightness.dark).colorScheme;
    expect(dark.primary.computeLuminance(), greaterThan(const Color(0xFF1D2B72).computeLuminance()));
    expect(buildAppTheme(const Color(0xFF1D2B72), Brightness.light).colorScheme.primary, const Color(0xFF1D2B72));
  });
}
