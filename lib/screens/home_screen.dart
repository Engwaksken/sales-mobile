import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/auth_store.dart';
import '../core/user_access.dart';
import 'customer_home_screen.dart';
import 'staff_home_screen.dart';

/// Sends customers to the shop experience and everyone else (admins,
/// managers, cashiers, accountants and custom roles) to the staff workspace.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final access = UserAccess(context.watch<AuthStore>().user);

    return access.isCustomer
        ? const CustomerHomeScreen()
        : StaffHomeScreen(key: ValueKey('staff-${access.role}'));
  }
}
