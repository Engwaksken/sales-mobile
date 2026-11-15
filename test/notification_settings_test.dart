import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nsales_native/core/api_client.dart';
import 'package:nsales_native/core/brand_defaults.dart';
import 'package:nsales_native/screens/notification_settings_screen.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('shows the options for this user and saves a change', (tester) async {
    final api = ApiClient(const FlutterSecureStorage())..setSessionToken('t');
    final sent = <Map<String, dynamic>>[];
    Map<String, dynamic> settings(bool lowStock) => {
          'data': {
            'options': [
              {'key': 'announcements', 'label': 'Announcements', 'description': 'News', 'channel': 'app', 'enabled': true},
              {'key': 'low_stock', 'label': 'Low stock alerts', 'description': 'Stock', 'channel': 'app', 'enabled': lowStock},
            ],
            'low_stock_threshold': 5,
          },
        };
    api.dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      if (options.method == 'PUT') sent.add(Map<String, dynamic>.from(options.data as Map));
      final lowStock = sent.isEmpty || (sent.last['preferences'] as Map)['low_stock'] == true;
      handler.resolve(Response(requestOptions: options, statusCode: 200, data: settings(lowStock)));
    }));

    await tester.pumpWidget(Provider<ApiClient>.value(
      value: api,
      child: const MaterialApp(home: NotificationSettingsScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Announcements'), findsOneWidget);
    expect(find.text('Low stock alerts'), findsOneWidget);
    expect(find.text('or fewer'), findsOneWidget);
    expect(find.text('By email'), findsNothing);

    await tester.tap(find.widgetWithText(SwitchListTile, 'Low stock alerts'));
    await tester.pumpAndSettle();

    expect(sent.single['preferences'], {'announcements': true, 'low_stock': false});
    expect(find.text('or fewer'), findsNothing);
  });

  test('brand defaults come from the website settings', () {
    expect(kBrandName, isNotEmpty);
  });
}
