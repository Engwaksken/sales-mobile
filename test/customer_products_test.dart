import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nsales_native/core/api_client.dart';
import 'package:nsales_native/screens/customer_products_screen.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('a failed load shows an error with Retry instead of spinning forever', (tester) async {
    var fail = true;
    final api = ApiClient(const FlutterSecureStorage())..setSessionToken('t');
    api.dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      if (fail) {
        handler.reject(DioException(requestOptions: options, type: DioExceptionType.connectionError));
        return;
      }
      handler.resolve(Response(requestOptions: options, statusCode: 200, data: {
        'data': [
          {'id': 1, 'name': 'Steel Bucket', 'sku': 'B1', 'price': 10000, 'available': 4},
        ],
      }));
    }));

    await tester.pumpWidget(Provider<ApiClient>.value(
      value: api,
      child: const MaterialApp(home: Scaffold(body: CustomerProductsScreen())),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.textContaining('No internet connection'), findsOneWidget);

    fail = false;
    await tester.tap(find.textContaining('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Steel Bucket'), findsOneWidget);
  });
}
