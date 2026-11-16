import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/customer_api.dart';

import '../core/app_theme.dart';
class CustomerHistoryScreen extends StatefulWidget {
  const CustomerHistoryScreen({super.key});

  @override
  State<CustomerHistoryScreen> createState() =>
      _CustomerHistoryScreenState();
}

class _CustomerHistoryScreenState extends State<CustomerHistoryScreen> {
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
    final result = await customerApi.history();
    if (!mounted) return;

    setState(() {
      rows = result;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Account History')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: rows.length,
              itemBuilder: (_, index) {
                final row =
                    Map<String, dynamic>.from(rows[index] as Map);

                return Card(
                  elevation: 0,
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Icon(
                        row['type'] == 'payment'
                            ? Icons.payments_outlined
                            : Icons.shopping_bag_outlined,
                      ),
                    ),
                    title: Text(
                      '${row['title'] ?? 'Activity'}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text('${row['subtitle'] ?? ''}'),
                    trailing: Text(
                      '${row['date'] ?? ''}',
                      style: TextStyle(
                        fontSize: 11,
                        color: context.muted,
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
