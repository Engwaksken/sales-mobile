import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/customer_api.dart';
import '../core/document_sharing.dart';

class CustomerPaymentsScreen extends StatefulWidget {
  const CustomerPaymentsScreen({super.key});

  @override
  State<CustomerPaymentsScreen> createState() => _CustomerPaymentsScreenState();
}

class _CustomerPaymentsScreenState extends State<CustomerPaymentsScreen> {
  bool loading = true;
  List<dynamic> rows = [];

  late final CustomerApi customerApi;

  @override
  void initState() {
    super.initState();
    customerApi = CustomerApi(context.read<ApiClient>());
    load();
  }

  Future<void> load() async {
    final result = await customerApi.payments();
    if (!mounted) return;

    setState(() {
      rows = result;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payments & Receipts')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: load,
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: rows.isEmpty
                    ? const [
                        SizedBox(height: 160),
                        Center(child: Text('No payments yet.')),
                      ]
                    : rows.map((raw) {
                        final row = Map<String, dynamic>.from(raw as Map);

                        return Card(
                          elevation: 0,
                          child: ListTile(
                            leading: const CircleAvatar(
                              child: Icon(Icons.payments_outlined),
                            ),
                            title: Text(
                              '${row['receipt_no'] ?? row['receipt_number'] ?? 'Payment'}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            subtitle: Text(
                              '${row['invoice_no'] ?? row['order_number'] ?? ''}\n${row['method'] ?? row['payment_method'] ?? ''}',
                            ),
                            isThreeLine: true,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'UGX ${row['amount'] ?? row['amount_paid'] ?? 0}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Share receipt',
                                  icon: const Icon(Icons.share_outlined),
                                  onPressed: () => shareDocument('Payment receipt', [
                                    'PAYMENT RECEIPT',
                                    'Receipt: ${row['receipt_no'] ?? row['receipt_number'] ?? 'Payment'}',
                                    'Invoice: ${row['invoice_no'] ?? row['order_number'] ?? ''}',
                                    'Amount: UGX ${row['amount'] ?? row['amount_paid'] ?? 0}',
                                    'Method: ${row['method'] ?? row['payment_method'] ?? ''}',
                                    'Date: ${row['created_at'] ?? row['payment_date'] ?? ''}',
                                  ]),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
              ),
            ),
    );
  }
}
