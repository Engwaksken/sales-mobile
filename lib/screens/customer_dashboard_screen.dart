import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/customer_api.dart';
import '../core/config.dart';
import '../widgets/common.dart';
import 'customer_order_detail_screen.dart';

class CustomerDashboardScreen extends StatefulWidget {
  const CustomerDashboardScreen({super.key});

  @override
  State<CustomerDashboardScreen> createState() =>
      _CustomerDashboardScreenState();
}

class _CustomerDashboardScreenState extends State<CustomerDashboardScreen> {
  bool loading = true;
  String? error;
  Map<String, dynamic> data = {};

  late final CustomerApi customerApi;

  @override
  void initState() {
    super.initState();
    customerApi = CustomerApi(context.read<ApiClient>());
    load();
  }

  Future<void> load() async {
    try {
      final result = await customerApi.home();
      if (!mounted) return;
      setState(() {
        data = result;
        error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = context.read<ApiClient>().messageFromError(e);
      });
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null) {
      return RefreshIndicator(
        onRefresh: load,
        child: ListView(
          children: [
            const SizedBox(height: 180),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Icon(Icons.cloud_off, size: 48),
                  const SizedBox(height: 12),
                  Text(error!, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: load,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final profile = Map<String, dynamic>.from(data['profile'] ?? const {});
    final counts = Map<String, dynamic>.from(data['counts'] ?? const {});
    final recentOrders = List<dynamic>.from(data['recent_orders'] ?? const []);
    final rawPhoto = profile['photo_url']?.toString() ?? '';
    final parsedPhoto = Uri.tryParse(rawPhoto);
    final photoUrl = rawPhoto.isEmpty
        ? null
        : (parsedPhoto?.hasScheme == true
              ? rawPhoto
              : Uri.parse(AppConfig.apiOrigin)
                    .resolve(rawPhoto.startsWith('/') ? rawPhoto : '/$rawPhoto')
                    .toString());

    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF111827),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white12,
                  foregroundImage: photoUrl == null
                      ? null
                      : NetworkImage(photoUrl),
                  onForegroundImageError: photoUrl == null ? null : (_, _) {},
                  child: Text(
                    '${profile['name'] ?? 'C'}'.substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Welcome back',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      Text(
                        '${profile['name'] ?? 'Customer'}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        '${profile['email'] ?? ''}',
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          const Text(
            'My Orders',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),

          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 4,
            crossAxisSpacing: 8,
            childAspectRatio: 1.65,
            children: [
              StatCard(
                icon: Icons.receipt_long_outlined,
                label: 'All',
                value: '${counts['all_orders'] ?? 0}',
              ),
              StatCard(
                icon: Icons.hourglass_top,
                label: 'Pending',
                value: '${counts['pending_orders'] ?? 0}',
              ),
              StatCard(
                icon: Icons.local_shipping_outlined,
                label: 'Shipping',
                value: '${counts['shipping_orders'] ?? 0}',
              ),
              StatCard(
                icon: Icons.check_circle_outline,
                label: 'Delivered',
                value: '${counts['delivered_orders'] ?? 0}',
              ),
              StatCard(
                icon: Icons.payments_outlined,
                label: 'Payments',
                value: '${counts['payments'] ?? 0}',
              ),
              StatCard(
                icon: Icons.notifications_outlined,
                label: 'Unread notifications',
                value: '${counts['unread_notifications'] ?? 0}',
              ),
            ],
          ),

          const SizedBox(height: 22),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Recent Orders',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                ),
              ),
              Text(
                '${counts['all_orders'] ?? 0} total',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (recentOrders.isEmpty)
            const Card(
              elevation: 0,
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Center(
                  child: Text('No orders yet. Start shopping from Products.'),
                ),
              ),
            )
          else
            ...recentOrders.map((raw) {
              final order = Map<String, dynamic>.from(raw as Map);
              return _OrderCard(order: order);
            }),
        ],
      ),
    );
  }
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24),
            const SizedBox(height: 5),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
            Text(
              label,
              maxLines: 1,
              style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: ListTile(
        leading: CircleAvatar(child: Icon(icon)),
        title: Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text(label),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final Map<String, dynamic> order;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.shopping_bag_outlined)),
        title: Text(
          '${order['order_number'] ?? order['order_id'] ?? 'Order'}',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          '${order['status_label'] ?? order['status'] ?? 'Pending'}'.replaceAll(
            '_',
            ' ',
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          final id = int.tryParse('${order['id']}');
          if (id == null) return;

          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => CustomerOrderDetailScreen(orderId: id),
            ),
          );
        },
      ),
    );
  }
}
