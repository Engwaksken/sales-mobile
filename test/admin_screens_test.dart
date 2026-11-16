import 'package:dio/dio.dart' show RequestOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nsales_native/screens/staff/admin_screens.dart';

import 'staff_harness.dart';

Map<String, dynamic> schema = {
  'data': {
    'key': 'payment-gateways',
    'label': 'Payment Gateways',
    'read_only': false,
    'fields': [
      {'name': 'display_name', 'type': 'text', 'label': 'Display name', 'required': true, 'required_on_edit': true},
      {'name': 'provider_type', 'type': 'select', 'label': 'Provider type', 'required': true, 'required_on_edit': true,
        'options': [{'value': 'mobile_money', 'label': 'Mobile money'}, {'value': 'card', 'label': 'Card'}]},
      {'name': 'is_active', 'type': 'bool', 'label': 'Active', 'required': false, 'default': false},
      {'name': 'client_secret', 'type': 'secret', 'label': 'Client secret', 'required': false, 'help': 'Hidden for security.'},
    ],
  },
};

Object? respond(RequestOptions r) {
  if (r.path.endsWith('/schema')) return schema;
  if (r.path == '/staff/admin/payment-gateways/7' && r.method == 'GET') {
    return {
      'data': {
        'id': 7,
        'title': 'Mobile Money',
        'values': {'display_name': 'Mobile Money', 'provider_type': 'mobile_money', 'is_active': true, 'client_secret': null, 'client_secret__set': true},
        'details': [{'label': 'Gateway Code', 'value': 'iotec'}],
      },
    };
  }
  if (r.method != 'GET') return {'message': 'Payment Gateway saved.', 'data': {'id': 7}};
  return page([]);
}

Future<void> tapText(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text).last);
  await tester.tap(find.text(text).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a new record is built from the schema, validated and posted', (tester) async {
    final server = await pumpStaff(
      tester,
      const AdminRecordScreen(resource: 'payment-gateways', label: 'Payment Gateways'),
      server: StaffServer(respond),
      size: const Size(360, 900),
    );

    expect(find.text('New payment gateway'), findsOneWidget);
    await tapText(tester, 'Create payment gateway');
    expect(find.text('Enter display name'), findsOneWidget);
    expect(find.text('Choose provider type'), findsOneWidget);
    expect(server.requests.where((r) => r.method == 'POST'), isEmpty);

    await tester.enterText(find.widgetWithText(TextFormField, 'Display name *'), 'Mobile Money');
    await tapText(tester, 'Provider type *');
    await tapText(tester, 'Mobile money');
    await tapText(tester, 'Active');
    await tapText(tester, 'Create payment gateway');

    final post = server.requests.singleWhere((r) => r.method == 'POST');
    expect(post.path, '/staff/admin/payment-gateways');
    expect(post.data, {'display_name': 'Mobile Money', 'provider_type': 'mobile_money', 'is_active': true, 'client_secret': null});
  });

  testWidgets('editing shows saved values, hides secrets and puts the change', (tester) async {
    final server = await pumpStaff(
      tester,
      const AdminRecordScreen(resource: 'payment-gateways', label: 'Payment Gateways', id: 7),
      server: StaffServer(respond),
      size: const Size(360, 1000),
    );

    expect(find.text('Mobile Money'), findsWidgets);
    expect(find.textContaining('Saved. Hidden for security.'), findsOneWidget);
    expect(find.text('All details'), findsOneWidget);

    await tapText(tester, 'Save changes');
    final put = server.requests.singleWhere((r) => r.method == 'PUT');
    expect(put.path, '/staff/admin/payment-gateways/7');
    expect((put.data as Map)['client_secret'], isNull, reason: 'blank secret keeps the saved one');
  });

  testWidgets('role permissions: switch role, tick a permission and save', (tester) async {
    final server = await pumpStaff(
      tester,
      const Scaffold(body: RolePermissionsScreen()),
      size: const Size(360, 900),
      server: StaffServer((r) => {
            'data': {
              'roles': [{'key': 'cashier', 'label': 'Cashier'}, {'key': 'manager', 'label': 'Manager'}],
              'groups': [
                {'category': 'Sales', 'permissions': [{'key': 'manage_sales', 'label': 'Manage sales', 'description': ''}, {'key': 'manage_orders', 'label': 'Manage orders', 'description': ''}]},
              ],
              'assigned': {'cashier': ['manage_sales']},
            },
            'message': 'Role permissions saved.',
          }),
    );

    expect(find.text('No changes'), findsOneWidget);
    await tapText(tester, 'Manager (0)');
    await tapText(tester, 'Manage orders');
    await tapText(tester, 'Save permissions');

    final put = server.requests.singleWhere((r) => r.method == 'PUT');
    expect(put.data, {'permissions': {'cashier': ['manage_sales'], 'manager': ['manage_orders']}});
  });

  testWidgets('settings: a bad colour is caught before saving', (tester) async {
    final server = await pumpStaff(
      tester,
      const Scaffold(body: AdminSettingsScreen()),
      size: const Size(360, 900),
      server: StaffServer((r) => {
            'data': {
              'values': {
                'site_name': 'Unihub', 'currency': 'UGX', 'timezone': 'Africa/Kampala', 'default_branch_id': '',
                'theme_primary': '#1d2b72', 'theme_secondary': '#0ea5e9', 'theme_accent': '#f59e0b', 'theme_sidebar': '#0f172a',
                'theme_sidebar_text': '#e2e8f0', 'theme_background': '#f8fafc', 'theme_surface': '#ffffff', 'font_family': 'Lato', 'font_size': '14',
                'tax_rate': '18', 'invoice_prefix': 'INV-', 'order_prefix': 'ORD-', 'low_stock_threshold': '5', 'receipt_footer_note': 'Thanks',
                'enable_guest_checkout': '1', 'enable_mobile_money': '1', 'accessibility_widget_enabled': '0',
                'system_logo_url': null, 'system_favicon_url': null,
              },
              'branches': [],
              'fonts': ['Lato', 'Inter'],
            },
          }),
    );

    expect(find.text('Unihub'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, '#1d2b72'), 'blue');
    await tapText(tester, 'Save settings');
    expect(find.text('Use a colour like #1d2b72'), findsOneWidget);
    expect(server.requests.where((r) => r.method == 'POST'), isEmpty);
  });
}
