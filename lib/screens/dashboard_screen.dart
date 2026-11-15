import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/config.dart';
import '../core/format.dart';
import '../widgets/common.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool loading = true;
  String? error;
  List<dynamic> stats = [];
  List<dynamic> recentSales = [];
  List<dynamic> recentOrders = [];
  String currency = AppConfig.currency;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final response = await context.read<ApiClient>().get('/dashboard');
      final data = Map<String, dynamic>.from(response.data);

      if (!mounted) return;
      setState(() {
        stats = List<dynamic>.from(data['stats'] ?? []);
        recentSales = List<dynamic>.from(data['recent_sales'] ?? []);
        recentOrders = List<dynamic>.from(data['recent_orders'] ?? []);
        currency = data['currency']?.toString() ?? AppConfig.currency;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => error = context.read<ApiClient>().messageFromError(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  IconData iconFor(String? name) {
    return switch (name) {
      'point_of_sale' => Icons.point_of_sale,
      'trending_up' => Icons.trending_up,
      'receipt_long' => Icons.receipt_long,
      'shopping_cart' => Icons.shopping_cart,
      'people' => Icons.people,
      'inventory_2' => Icons.inventory_2,
      'payments' => Icons.payments,
      'notifications' => Icons.notifications,
      _ => Icons.insights,
    };
  }

  String valueFor(Map<String, dynamic> stat) {
    final value = stat['value'];
    if (stat['type'] == 'money') {
      return compactMoney(value);
    }
    return '$value';
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());

    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 50, color: Color(0xFF94A3B8)),
              const SizedBox(height: 12),
              Text(error!, textAlign: TextAlign.center),
              const SizedBox(height: 14),
              FilledButton.icon(onPressed: load, icon: const Icon(Icons.refresh), label: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Dashboard', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          const Text('Live business overview', style: TextStyle(color: Color(0xFF64748B))),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final columns = width >= 800 ? 4 : 2;
              final cardWidth = (width - ((columns - 1) * 12)) / columns;

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: stats.map((entry) {
                  final stat = Map<String, dynamic>.from(entry as Map);
                  return SizedBox(
                    width: cardWidth,
                    child: StatCard(
                      label: stat['label']?.toString() ?? 'Statistic',
                      value: valueFor(stat),
                      icon: iconFor(stat['icon']?.toString()),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 20),
          _Section(title: 'Recent Sales', icon: Icons.receipt_long, rows: recentSales),
          const SizedBox(height: 14),
          _Section(title: 'Recent Orders', icon: Icons.shopping_cart, rows: recentOrders),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.icon, required this.rows});

  final String title;
  final IconData icon;
  final List<dynamic> rows;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [Icon(icon, size: 20), const SizedBox(width: 8), Text(title, style: const TextStyle(fontWeight: FontWeight.w800))]),
            const SizedBox(height: 10),
            if (rows.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: Text('No recent records.', style: TextStyle(color: Color(0xFF94A3B8)))),
              )
            else
              ...rows.take(5).map((raw) {
                final row = Map<String, dynamic>.from(raw as Map);
                final title = row['invoice_no'] ?? row['order_number'] ?? row['customer_name'] ?? row['name'] ?? 'Record';
                final subtitle = row['status'] ?? row['payment_status'] ?? row['created_at'] ?? '';
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: const CircleAvatar(child: Icon(Icons.arrow_outward, size: 17)),
                  title: Text('$title', maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('$subtitle', maxLines: 1, overflow: TextOverflow.ellipsis),
                );
              }),
          ],
        ),
      ),
    );
  }
}
