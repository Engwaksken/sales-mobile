import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nsales_native/screens/profile_screen.dart';
import 'package:nsales_native/widgets/signature_pad.dart';

import 'staff_harness.dart';

void main() {
  Map<String, dynamic> profile({bool customer = false, String? signature}) => {
        'data': {
          'name': 'Grace Nakato',
          'email': 'grace@example.com',
          'role': customer ? 'customer' : 'cashier',
          'role_label': customer ? 'Customer' : 'Cashier',
          'is_customer': customer,
          'signature': signature,
        },
      };

  testWidgets('staff see their signature and can remove it', (tester) async {
    final png = await tester.runAsync(() => renderSignaturePng([
          [const Offset(10, 30), const Offset(60, 10), const Offset(110, 40)],
        ]));
    final server = await pumpStaff(
      tester,
      const ProfileScreen(),
      size: const Size(360, 900),
      server: StaffServer((r) => r.method == 'DELETE' ? profile() : profile(signature: pngDataUri(png!))),
    );

    expect(find.text('My signature'), findsOneWidget);
    expect(find.bySemanticsLabel('Your signature'), findsOneWidget);
    expect(find.text('Redraw'), findsOneWidget);

    await tester.ensureVisible(find.text('Remove'));
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    expect(server.requests.where((r) => r.method == 'DELETE' && r.path == '/profile/signature'), hasLength(1));
    expect(find.text('No signature yet'), findsOneWidget);
    expect(find.text('Draw'), findsOneWidget);
  });

  testWidgets('customers have no signature section', (tester) async {
    await pumpStaff(tester, const ProfileScreen(), server: StaffServer((_) => profile(customer: true)));

    expect(find.text('My signature'), findsNothing);
  });
}
