import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/auth_store.dart';
import 'customer_chat_screen.dart';
import 'customer_history_screen.dart';
import 'customer_notifications_screen.dart';
import 'customer_payments_screen.dart';
import 'profile_screen.dart';
import 'notification_settings_screen.dart';

class CustomerAccountScreen extends StatelessWidget {
  const CustomerAccountScreen({
    super.key,
    required this.onOpenOrders,
  });

  final VoidCallback onOpenOrders;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthStore>().user;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 33,
              child: Text(
                '${user?['name'] ?? 'C'}'
                    .substring(0, 1)
                    .toUpperCase(),
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${user?['name'] ?? 'Customer'}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    '${user?['email'] ?? ''}',
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        _section(
          'My Account',
          [
            _item(
              context,
              icon: Icons.local_shipping_outlined,
              title: 'My Orders',
              subtitle: 'Track pending, shipped and delivered orders',
              onTap: onOpenOrders,
            ),
            _item(
              context,
              icon: Icons.payments_outlined,
              title: 'Payments & Receipts',
              subtitle: 'View payment history and receipts',
              page: const CustomerPaymentsScreen(),
            ),
            _item(
              context,
              icon: Icons.notifications_outlined,
              title: 'Notifications',
              subtitle: 'Orders, payments and support updates',
              page: const CustomerNotificationsScreen(),
            ),
            _item(
              context,
              icon: Icons.history,
              title: 'History',
              subtitle: 'Your order and payment activity',
              page: const CustomerHistoryScreen(),
            ),
          ],
        ),

        const SizedBox(height: 16),
        _section(
          'Support & Profile',
          [
            _item(
              context,
              icon: Icons.support_agent,
              title: 'Chat Support',
              subtitle: 'Ask the chatbot or contact support',
              page: const CustomerChatScreen(),
            ),
            _item(
              context,
              icon: Icons.manage_accounts_outlined,
              title: 'My Profile',
              subtitle: 'Photo, name, phone, address and password',
              page: const ProfileScreen(),
            ),
            _item(
              context,
              icon: Icons.notifications_active_outlined,
              title: 'Notification Settings',
              subtitle: 'Choose what you are notified about',
              page: const NotificationSettingsScreen(),
            ),
          ],
        ),

        const SizedBox(height: 18),
        OutlinedButton.icon(
          onPressed: () => context.read<AuthStore>().logout(),
          icon: const Icon(Icons.logout),
          label: const Text('Sign Out'),
        ),
      ],
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Card(
      elevation: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _item(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? page,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: CircleAvatar(child: Icon(icon)),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap ??
          () {
            if (page == null) return;
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => page),
            );
          },
    );
  }
}
