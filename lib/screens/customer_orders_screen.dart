import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/customer_api.dart';
import '../widgets/filter_bar.dart';
import 'customer_order_detail_screen.dart';

class CustomerOrdersScreen extends StatefulWidget {
  const CustomerOrdersScreen({super.key});

  @override
  State<CustomerOrdersScreen> createState() => _CustomerOrdersScreenState();
}

class _CustomerOrdersScreenState extends State<CustomerOrdersScreen> {
  bool loading = true;
  String? error;
  List<dynamic> rows = [];

  late final CustomerApi customerApi;

  /// Matched against each order's status group on the phone.
  static const filters = [
    ChoiceFilter(
      id: 'status',
      label: 'Status',
      options: [
        FilterOption('pending', 'Pending'),
        FilterOption('shipping', 'Shipping'),
        FilterOption('delivered', 'Delivered'),
      ],
    ),
  ];
  Map<String, Object?> values = {};

  @override
  void initState() {
    super.initState();
    customerApi = CustomerApi(context.read<ApiClient>());
    load();
  }

  Future<void> load() async {
    try {
      final result = await customerApi.orders();
      if (!mounted) return;
      setState(() {
        rows = result;
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

  List<dynamic> filtered(String? filter) {
    if (filter == null) return rows;

    return rows.where((raw) {
      final row = Map<String, dynamic>.from(raw as Map);
      final status = '${row['status_group'] ?? row['status'] ?? ''}'
          .toLowerCase();
      return status == filter;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());

    if (error != null) {
      return Center(child: Text(error!, textAlign: TextAlign.center));
    }

    return Column(
      children: [
        Material(
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'My Orders',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                  ),
                ),
                IconButton(onPressed: load, icon: const Icon(Icons.refresh)),
              ],
            ),
          ),
        ),
        FilterBar(
          filters: filters,
          values: values,
          onChanged: (v) => setState(() => values = v),
          quickFilters: const ['status'],
        ),
        Expanded(
          child: Builder(
            builder: (context) {
              final items = filtered(values['status'] as String?);

              if (items.isEmpty) {
                return values['status'] == null
                    ? const Center(child: Text('No orders yet.'))
                    : SingleChildScrollView(
                        child: FilteredEmptyState(
                          message: 'No orders match these filters',
                          onClear: () => setState(() => values = {}),
                        ),
                      );
              }

              return RefreshIndicator(
                onRefresh: load,
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: items.length,
                  itemBuilder: (_, index) {
                    final order = Map<String, dynamic>.from(
                      items[index] as Map,
                    );
                    return Card(
                      elevation: 0,
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(12),
                        leading: const CircleAvatar(
                          child: Icon(Icons.inventory_2_outlined),
                        ),
                        title: Text(
                          '${order['order_number'] ?? order['order_id'] ?? 'Order'}',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${order['status_label'] ?? order['status'] ?? 'Pending'}',
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'UGX ${order['total_amount'] ?? 0}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => CustomerOrderDetailScreen(
                                orderId: int.parse('${order['id']}'),
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
