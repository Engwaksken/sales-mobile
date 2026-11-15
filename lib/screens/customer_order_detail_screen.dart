import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/customer_api.dart';
import '../core/document_sharing.dart';

class CustomerOrderDetailScreen extends StatefulWidget {
  const CustomerOrderDetailScreen({super.key, required this.orderId});

  final int orderId;

  @override
  State<CustomerOrderDetailScreen> createState() =>
      _CustomerOrderDetailScreenState();
}

class _CustomerOrderDetailScreenState extends State<CustomerOrderDetailScreen> {
  bool loading = true;
  Map<String, dynamic> order = {};

  late final CustomerApi customerApi;

  @override
  void initState() {
    super.initState();
    customerApi = CustomerApi(context.read<ApiClient>());
    load();
  }

  Future<void> load() async {
    final result = await customerApi.order(widget.orderId);
    if (!mounted) return;
    setState(() {
      order = result;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final timeline = List<dynamic>.from(order['timeline'] ?? []);
    final items = List<dynamic>.from(order['items'] ?? []);
    final receipts = List<dynamic>.from(order['receipts'] ?? []);

    return Scaffold(
      appBar: AppBar(
        title: Text('${order['order_number'] ?? order['order_id'] ?? 'Order'}'),
        actions: [
          IconButton(
            tooltip: 'Share invoice',
            icon: const Icon(Icons.share_outlined),
            onPressed: () => shareDocument(
              'Invoice ${order['order_number'] ?? order['order_id'] ?? ''}',
              [
                'INVOICE ${order['order_number'] ?? order['order_id'] ?? ''}',
                'Customer: ${order['customer_name'] ?? ''}',
                'Status: ${order['status_label'] ?? order['status'] ?? ''}',
                '',
                for (final raw in items)
                  () {
                    final item = Map<String, dynamic>.from(raw as Map);
                    return '${item['product_name'] ?? 'Product'} — Qty ${item['quantity'] ?? 0} — UGX ${item['subtotal'] ?? item['price'] ?? 0}';
                  }(),
                '',
                'Total: UGX ${order['total_amount'] ?? 0}',
                'Paid: UGX ${order['amount_paid'] ?? 0}',
                'Balance: UGX ${order['balance_amount'] ?? 0}',
                'Delivery address: ${order['address'] ?? order['delivery_location'] ?? ''}',
              ],
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              elevation: 0,
              child: ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.local_shipping_outlined),
                ),
                title: Text(
                  '${order['status_label'] ?? order['status'] ?? 'Pending'}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: Text(
                  'Payment: ${order['payment_status'] ?? 'pending'}',
                ),
                trailing: Text(
                  'UGX ${order['total_amount'] ?? 0}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
            const SizedBox(height: 14),

            const Text(
              'Track Order',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),

            ...timeline.asMap().entries.map((entry) {
              final step = Map<String, dynamic>.from(entry.value as Map);
              final done = step['done'] == true;
              final active = step['active'] == true;

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      CircleAvatar(
                        radius: 13,
                        backgroundColor: done || active
                            ? Theme.of(context).colorScheme.primary
                            : const Color(0xFFE2E8F0),
                        child: Icon(
                          done ? Icons.check : Icons.circle,
                          size: done ? 15 : 7,
                          color: done || active
                              ? Colors.white
                              : const Color(0xFF94A3B8),
                        ),
                      ),
                      if (entry.key < timeline.length - 1)
                        Container(
                          width: 2,
                          height: 45,
                          color: done
                              ? Theme.of(context).colorScheme.primary
                              : const Color(0xFFE2E8F0),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${step['label'] ?? ''}',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: done || active
                                  ? const Color(0xFF0F172A)
                                  : const Color(0xFF94A3B8),
                            ),
                          ),
                          if ('${step['date'] ?? ''}'.isNotEmpty)
                            Text(
                              '${step['date']}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF64748B),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }),

            const SizedBox(height: 8),
            const Text(
              'Items',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            ...items.map((raw) {
              final item = Map<String, dynamic>.from(raw as Map);
              return Card(
                elevation: 0,
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.inventory_2_outlined),
                  ),
                  title: Text('${item['product_name'] ?? 'Product'}'),
                  subtitle: Text('Qty: ${item['quantity'] ?? 0}'),
                  trailing: Text(
                    'UGX ${item['subtotal'] ?? item['price'] ?? 0}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              );
            }),

            if (receipts.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Payment Receipts',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              ...receipts.map((raw) {
                final receipt = Map<String, dynamic>.from(raw as Map);
                return Card(
                  elevation: 0,
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.receipt_long_outlined),
                    ),
                    title: Text(
                      '${receipt['receipt_number'] ?? receipt['receipt_no'] ?? 'Receipt'}',
                    ),
                    subtitle: Text(
                      '${receipt['payment_method'] ?? receipt['method'] ?? ''}',
                    ),
                    trailing: IconButton(
                      tooltip: 'Share receipt',
                      icon: const Icon(Icons.share_outlined),
                      onPressed: () => shareDocument(
                        'Payment receipt ${receipt['receipt_number'] ?? receipt['receipt_no'] ?? ''}',
                        [
                          'PAYMENT RECEIPT ${receipt['receipt_number'] ?? receipt['receipt_no'] ?? ''}',
                          'Invoice: ${order['order_number'] ?? order['order_id'] ?? ''}',
                          'Amount: UGX ${receipt['amount_paid'] ?? receipt['amount'] ?? 0}',
                          'Method: ${receipt['payment_method'] ?? receipt['method'] ?? ''}',
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],

            const SizedBox(height: 16),
            Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    _row(
                      'Delivery Address',
                      '${order['address'] ?? order['delivery_location'] ?? '—'}',
                    ),
                    _row('Payment Method', '${order['payment_method'] ?? '—'}'),
                    _row('Amount Paid', 'UGX ${order['amount_paid'] ?? 0}'),
                    _row('Balance', 'UGX ${order['balance_amount'] ?? 0}'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF64748B)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
