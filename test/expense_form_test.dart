import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nsales_native/core/api_client.dart';
import 'package:nsales_native/core/staff_lookups.dart';
import 'package:nsales_native/screens/expense_form_screen.dart';
import 'package:provider/provider.dart';

void main() {
  late ApiClient api;
  late List<RequestOptions> posts;

  Future<void> pumpForm(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 3600);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);

    api = ApiClient(const FlutterSecureStorage())..setSessionToken('t');
    posts = [];
    api.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.method == 'POST') posts.add(options);
          final data = options.path == '/staff/lookups'
              ? {
                  'payment_methods': [
                    'Cash',
                    'Mobile Money',
                    'Card',
                    'Bank Transfer',
                    'Cheque',
                  ],
                  'expense_category_names': ['Fuel', 'Rent', 'Transport'],
                }
              : {'message': 'ok', 'data': {}};
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: options.method == 'POST' ? 201 : 200,
              data: data,
            ),
          );
        },
      ),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ApiClient>.value(value: api),
          ChangeNotifierProvider<StaffLookups>(
            create: (_) => StaffLookups(api),
          ),
        ],
        child: const MaterialApp(home: ExpenseFormScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Map<String, String> sentFields() {
    final body = posts.single.data;
    if (body is FormData) {
      return {for (final field in body.fields) field.key: field.value};
    }
    return (body as Map).map((key, value) => MapEntry('$key', '$value'));
  }

  testWidgets(
    'saves without a title, with the chosen payment method and category',
    (tester) async {
      await pumpForm(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Amount *'),
        '50000',
      );
      await tester.tap(find.text('Choose a category'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fuel').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cash'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mobile Money').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Paid to (payee / merchant)'),
        'Shell Bugolobi',
      );
      await tester.pump();

      expect(
        find.text('If left blank: "Fuel – Shell Bugolobi"'),
        findsOneWidget,
      );

      await tester.tap(find.text('Save Expense'));
      await tester.pumpAndSettle();

      final fields = sentFields();
      expect(posts.single.data, isA<Map<String, dynamic>>());
      expect(fields['category'], 'Fuel');
      expect(fields['payment_method'], 'Mobile Money');
      expect(fields.containsKey('title'), isFalse);
    },
  );

  testWidgets('a new category can be typed', (tester) async {
    await pumpForm(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Amount *'),
      '20000',
    );
    await tester.tap(find.text('Choose a category'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add a new category').last);
    await tester.pumpAndSettle();

    // Saving without a name is refused.
    await tester.tap(find.text('Save Expense'));
    await tester.pumpAndSettle();
    expect(find.text('Type the category name'), findsOneWidget);
    expect(posts, isEmpty);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'New category name *'),
      'Generator fuel',
    );
    await tester.tap(find.text('Save Expense'));
    await tester.pumpAndSettle();

    final fields = sentFields();
    expect(fields['category_new'], 'Generator fuel');
    expect(fields.containsKey('category'), isFalse);
  });

  test('receipt payment text maps onto the app methods', () {
    const methods = ['Cash', 'Mobile Money', 'Card', 'Bank Transfer', 'Cheque'];
    expect(matchPaymentMethod('MTN MoMo', methods), 'Mobile Money');
    expect(matchPaymentMethod('VISA ****1234', methods), 'Card');
    expect(matchPaymentMethod('EFT', methods), 'Bank Transfer');
    expect(matchPaymentMethod('cash', methods), 'Cash');
    expect(matchPaymentMethod('voucher', methods), isNull);
  });
}
